import { EventEmitter } from "events";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import * as https from "https";
import * as http from "http";

const CONFIG_DIR = path.join(os.homedir(), ".agent-team");
const CONFIG_FILE = path.join(CONFIG_DIR, "tracker.json");

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface Bounty {
  number: number;
  title: string;
  status: string;       // ready, blocked, review, claimed
  agent_type: string;   // be, fe, qa, etc.
  _repo: string;
  claimed_by?: string;
}

export interface Repo {
  slug: string;
  local_dir: string;
  repo_dir: string;
}

export interface GitHubPR {
  number: number;
  title: string;
  state: string;
  head: string;
  author: string;
  url: string;
  created_at: string;
  updated_at: string;
}

export interface GitHubIssue {
  number: number;
  title: string;
  state: string;
  labels: string[];
  url: string;
}

export interface RepoStatus {
  slug: string;
  bounties: { ready: number; blocked: number; review: number; claimed: number; total: number };
  prs: GitHubPR[];
  issues: GitHubIssue[];
  issues_open: number;
  prs_open: number;
  url: string;
}

export interface TrackerState {
  api_url: string;
  github_token: string | null;
  repos: Repo[];
  bounties: Bounty[];
  repo_statuses: RepoStatus[];
  last_updated: number;
  error: string | null;
}

// ---------------------------------------------------------------------------
// Tracker
// ---------------------------------------------------------------------------

export class Tracker extends EventEmitter {
  private fallbackTimer: ReturnType<typeof setInterval> | null = null;
  private sseRequest: http.ClientRequest | null = null;
  private sseReconnectTimer: ReturnType<typeof setTimeout> | null = null;
  private _state: TrackerState = {
    api_url: "http://localhost:8000",
    github_token: null,
    repos: [],
    bounties: [],
    repo_statuses: [],
    last_updated: 0,
    error: null,
  };

  constructor() {
    super();
    fs.mkdirSync(CONFIG_DIR, { recursive: true });
    this.loadConfig();
  }

  // -----------------------------------------------------------------------
  // Config persistence
  // -----------------------------------------------------------------------

  private loadConfig(): void {
    try {
      if (fs.existsSync(CONFIG_FILE)) {
        const data = JSON.parse(fs.readFileSync(CONFIG_FILE, "utf-8"));
        if (data.github_token) this._state.github_token = data.github_token;
        if (data.api_url) this._state.api_url = data.api_url;
      }
    } catch { /* ignore */ }
  }

  private saveConfig(): void {
    const data = {
      github_token: this._state.github_token,
      api_url: this._state.api_url,
    };
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(data, null, 2));
  }

  setGitHubToken(token: string): void {
    this._state.github_token = token || null;
    this.saveConfig();
    this.emit("update");
    this.refresh();
  }

  setApiUrl(url: string): void {
    this._state.api_url = url;
    this.saveConfig();
    this.emit("update");
    // Reconnect SSE to new URL
    this.disconnectSSE();
    this.connectSSE();
    this.refresh();
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  start(): void {
    this.refresh();
    this.connectSSE();
    // Fallback poll every 5 minutes (in case SSE drops silently)
    this.fallbackTimer = setInterval(() => this.refresh(), 5 * 60_000);
  }

  stop(): void {
    if (this.fallbackTimer) {
      clearInterval(this.fallbackTimer);
      this.fallbackTimer = null;
    }
    this.disconnectSSE();
  }

  // -----------------------------------------------------------------------
  // SSE connection
  // -----------------------------------------------------------------------

  private connectSSE(): void {
    const url = `${this._state.api_url}/events`;
    const client = url.startsWith("https") ? https : http;

    try {
      this.sseRequest = client.get(url, { timeout: 0 }, (res) => {
        if (res.statusCode !== 200) {
          res.destroy();
          this.scheduleSSEReconnect();
          return;
        }

        let buffer = "";
        res.setEncoding("utf-8");

        res.on("data", (chunk: string) => {
          buffer += chunk;
          // Process complete SSE messages (double newline separated)
          const parts = buffer.split("\n\n");
          buffer = parts.pop() ?? "";
          for (const part of parts) {
            this.handleSSEMessage(part);
          }
        });

        res.on("end", () => {
          this.scheduleSSEReconnect();
        });

        res.on("error", () => {
          this.scheduleSSEReconnect();
        });
      });

      this.sseRequest.on("error", () => {
        this.scheduleSSEReconnect();
      });

      this.sseRequest.on("timeout", () => {
        this.sseRequest?.destroy();
        this.scheduleSSEReconnect();
      });
    } catch {
      this.scheduleSSEReconnect();
    }
  }

  private disconnectSSE(): void {
    if (this.sseReconnectTimer) {
      clearTimeout(this.sseReconnectTimer);
      this.sseReconnectTimer = null;
    }
    if (this.sseRequest) {
      this.sseRequest.destroy();
      this.sseRequest = null;
    }
  }

  private scheduleSSEReconnect(): void {
    this.sseRequest = null;
    if (this.sseReconnectTimer) return; // Already scheduled
    this.sseReconnectTimer = setTimeout(() => {
      this.sseReconnectTimer = null;
      this.connectSSE();
    }, 5_000);
  }

  private handleSSEMessage(raw: string): void {
    // Parse SSE format: "event: xxx\ndata: yyy"
    let event = "";
    let data = "";
    for (const line of raw.split("\n")) {
      if (line.startsWith("event: ")) event = line.slice(7);
      else if (line.startsWith("data: ")) data = line.slice(6);
      else if (line.startsWith(": ")) continue; // comment / ping
    }

    if (event === "connected") return;
    if (!event || !data) return;

    // Any bounty board event → trigger a full refresh
    // This is simpler and more reliable than incremental updates
    this.refresh();
  }

  // -----------------------------------------------------------------------
  // Refresh all data
  // -----------------------------------------------------------------------

  async refresh(): Promise<void> {
    try {
      // 1. Fetch repos from bounty board
      const repos = await this.fetchJSON<Repo[]>(`${this._state.api_url}/repos`);
      this._state.repos = repos ?? [];

      // 2. Fetch all bounties
      const bounties = await this.fetchJSON<Bounty[]>(`${this._state.api_url}/bounties`);
      this._state.bounties = bounties ?? [];

      // 3. Build per-repo status
      const statuses: RepoStatus[] = [];
      for (const repo of this._state.repos) {
        const repoBounties = (bounties ?? []).filter((b) => b._repo === repo.slug);
        const status: RepoStatus = {
          slug: repo.slug,
          bounties: {
            ready: repoBounties.filter((b) => b.status === "ready").length,
            blocked: repoBounties.filter((b) => b.status === "blocked").length,
            review: repoBounties.filter((b) => b.status === "review").length,
            claimed: repoBounties.filter((b) => b.status === "claimed").length,
            total: repoBounties.length,
          },
          prs: [],
          issues: [],
          issues_open: 0,
          prs_open: 0,
          url: `https://github.com/${repo.slug}`,
        };

        // 4. Fetch GitHub data if token available
        if (this._state.github_token) {
          try {
            // PRs
            const prs = await this.fetchGitHub<any[]>(
              `/repos/${repo.slug}/pulls?state=open&per_page=20`
            );
            status.prs = (prs ?? []).map((pr) => ({
              number: pr.number,
              title: pr.title,
              state: pr.state,
              head: pr.head?.ref ?? "",
              author: pr.user?.login ?? "",
              url: pr.html_url ?? "",
              created_at: pr.created_at ?? "",
              updated_at: pr.updated_at ?? "",
            }));
            status.prs_open = status.prs.length;

            // Issues (exclude PRs — GitHub counts PRs as issues)
            const issues = await this.fetchGitHub<any[]>(
              `/repos/${repo.slug}/issues?state=open&per_page=30`
            );
            status.issues = (issues ?? [])
              .filter((i) => !i.pull_request) // Exclude PRs
              .map((i) => ({
                number: i.number,
                title: i.title,
                state: i.state,
                labels: (i.labels ?? []).map((l: any) => l.name),
                url: i.html_url ?? "",
              }));
            status.issues_open = status.issues.length;
          } catch {
            // GitHub fetch failed — continue without data
          }
        }

        statuses.push(status);
      }
      this._state.repo_statuses = statuses;
      this._state.last_updated = Date.now();
      this._state.error = null;
    } catch (err: any) {
      this._state.error = err.message ?? String(err);
    }

    this.emit("update");
  }

  // -----------------------------------------------------------------------
  // HTTP helpers
  // -----------------------------------------------------------------------

  private fetchJSON<T>(url: string): Promise<T | null> {
    return new Promise((resolve) => {
      const client = url.startsWith("https") ? https : http;
      const req = client.get(url, { timeout: 5000 }, (res) => {
        let data = "";
        res.on("data", (chunk: Buffer) => { data += chunk; });
        res.on("end", () => {
          try {
            resolve(JSON.parse(data) as T);
          } catch {
            resolve(null);
          }
        });
      });
      req.on("error", () => resolve(null));
      req.on("timeout", () => { req.destroy(); resolve(null); });
    });
  }

  private fetchGitHub<T>(endpoint: string): Promise<T | null> {
    return new Promise((resolve) => {
      const options = {
        hostname: "api.github.com",
        path: endpoint,
        headers: {
          "User-Agent": "agent-team-supervisor",
          "Accept": "application/vnd.github+json",
          ...(this._state.github_token
            ? { Authorization: `Bearer ${this._state.github_token}` }
            : {}),
        },
        timeout: 10000,
      };
      const req = https.get(options, (res) => {
        let data = "";
        res.on("data", (chunk: Buffer) => { data += chunk; });
        res.on("end", () => {
          try {
            resolve(JSON.parse(data) as T);
          } catch {
            resolve(null);
          }
        });
      });
      req.on("error", () => resolve(null));
      req.on("timeout", () => { req.destroy(); resolve(null); });
    });
  }

  // -----------------------------------------------------------------------
  // API
  // -----------------------------------------------------------------------

  getState(): TrackerState {
    return { ...this._state };
  }

  hasGitHubToken(): boolean {
    return this._state.github_token != null && this._state.github_token.length > 0;
  }
}
