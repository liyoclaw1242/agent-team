import { ipcMain, BrowserWindow } from "electron";
import { Supervisor, LogEntry } from "./supervisor";
import { Tracker } from "./tracker";

export function setupIPC(supervisor: Supervisor, tracker: Tracker): void {
  // --- Agent handlers ---
  ipcMain.handle("get-agents", () => supervisor.getAllAgents());
  ipcMain.handle("get-agent", (_e, id: string) => supervisor.getAgent(id));
  ipcMain.handle("get-health", () => supervisor.getHealth());
  ipcMain.handle("get-agent-logs", (_e, id: string) => supervisor.getAgentLogs(id));
  ipcMain.handle("create-agent", (_e, role: string, repoSlug: string) => {
    const validRoles = ["be", "fe", "ops", "arch", "design", "qa", "debug"];
    if (!role || !validRoles.includes(role)) {
      return { ok: false, error: `Invalid role. Must be one of: ${validRoles.join(", ")}` };
    }
    if (!repoSlug || !/^[a-zA-Z0-9._-]+\/[a-zA-Z0-9._-]+$/.test(repoSlug)) {
      return { ok: false, error: "Invalid repo format. Must be owner/repo" };
    }
    // Check duplicate
    const existing = supervisor.getAllAgents().find(
      a => a.role === role && a.repo === repoSlug && !["dead", "error"].includes(a.status)
    );
    if (existing) {
      return { ok: false, error: `${role.toUpperCase()} already running on ${repoSlug.split("/")[1]}` };
    }
    return { ok: true, agent_id: supervisor.createAgent(role, repoSlug) };
  });
  ipcMain.handle("stop-agent", async (_e, id: string) => {
    const err = await supervisor.stopAgent(id);
    return { ok: !err, error: err };
  });
  ipcMain.handle("restart-agent", async (_e, id: string) => {
    const err = await supervisor.restartAgent(id);
    return { ok: !err, error: err };
  });

  ipcMain.on("write-agent-input", (_e, id: string, data: string) => {
    supervisor.writeToAgent(id, data);
  });

  // --- Tracker handlers ---
  ipcMain.handle("get-tracker", () => tracker.getState());
  ipcMain.handle("set-github-token", (_e, token: string) => {
    tracker.setGitHubToken(token);
    return { ok: true };
  });
  // set-api-url removed — no bounty board API
  ipcMain.handle("refresh-tracker", async () => {
    await tracker.refresh();
    return { ok: true };
  });
  ipcMain.handle("add-repo", (_e, slug: string) => {
    tracker.addRepo(slug);
    return { ok: true };
  });
  ipcMain.handle("remove-repo", (_e, slug: string) => {
    tracker.removeRepo(slug);
    return { ok: true };
  });
  ipcMain.handle("get-tracked-entries", () => {
    return tracker.getTrackedEntries();
  });

  // --- Push events ---
  supervisor.on("agent:log", (agentId: string, entry: LogEntry) => {
    for (const win of BrowserWindow.getAllWindows()) {
      win.webContents.send("agent-log", agentId, entry);
    }
  });

  supervisor.on("agent:pty-data", (agentId: string, data: string) => {
    for (const win of BrowserWindow.getAllWindows()) {
      win.webContents.send("agent-pty-data", agentId, data);
    }
  });

  supervisor.on("agent:update", (agentId: string) => {
    const data = supervisor.getAgent(agentId);
    for (const win of BrowserWindow.getAllWindows()) {
      win.webContents.send("agent-status", agentId, data);
    }
  });

  tracker.on("update", () => {
    const state = tracker.getState();
    for (const win of BrowserWindow.getAllWindows()) {
      win.webContents.send("tracker-update", state);
    }
  });
}
