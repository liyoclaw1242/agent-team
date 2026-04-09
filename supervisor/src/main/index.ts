import { app, BrowserWindow, Tray, Menu, nativeImage, Notification } from "electron";
import * as path from "path";
import * as http from "http";
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
// HTTP API (lightweight status endpoint)
// ---------------------------------------------------------------------------

function startAPIServer(sup: Supervisor): void {
  const PORT = 3200;

  const server = http.createServer((req, res) => {
    res.setHeader("Content-Type", "application/json");
    res.setHeader("Access-Control-Allow-Origin", "*");

    const url = req.url || "/";

    // GET /api/agents — simple list
    if (url === "/api/agents" && req.method === "GET") {
      const agents = sup.getAllAgents().map(a => ({
        id: a.agent_id,
        role: a.role,
        repo: a.repo,
        status: a.status,
        cycle: a.cycle,
      }));
      res.writeHead(200);
      res.end(JSON.stringify(agents));
      return;
    }

    // GET /api/agents/:id — detailed
    const match = url.match(/^\/api\/agents\/(.+)$/);
    if (match && req.method === "GET") {
      const agent = sup.getAgent(decodeURIComponent(match[1]));
      if (!agent) {
        res.writeHead(404);
        res.end(JSON.stringify({ error: "not found" }));
        return;
      }
      res.writeHead(200);
      res.end(JSON.stringify(agent));
      return;
    }

    // GET /api/health — overview
    if (url === "/api/health") {
      const agents = sup.getAllAgents();
      const alive = agents.filter(a => !["dead", "restarting"].includes(a.status)).length;
      const cost = agents.reduce((s, a) => s + (a.cost_usd || 0), 0);
      res.writeHead(200);
      res.end(JSON.stringify({
        agents_alive: alive,
        agents_total: agents.length,
        cost_usd: Math.round(cost * 100) / 100,
      }));
      return;
    }

    // POST /api/agents — create agent { role, repo }
    if (url === "/api/agents" && req.method === "POST") {
      let body = "";
      req.on("data", (chunk: Buffer) => { body += chunk; });
      req.on("end", () => {
        try {
          const { role, repo } = JSON.parse(body);
          const validRoles = ["be", "fe", "ops", "arch", "design", "qa", "debug"];
          if (!role || !validRoles.includes(role)) {
            res.writeHead(400);
            res.end(JSON.stringify({ error: `invalid role, must be one of: ${validRoles.join(", ")}` }));
            return;
          }
          if (!repo) {
            res.writeHead(400);
            res.end(JSON.stringify({ error: "repo required (e.g. owner/repo)" }));
            return;
          }
          const agentId = sup.createAgent(role, repo);
          res.writeHead(201);
          res.end(JSON.stringify({ ok: true, agent_id: agentId }));
        } catch {
          res.writeHead(400);
          res.end(JSON.stringify({ error: "invalid JSON body" }));
        }
      });
      return;
    }

    // DELETE /api/agents/:id — stop agent
    const delMatch = url.match(/^\/api\/agents\/(.+)$/);
    if (delMatch && req.method === "DELETE") {
      sup.stopAgent(decodeURIComponent(delMatch[1])).then((err) => {
        if (err) {
          res.writeHead(404);
          res.end(JSON.stringify({ error: err }));
        } else {
          res.writeHead(200);
          res.end(JSON.stringify({ ok: true }));
        }
      });
      return;
    }

    res.writeHead(404);
    res.end(JSON.stringify({ error: "not found" }));
  });

  server.listen(PORT, "127.0.0.1", () => {
    console.log(`[API] HTTP server listening on http://127.0.0.1:${PORT}`);
  });

  server.on("error", (err: any) => {
    if (err.code === "EADDRINUSE") {
      console.log(`[API] Port ${PORT} in use, skipping HTTP server`);
    }
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

  // Repos are managed manually via Settings — no auto-add from agents

  createWindow();
  createTray();
  setupIPC(supervisor, tracker);
  setupNotifications(supervisor);
  startAPIServer(supervisor);

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
