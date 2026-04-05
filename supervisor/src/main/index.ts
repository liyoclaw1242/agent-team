import { app, BrowserWindow, Tray, Menu, nativeImage, Notification } from "electron";
import * as path from "path";
import { Supervisor } from "./supervisor";
import { Tracker } from "./tracker";
import { setupIPC } from "./ipc";

let mainWindow: BrowserWindow | null = null;
let tray: Tray | null = null;
let supervisor: Supervisor | null = null;
let tracker: Tracker | null = null;

// ---------------------------------------------------------------------------
// Window
// ---------------------------------------------------------------------------

function createWindow(): void {
  mainWindow = new BrowserWindow({
    width: 1060,
    height: 640,
    minWidth: 800,
    minHeight: 400,
    titleBarStyle: "hiddenInset",
    backgroundColor: "#0a0a0a",
    webPreferences: {
      preload: path.join(__dirname, "preload.js"),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });

  mainWindow.loadFile(path.join(__dirname, "../../renderer/index.html"));
  mainWindow.webContents.openDevTools({ mode: "bottom" });

  mainWindow.on("close", (e) => {
    e.preventDefault();
    mainWindow?.hide();
  });
}

// ---------------------------------------------------------------------------
// Tray
// ---------------------------------------------------------------------------

function createTray(): void {
  const icon = nativeImage.createFromDataURL(
    "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAABHNCSVQICAgIfAhkiAAAADRJREFUOE9jZKAQMFKon2HUAIZhEAb/GRj+k+IyRkZGRpIsJ9kAki0fpGFAshcMfBiQnJgAPNUEERbfzKEAAAAASUVORK5CYII="
  );
  icon.setTemplateImage(true);

  tray = new Tray(icon);
  tray.setToolTip("Agent Team");

  tray.on("click", () => {
    if (mainWindow?.isVisible()) {
      mainWindow.focus();
    } else {
      mainWindow?.show();
    }
  });

  updateTrayMenu();
}

function updateTrayMenu(): void {
  if (!tray || !supervisor) return;

  const health = supervisor.getHealth();
  const agents = supervisor.getAllAgents();

  const agentItems: Electron.MenuItemConstructorOptions[] = agents.length > 0
    ? agents.map((a) => ({
        label: `${a.role.toUpperCase()} ${a.agent_id.split("-").slice(-1)[0]} — ${a.status}${a.current_task ? ` (${a.current_task})` : ""}`,
        enabled: false,
      }))
    : [{ label: "No agents", enabled: false }];

  const createSubmenu: Electron.MenuItemConstructorOptions[] = [
    "be", "fe", "ops", "arch", "design", "qa", "debug",
  ].map((role) => ({
    label: role.toUpperCase(),
    click: () => {
      supervisor?.createAgent(role);
      setTimeout(() => updateTrayMenu(), 1000);
    },
  }));

  const menu = Menu.buildFromTemplate([
    {
      label: `${health.agents_alive}/${health.agents_total} alive · $${health.total_cost_usd.toFixed(2)}`,
      enabled: false,
    },
    { type: "separator" },
    ...agentItems,
    { type: "separator" },
    { label: "Create Agent", submenu: createSubmenu },
    {
      label: "Open Dashboard",
      click: () => { mainWindow?.show(); mainWindow?.focus(); },
    },
    { type: "separator" },
    {
      label: "Quit",
      click: () => {
        supervisor?.stop();
        app.exit(0);
      },
    },
  ]);

  tray.setContextMenu(menu);
  tray.setToolTip(`Agent Team: ${health.agents_alive}/${health.agents_total} alive`);
}

// ---------------------------------------------------------------------------
// Notifications
// ---------------------------------------------------------------------------

function setupNotifications(sv: Supervisor): void {
  sv.on("agent:created", (agentId: string, role: string) => {
    new Notification({
      title: "Agent Created",
      body: `${agentId} (${role.toUpperCase()})`,
    }).show();
  });

  sv.on("agent:dead", (agentId: string, detail: string) => {
    new Notification({
      title: "Agent Dead",
      body: `${agentId}: ${detail}`,
    }).show();
    updateTrayMenu();
  });

  sv.on("agent:restarted", (newId: string, oldId: string) => {
    new Notification({
      title: "Agent Restarted",
      body: `${oldId} → ${newId}`,
    }).show();
    updateTrayMenu();
  });

  sv.on("agent:update", () => {
    // Debounced tray refresh handled by interval below
  });
}

// ---------------------------------------------------------------------------
// App lifecycle
// ---------------------------------------------------------------------------

app.whenReady().then(() => {
  supervisor = new Supervisor();
  supervisor.start();

  tracker = new Tracker();
  tracker.start();

  // Sync agent repos → tracker so their repos always appear
  const syncAgentRepos = () => {
    if (!supervisor || !tracker) return;
    const repos = [...new Set(supervisor.getAllAgents().map((a) => a.repo).filter(Boolean))];
    tracker.setAgentRepos(repos);
  };
  supervisor.on("agent:update", syncAgentRepos);
  supervisor.on("agent:created", syncAgentRepos);
  supervisor.on("agent:stopped", syncAgentRepos);

  createWindow();
  createTray();
  setupIPC(supervisor, tracker);
  setupNotifications(supervisor);

  // Refresh tray periodically
  setInterval(() => updateTrayMenu(), 15_000);
});

app.on("window-all-closed", () => {
  // Keep running in tray
});

app.on("activate", () => {
  if (mainWindow) {
    mainWindow.show();
  } else {
    createWindow();
  }
});

app.on("before-quit", () => {
  supervisor?.stop();
  tracker?.stop();
});
