import { EventEmitter } from "events";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";
import * as https from "https";

const CONFIG_DIR = path.join(os.homedir(), ".agent-team");
const CONFIG_FILE = path.join(CONFIG_DIR, "tracker.json");

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export interface Bounty {
  number: number;
  title: string;
  status: string;
  agent_type: string;
  _repo: string;
  url: string;
  labels: string[];
}

export interface Repo {
  slug: string;
  local_dir: string;
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

export interface TaskCounts {
  ready: number;
  blocked: number;
  "in-progress": number;
  done: number;
  total: number;
}

export interface RepoStatus {
  slug: string;
  tasks: TaskCounts;
  prs: GitHubPR[];
  issues: GitHubIssue[];
  issues_open: number;
  prs_open: number;
  url: string;
}

export interface TrackerState {
  github_token: string | null;
  repos: Repo[];
  bounties: Bounty[];
  repo_statuses: RepoStatus[];
  last_updated: number;
  error: string | null;
}

// ---------------------------------------------------------------------------
// Tracker — GitHub-native, no external API
// ---------------------------------------------------------------------------

export class Tracker extends EventEmitter {
  private pollTimer: ReturnType<typeof setInterval> | null = null;
  private _trackedEntries: string[] = [];
  private _state: TrackerState = {
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
        if (Array.isArray(data.tracked_entries)) this._trackedEntries = data.tracked_entries;
      }
    } catch { /* ignore */ }
  }

  private saveConfig(): void {
    const data = {
      github_token: this._state.github_token,
      tracked_entries: this._trackedEntries,
    };
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(data, null, 2));
  }

  // -----------------------------------------------------------------------
  // Public API
  // -----------------------------------------------------------------------

  setGitHubToken(token: string): void {
    this._state.github_token = token || null;
    this.saveConfig();
    this.emit("update");
    this.refresh();
  }

  addRepo(slug: string): void {
    if (!this._trackedEntries.includes(slug)) {
      this._trackedEntries.push(slug);
      this.saveConfig();
      this.emit("update");
      this.refresh();
    }
  }

  removeRepo(slug: string): void {
    this._trackedEntries = this._trackedEntries.filter(e => e !== slug);
    this.saveConfig();
    this.emit("update");
    this.refresh();
  }

  getTrackedEntries(): string[] {
    return [...this._trackedEntries];
  }

  getState(): TrackerState & { tracked_entries: string[] } {
    return { ...this._state, tracked_entries: [...this._trackedEntries] };
  }

  hasGitHubToken(): boolean {
    return this._state.github_token != null && this._state.github_token.length > 0;
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  start(): void {
    this.refresh();
    // Poll GitHub every 5 minutes
    this.pollTimer = setInterval(() => this.refresh(), 5 * 60_000);
  }

  stop(): void {
    if (this.pollTimer) {
      clearInterval(this.pollTimer);
      this.pollTimer = null;
    }
  }

  // -----------------------------------------------------------------------
  // Refresh — fetch all data from GitHub
  // -----------------------------------------------------------------------

  async refresh(): Promise<void> {
    try {
      // Resolve tracked entries to repo slugs
      const repoSlugs: string[] = [];
      for (const entry of this._trackedEntries) {
        if (entry.includes("/")) {
          repoSlugs.push(entry);
        } else if (this._state.github_token) {
          const ownerRepos = await this.fetchGitHub<any[]>(`/users/${entry}/repos?per_page=100&sort=updated`);
          for (const r of ownerRepos ?? []) {
            repoSlugs.push(r.full_name);
          }
        }
      }

      this._state.repos = repoSlugs.map(slug => ({ slug, local_dir: "" }));

      // Build per-repo status
      const statuses: RepoStatus[] = [];
      const allBounties: Bounty[] = [];

      for (const slug of repoSlugs) {
        const status: RepoStatus = {
          slug,
          tasks: { ready: 0, blocked: 0, "in-progress": 0, done: 0, total: 0 },
          prs: [],
          issues: [],
          issues_open: 0,
          prs_open: 0,
          url: `https://github.com/${slug}`,
        };

        if (this._state.github_token) {
          try {
            // PRs
            const prs = await this.fetchGitHub<any[]>(`/repos/${slug}/pulls?state=open&per_page=20`);
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

            // Issues (exclude PRs)
            const issues = await this.fetchGitHub<any[]>(`/repos/${slug}/issues?state=open&per_page=30`);
            status.issues = (issues ?? [])
              .filter((i: any) => !i.pull_request)
              .map((i: any) => ({
                number: i.number,
                title: i.title,
                state: i.state,
                labels: (i.labels ?? []).map((l: any) => l.name),
                url: i.html_url ?? "",
              }));
            status.issues_open = status.issues.length;

            // Compute task counts from labels
            for (const issue of status.issues) {
              const hasAgent = issue.labels.some((l: string) => l.startsWith("agent:"));
              if (!hasAgent) continue;
              status.tasks.total++;
              if (issue.labels.includes("status:ready")) status.tasks.ready++;
              else if (issue.labels.includes("status:in-progress")) status.tasks["in-progress"]++;
              else if (issue.labels.includes("status:blocked")) status.tasks.blocked++;
              else if (issue.labels.includes("status:done")) status.tasks.done++;

              const agentLabel = issue.labels.find((l: string) => l.startsWith("agent:"));
              const statusLabel = issue.labels.find((l: string) => l.startsWith("status:"));
              allBounties.push({
                number: issue.number,
                title: issue.title,
                status: statusLabel ? statusLabel.replace("status:", "") : "open",
                agent_type: agentLabel ? agentLabel.replace("agent:", "") : "",
                _repo: slug,
                url: issue.url,
                labels: issue.labels,
              });
            }
          } catch {
            // GitHub fetch failed — continue without data
          }
        }

        statuses.push(status);
      }

      this._state.bounties = allBounties;
      this._state.repo_statuses = statuses;
      this._state.last_updated = Date.now();
      this._state.error = null;
    } catch (err: any) {
      this._state.error = err.message ?? String(err);
    }

    this.emit("update");
  }

  // -----------------------------------------------------------------------
  // GitHub HTTP helper
  // -----------------------------------------------------------------------

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
}
