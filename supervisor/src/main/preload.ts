import { contextBridge, ipcRenderer } from "electron";

contextBridge.exposeInMainWorld("bridge", {
  // Agents
  getAgents: () => ipcRenderer.invoke("get-agents"),
  getAgent: (id: string) => ipcRenderer.invoke("get-agent", id),
  getHealth: () => ipcRenderer.invoke("get-health"),
  getAgentLogs: (id: string) => ipcRenderer.invoke("get-agent-logs", id),
  createAgent: (role: string, repo: string) => ipcRenderer.invoke("create-agent", role, repo),
  stopAgent: (id: string) => ipcRenderer.invoke("stop-agent", id),
  restartAgent: (id: string) => ipcRenderer.invoke("restart-agent", id),
  writeAgentInput: (id: string, data: string) => ipcRenderer.send("write-agent-input", id, data),

  // Tracker
  getTracker: () => ipcRenderer.invoke("get-tracker"),
  setGitHubToken: (token: string) => ipcRenderer.invoke("set-github-token", token),
  setApiUrl: (url: string) => ipcRenderer.invoke("set-api-url", url),
  refreshTracker: () => ipcRenderer.invoke("refresh-tracker"),
  addRepo: (slug: string) => ipcRenderer.invoke("add-repo", slug),
  removeRepo: (slug: string) => ipcRenderer.invoke("remove-repo", slug),
  getTrackedEntries: () => ipcRenderer.invoke("get-tracked-entries"),

  // Real-time push
  onLogEntry: (cb: (agentId: string, entry: any) => void) => {
    ipcRenderer.on("agent-log", (_e, agentId, entry) => cb(agentId, entry));
  },
  onStatusUpdate: (cb: (agentId: string, data: any) => void) => {
    ipcRenderer.on("agent-status", (_e, agentId, data) => cb(agentId, data));
  },
  onTrackerUpdate: (cb: (state: any) => void) => {
    ipcRenderer.on("tracker-update", (_e, state) => cb(state));
  },
  onPtyData: (cb: (agentId: string, data: string) => void) => {
    ipcRenderer.on("agent-pty-data", (_e, agentId, data) => cb(agentId, data));
  },
});
