import { EventEmitter } from "events";
import * as fs from "fs";
import * as path from "path";
import * as os from "os";

const LOG_DIR = path.join(os.homedir(), ".agent-team", "logs");

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

export type AgentStatus =
  | "starting"
  | "polling"
  | "working"
  | "sleeping"
  | "rate_limited"
  | "error"
  | "dead"
  | "restarting";

export interface LogEntry {
  timestamp: number;
  type: "system" | "assistant" | "tool_call" | "tool_result" | "status" | "error";
  text: string;
}

export interface AgentState {
  agent_id: string;
  role: string;
  repo: string;
  status: AgentStatus;
  cycle: number;
  detail: string;
  current_task: string | null;
  error: string | null;
  cost_usd: number;
  restart_count: number;
  created_at: number;
  last_activity: number;
  session_id: string | null;
  end_reason: string | null; // SDK ResultMessage.subtype: success, error_max_turns, error_max_budget_usd, error_during_execution
}

export interface AgentAPI {
  agent_id: string;
  role: string;
  repo: string;
  status: AgentStatus;
  cycle: number;
  detail: string;
  current_task: string | null;
  error: string | null;
  cost_usd: number;
  restart_count: number;
  last_activity_seconds_ago: number;
  session_id: string | null;
}

// ---------------------------------------------------------------------------
// Managed Agent
// ---------------------------------------------------------------------------

class ManagedAgent {
  state: AgentState;
  logs: LogEntry[] = [];
  private abortController: AbortController | null = null;
  private onUpdate: () => void;
  private onLog: (agentId: string, entry: LogEntry) => void;

  private static MAX_LOG_LINES = 2000;

  constructor(
    public role: string,
    public agentId: string,
    public repoSlug: string,
    onUpdate: () => void,
    onLog: (agentId: string, entry: LogEntry) => void,
  ) {
    this.onUpdate = onUpdate;
    this.onLog = onLog;
    this.state = {
      agent_id: agentId,
      role,
      repo: repoSlug,
      status: "starting",
      cycle: 0,
      detail: "Launching...",
      current_task: null,
      error: null,
      cost_usd: 0,
      restart_count: 0,
      created_at: Date.now(),
      last_activity: Date.now(),
      session_id: null,
      end_reason: null,
    };
  }

  private pushLog(type: LogEntry["type"], text: string): void {
    const entry: LogEntry = { timestamp: Date.now(), type, text };
    this.logs.push(entry);
    if (this.logs.length > ManagedAgent.MAX_LOG_LINES) {
      this.logs.splice(0, this.logs.length - ManagedAgent.MAX_LOG_LINES);
    }
    this.onLog(this.agentId, entry);
  }

  async start(): Promise<void> {
    console.log(`[AGENT] start() called for ${this.agentId}`);

    let query: any;
    try {
      const sdk = await import("@anthropic-ai/claude-agent-sdk");
      query = sdk.query;
      console.log(`[AGENT] SDK imported, query type: ${typeof query}`);
    } catch (importErr: any) {
      console.error(`[AGENT] SDK import failed:`, importErr.message);
      this.pushLog("error", `SDK import failed: ${importErr.message}`);
      this.state.status = "dead";
      this.onUpdate();
      return;
    }

    this.abortController = new AbortController();

    const prompt = [
      `You are agent \`${this.agentId}\`.`,
      `Execute /create-agent-employ ${this.role} ${this.repoSlug}`,
      `When asked to generate an Agent ID, use exactly: ${this.agentId}`,
      `When asked which repo, answer: ${this.repoSlug}`,
      `When asked to confirm (Ready to start? y/n), answer: y`,
    ].join("\n");

    this.pushLog("system", `Session starting for ${this.role.toUpperCase()} agent...`);
    this.pushLog("system", `Agent ID: ${this.agentId}`);
    this.pushLog("system", `Repo: ${this.repoSlug}`);
    this.pushLog("system", "─".repeat(60));
    this.onUpdate();

    try {
      console.log(`[SDK] Calling query() for ${this.agentId}...`);
      const stream = query({
        prompt,
        options: {
          allowedTools: [
            "Read", "Edit", "Write", "Bash", "Glob", "Grep",
            "Agent", "Skill",
          ],
          permissionMode: "acceptEdits",
          pathToClaudeCodeExecutable: process.env.CLAUDE_PATH || "claude",
        },
      } as any);
      console.log(`[SDK] Got stream for ${this.agentId}:`, typeof stream);

      for await (const message of stream) {
        const msg = message as any;
        this.state.last_activity = Date.now();

        this.parseMessage(msg);

        this.onUpdate();
      }
    } catch (err: any) {
      if (err.name === "AbortError") {
        this.pushLog("system", "Session stopped by supervisor.");
      } else {
        this.state.error = err.message ?? String(err);
        this.pushLog("error", `CRASH: ${this.state.error}`);
        const logFile = path.join(LOG_DIR, `${this.agentId}.log`);
        fs.appendFileSync(logFile, `[${new Date().toISOString()}] crashed: ${this.state.error}\n`);
      }
    }

    this.state.status = "dead";
    this.pushLog("status", `Agent ${this.agentId} is now DEAD`);
    this.onUpdate();
  }

  stop(): void {
    this.abortController?.abort();
  }

  // -----------------------------------------------------------------------
  // Message parsing — handle all SDK message shapes
  // -----------------------------------------------------------------------

  private parseMessage(msg: any): void {
    const type: string = msg.type ?? "unknown";

    if (type === "system") {
      if (msg.subtype === "init") {
        this.state.session_id = msg.session_id ?? null;
        this.pushLog("system", `Session: ${this.state.session_id}`);
      }
      // Ignore task_started, task_progress etc. — just update activity
      return;
    }

    if (type === "result") {
      this.state.session_id = msg.session_id ?? this.state.session_id;
      this.state.cost_usd += msg.total_cost_usd ?? 0;
      this.state.end_reason = msg.subtype ?? "unknown";
      this.pushLog("system", "─".repeat(60));
      this.pushLog("system",
        `Session ended: ${msg.subtype} | Cost: $${(msg.total_cost_usd ?? 0).toFixed(4)}`
      );
      const logFile = path.join(LOG_DIR, `${this.agentId}.log`);
      fs.appendFileSync(logFile,
        `[${new Date().toISOString()}] ended: ${msg.subtype}, cost=$${(msg.total_cost_usd ?? 0).toFixed(4)}\n`
      );
      return;
    }

    if (type === "rate_limit_event") {
      this.state.status = "rate_limited";
      this.state.error = "rate_limited";
      this.pushLog("error", `Rate limited: ${JSON.stringify(msg).slice(0, 200)}`);
      return;
    }

    // assistant / user — try multiple content paths
    const content = msg.content ?? msg.message?.content ?? null;

    if (type === "assistant") {
      if (Array.isArray(content)) {
        for (const block of content) {
          if (block.type === "text" && block.text) {
            this.pushLog("assistant", block.text);
            this.inferStatus(block.text);
          } else if (block.type === "tool_use") {
            const input = this.formatToolInput(block.name, block.input);
            this.pushLog("tool_call", `${block.name}: ${input}`);
            this.inferStatusFromTool(block.name, block.input);
          }
        }
      } else if (typeof content === "string" && content) {
        this.pushLog("assistant", content);
        this.inferStatus(content);
      }
      return;
    }

    if (type === "user") {
      if (Array.isArray(content)) {
        for (const block of content) {
          const output =
            block.content ?? block.output ?? block.text ?? null;
          if (output) {
            const text = typeof output === "string" ? output : JSON.stringify(output);
            const truncated = text.length > 500
              ? text.slice(0, 500) + `\n... (${text.length} chars)`
              : text;
            this.pushLog("tool_result", truncated);
          }
        }
      }
      return;
    }
  }

  // -----------------------------------------------------------------------
  // Status inference
  // -----------------------------------------------------------------------

  private inferStatus(text: string): void {
    const cycleMatch = text.match(/Cycle #(\d+)/);
    if (cycleMatch) this.state.cycle = parseInt(cycleMatch[1], 10);

    const claimMatch = text.match(/Claimed #(\d+).*?\(([^)]+)\)/);
    if (claimMatch) this.state.current_task = `${claimMatch[2]}#${claimMatch[1]}`;

    if (text.includes("Task #") && text.includes("complete")) {
      this.state.current_task = null;
    }

    if (text.includes("Sleeping") || text.includes("sleeping") || text.includes("next poll in")) {
      this.state.status = "sleeping";
      this.state.detail = "Sleeping until next cycle";
    } else if (text.includes("No tasks available") || text.includes("No repos registered")) {
      this.state.status = "sleeping";
      this.state.detail = "No tasks — sleeping";
    } else if (text.toLowerCase().includes("rate limit")) {
      this.state.status = "rate_limited";
      this.state.detail = "API rate limited";
      this.state.error = "rate_limited";
    } else if (text.includes("Cycle #")) {
      this.state.status = "polling";
      this.state.detail = text.split("\n")[0].slice(0, 120);
    }
  }

  private inferStatusFromTool(name: string, input: any): void {
    if (name === "Bash") {
      const cmd = typeof input === "string" ? input : input?.command ?? "";
      if (cmd.includes("/bounties?") || cmd.includes("/repos")) {
        this.state.status = "polling";
        this.state.detail = "Polling for tasks...";
      } else if (cmd.includes("git push") || cmd.includes("gh pr create")) {
        this.state.status = "working";
        this.state.detail = "Delivering output...";
      } else if (cmd.includes("sleep") || cmd.includes("Sleep")) {
        this.state.status = "sleeping";
      } else {
        this.state.status = "working";
        this.state.detail = `Running: ${cmd.slice(0, 60)}`;
      }
    } else if (["Edit", "Write", "Read", "Glob", "Grep"].includes(name)) {
      this.state.status = "working";
    }
  }

  private formatToolInput(name: string, input: any): string {
    if (!input) return "";
    if (name === "Bash") return input.command ?? JSON.stringify(input);
    if (name === "Read") return input.file_path ?? "";
    if (name === "Edit") return `${input.file_path ?? ""}`;
    if (name === "Write") return `${input.file_path ?? ""}`;
    if (name === "Glob") return input.pattern ?? "";
    if (name === "Grep") return input.pattern ?? "";
    return JSON.stringify(input).slice(0, 100);
  }
}

// ---------------------------------------------------------------------------
// Supervisor
// ---------------------------------------------------------------------------

export class Supervisor extends EventEmitter {
  private agents = new Map<string, ManagedAgent>();
  private staleTimer: ReturnType<typeof setInterval> | null = null;
  private startedAt = Date.now();

  private staleTimeouts: Record<string, number> = {
    starting: 3 * 60_000,
    polling: 10 * 60_000,
    working: 90 * 60_000,
    sleeping: 45 * 60_000,
    rate_limited: 120 * 60_000,
    error: 30 * 60_000,
  };

  private maxRestarts = 5;

  constructor() {
    super();
    fs.mkdirSync(LOG_DIR, { recursive: true });
  }

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  createAgent(role: string, repoSlug: string): string {
    const ts = new Date().toISOString().replace(/[-:.TZ]/g, "").slice(0, 15);
    const agentId = `${role}-${ts.slice(0, 8)}-${ts.slice(8)}`;

    const managed = new ManagedAgent(
      role,
      agentId,
      repoSlug,
      () => this.emit("agent:update", agentId),
      (id, entry) => this.emit("agent:log", id, entry),
    );
    this.agents.set(agentId, managed);
    managed.start().then(() => {
      // Decide whether to auto-restart based on how the session ended
      const reason = managed.state.end_reason;
      const shouldRestart = this.shouldAutoRestart(reason, managed.state);
      if (shouldRestart) {
        console.log(`[supervisor] Auto-restarting ${agentId} (reason: ${reason}, cycles: ${managed.state.cycle})`);
        setTimeout(() => this.doRestart(agentId), 5000);
      } else {
        console.log(`[supervisor] NOT restarting ${agentId} (reason: ${reason})`);
      }
    });

    this.emit("agent:created", agentId, role);
    return agentId;
  }

  async stopAgent(agentId: string): Promise<string | null> {
    const managed = this.agents.get(agentId);
    if (!managed) return `Agent ${agentId} not found`;
    managed.stop();
    managed.state.status = "dead";
    managed.state.detail = "Stopped manually";
    this.agents.delete(agentId);
    this.emit("agent:stopped", agentId);
    this.emit("agent:update", agentId);
    return null;
  }

  /**
   * Decide if an agent should be auto-restarted based on how it ended.
   *
   * SDK result subtypes:
   *   success                → agent chose to end → NO restart
   *   error_max_turns        → ran out of turns   → YES restart (session was cut short)
   *   error_max_budget_usd   → budget exhausted   → NO restart (would burn more money)
   *   error_during_execution → runtime crash       → YES restart
   *   null / unknown         → JS exception        → YES restart (if it ever ran)
   */
  private shouldAutoRestart(reason: string | null, state: AgentState): boolean {
    if (state.restart_count >= this.maxRestarts) return false;
    if (state.cycle === 0) return false; // Never successfully started

    switch (reason) {
      case "success":
        return false; // Agent decided it was done
      case "error_max_budget_usd":
        return false; // Would just burn more money
      case "error_max_turns":
        return true;  // Cut short, should continue
      case "error_during_execution":
        return true;  // Crash, retry
      default:
        return true;  // Unknown failure, try again
    }
  }

  private doRestart(agentId: string): void {
    const old = this.agents.get(agentId);
    if (!old) return;

    const role = old.role;
    const restartCount = old.state.restart_count + 1;

    if (restartCount > this.maxRestarts) {
      old.state.detail = `Exceeded max restarts (${this.maxRestarts})`;
      this.emit("agent:update", agentId);
      return;
    }

    old.stop();

    const newId = this.createAgent(role, old.repoSlug);
    const newManaged = this.agents.get(newId);
    if (newManaged) {
      newManaged.state.restart_count = restartCount;
    }

    this.emit("agent:restarted", newId, agentId);
  }

  async restartAgent(agentId: string): Promise<string | null> {
    const managed = this.agents.get(agentId);
    if (!managed) return `Agent ${agentId} not found`;
    managed.state.restart_count = 0; // Reset for manual
    this.doRestart(agentId);
    return null;
  }

  // -----------------------------------------------------------------------
  // Stale detection
  // -----------------------------------------------------------------------

  start(): void {
    this.staleTimer = setInterval(() => this.checkStale(), 30_000);
  }

  stop(): void {
    if (this.staleTimer) {
      clearInterval(this.staleTimer);
      this.staleTimer = null;
    }
    for (const [, managed] of this.agents) {
      managed.stop();
    }
  }

  private checkStale(): void {
    const now = Date.now();
    for (const [agentId, managed] of this.agents) {
      const { status, last_activity, restart_count } = managed.state;
      if (status === "dead" || status === "restarting") continue;

      const timeout = this.staleTimeouts[status] ?? 60 * 60_000;
      if (now - last_activity > timeout) {
        managed.state.status = "dead";
        managed.state.detail = `Stale: no activity for ${Math.round((now - last_activity) / 60_000)}min`;
        this.emit("agent:dead", agentId, managed.state.detail);
        if (restart_count < this.maxRestarts) {
          this.doRestart(agentId);
        }
      }
    }
  }

  // -----------------------------------------------------------------------
  // API
  // -----------------------------------------------------------------------

  getAgentLogs(agentId: string): LogEntry[] {
    return this.agents.get(agentId)?.logs ?? [];
  }

  getAllAgents(): AgentAPI[] {
    const now = Date.now();
    return Array.from(this.agents.values()).map((m) => ({
      agent_id: m.state.agent_id,
      role: m.state.role,
      repo: m.state.repo,
      status: m.state.status,
      cycle: m.state.cycle,
      detail: m.state.detail,
      current_task: m.state.current_task,
      error: m.state.error,
      cost_usd: Math.round(m.state.cost_usd * 10000) / 10000,
      restart_count: m.state.restart_count,
      last_activity_seconds_ago: Math.round((now - m.state.last_activity) / 1000),
      session_id: m.state.session_id,
    }));
  }

  getAgent(agentId: string): AgentAPI | null {
    const managed = this.agents.get(agentId);
    if (!managed) return null;
    return {
      agent_id: managed.state.agent_id,
      role: managed.state.role,
      repo: managed.state.repo,
      status: managed.state.status,
      cycle: managed.state.cycle,
      detail: managed.state.detail,
      current_task: managed.state.current_task,
      error: managed.state.error,
      cost_usd: Math.round(managed.state.cost_usd * 10000) / 10000,
      restart_count: managed.state.restart_count,
      last_activity_seconds_ago: Math.round((Date.now() - managed.state.last_activity) / 1000),
      session_id: managed.state.session_id,
    };
  }

  getHealth() {
    const agents = Array.from(this.agents.values());
    const alive = agents.filter((m) => !["dead", "restarting"].includes(m.state.status)).length;
    const totalCost = agents.reduce((sum, m) => sum + m.state.cost_usd, 0);
    return {
      status: "ok",
      uptime_seconds: Math.round((Date.now() - this.startedAt) / 1000),
      agents_total: agents.length,
      agents_alive: alive,
      total_cost_usd: Math.round(totalCost * 10000) / 10000,
    };
  }
}
