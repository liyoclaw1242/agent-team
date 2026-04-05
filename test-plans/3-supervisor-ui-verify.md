# Test Plan: Verify Supervisor UI 三欄佈局 + keyboard + cost tracking

- **Issue**: liyoclaw1242/agent-team#3
- **PR under test**: (TBD — will be the PR from #2)
- **Author**: qa-20260405-1518319
- **Date**: 2026-04-05
- **Dimensions**: UI (Electron/Chrome MCP) | API (IPC bridge) | Edge Cases

## Prerequisites

- [ ] FE PR from #2 merged or checked out
- [ ] Electron app builds: `cd supervisor && npm run build` (or equivalent)
- [ ] Electron app launches: `npm start` or `electron .`
- [ ] At least one agent repo configured in settings so sidebar has data

---

## UI Verification (Chrome MCP / Electron window)

### U1: Three-panel layout renders correctly
- **Action**: Launch Electron app, observe main window
- **Expected**: Three panels visible — sidebar (240px, left) | main area (flex-1, center) | properties panel hidden (no agent selected)
- **Tool**: Chrome MCP screenshot

### U2: Sidebar width is 240px
- **Action**: Inspect sidebar element with CSS var `--sidebar-w`
- **Expected**: Sidebar computed width = 240px, does not flex
- **Tool**: Chrome MCP / DevTools

### U3: Sidebar is scrollable when content overflows
- **Action**: Add enough repos/agents to overflow sidebar height, then scroll
- **Expected**: `.sidebar-scroll` area scrolls vertically, header stays fixed
- **Tool**: Chrome MCP

### U4: Properties panel slides in on agent select
- **Action**: Click an agent in the sidebar repos list
- **Expected**: Properties panel (320px) appears on right with slide animation, has class `.open`
- **Tool**: Chrome MCP screenshot before/after

### U5: Properties panel slides out on agent deselect
- **Action**: Press `Esc` or click the same agent again
- **Expected**: Properties panel slides out, `.open` class removed
- **Tool**: Chrome MCP screenshot

### U6: Window resizing doesn't break layout
- **Action**: Resize window to minimum (e.g. 800x400) and maximum (fullscreen)
- **Expected**: Sidebar stays 240px, properties stays 320px (when open), main area flexes. No overflow, no broken elements.
- **Tool**: Chrome MCP resize + screenshot

---

## Sidebar Verification

### U7: Title bar shows "Agent Team" and is draggable
- **Action**: Observe sidebar header, attempt to drag window by title bar
- **Expected**: Text reads "Agent Team", header has `-webkit-app-region: drag`, window moves on drag
- **Tool**: Chrome MCP

### U8: Settings gear opens Settings modal
- **Action**: Click the gear icon (`#btn-settings`) in sidebar header
- **Expected**: Settings modal appears (existing behavior preserved)
- **Tool**: Chrome MCP

### U9: Inbox section shows "Pending Approvals" with badge (0)
- **Action**: Observe inbox section in sidebar
- **Expected**: Shows envelope icon + "Approvals" text, badge shows "0"
- **Tool**: Chrome MCP

### U10: Repos accordion expand/collapse
- **Action**: Click a repo section header to collapse, then click again to expand
- **Expected**: Agent list under repo hides/shows with accordion behavior
- **Tool**: Chrome MCP

### U11: Repos accordion shows agents under each repo
- **Action**: Expand a repo section that has running agents
- **Expected**: Each agent listed with role, status indicator, agent ID
- **Tool**: Chrome MCP

### U12: Repos accordion shows active tasks
- **Action**: Observe agent entries that have claimed tasks
- **Expected**: Active task shown (issue number or title) under the agent
- **Tool**: Chrome MCP

### U13: [+] button opens role picker, creates agent
- **Action**: Click the [+] button on a repo section
- **Expected**: Role picker modal appears with role options. Selecting a role calls `window.bridge.createAgent()` and new agent appears in sidebar.
- **Tool**: Chrome MCP

---

## Breadcrumb Bar Verification

### U14: Shows "Agent Team" or similar when nothing selected
- **Action**: Deselect all agents, observe breadcrumb bar
- **Expected**: Breadcrumb shows neutral text (e.g., "No agent selected" or "Agent Team")
- **Tool**: Chrome MCP

### U15: Shows "Repo > Agent" when agent selected
- **Action**: Select an agent in sidebar
- **Expected**: Breadcrumb updates to show "RepoName > AgentID" with separator
- **Tool**: Chrome MCP

### U16: Keyboard shortcut hints visible on right side
- **Action**: Observe right side of breadcrumb bar
- **Expected**: Shows hints: `⌘K search`, `N new agent`, `R refresh`, `1-9 switch`
- **Tool**: Chrome MCP

---

## Dashboard Verification (no agent selected)

### U17: Dashboard visible when no agent selected
- **Action**: Ensure no agent is selected
- **Expected**: Main content shows dashboard view (not terminal)
- **Tool**: Chrome MCP screenshot

### U18: Agent count card
- **Action**: Read dashboard cards
- **Expected**: Card shows "Agents" label with "alive/total" format (e.g., "0/0" or "2/3")
- **Tool**: Chrome MCP

### U19: Total cost card
- **Action**: Read dashboard cards
- **Expected**: Card shows "Total Cost" with dollar amount (e.g., "$0.00")
- **Tool**: Chrome MCP

### U20: Tasks ready card
- **Action**: Read dashboard cards
- **Expected**: Card shows task count matching status labels
- **Tool**: Chrome MCP

---

## Terminal Verification (agent selected)

### U21: xterm.js renders full-width in main content
- **Action**: Select an agent
- **Expected**: Terminal fills the main-content area, no horizontal scrollbar, proper fit
- **Tool**: Chrome MCP screenshot

### U22: Terminal receives real-time PTY data
- **Action**: Select a running agent, wait for output
- **Expected**: Terminal shows live output from agent process (poll logs, task output, etc.)
- **Tool**: Chrome MCP (observe text appearing)

### U23: Switching agents switches terminal
- **Action**: Select agent A, note terminal content. Select agent B.
- **Expected**: Terminal content changes to agent B's output. Switch back to A — shows A's output.
- **Tool**: Chrome MCP

---

## Properties Panel Verification

### U24: Shows agent role, ID, status dot, uptime
- **Action**: Select an agent, read properties panel
- **Expected**: Role (e.g., "BE"), agent ID, colored status dot, uptime displayed
- **Tool**: Chrome MCP

### U25: Cost bar — green when < 60%
- **Action**: Select agent with cost < $6.00 (< 60% of $10 budget)
- **Expected**: Cost bar fill is green
- **Tool**: Chrome MCP screenshot

### U26: Cost bar — yellow when 60-80%
- **Action**: Select agent with cost $6.00-$8.00
- **Expected**: Cost bar fill has `.warning` class, appears yellow
- **Tool**: Chrome MCP screenshot

### U27: Cost bar — red when > 80%
- **Action**: Select agent with cost > $8.00
- **Expected**: Cost bar fill has `.danger` class, appears red
- **Tool**: Chrome MCP screenshot

### U28: Current task as clickable GitHub link
- **Action**: Select agent with an active task
- **Expected**: Task shown as "#{N} title" linking to `https://github.com/{repo}/issues/{N}`
- **Tool**: Chrome MCP — verify href

### U29: Stop button works
- **Action**: Click Stop button in properties panel
- **Expected**: Agent stops, status updates, calls `window.bridge.stopAgent()`
- **Tool**: Chrome MCP + verify agent disappears or shows stopped status

### U30: Restart button works
- **Action**: Click Restart button in properties panel
- **Expected**: Agent restarts, status resets, calls appropriate restart IPC
- **Tool**: Chrome MCP + verify agent shows alive status after restart

---

## Keyboard Shortcuts Verification

### K1: Cmd+K — command palette
- **Action**: Press `Cmd+K`
- **Expected**: Command palette / search appears (or placeholder alert)
- **Tool**: Chrome MCP

### K2: 1-9 — select nth agent
- **Action**: Press `1` with at least 1 agent running
- **Expected**: First agent selected, terminal + properties shown
- **Tool**: Chrome MCP

### K3: N — create agent
- **Action**: Press `N`
- **Expected**: Role picker appears for first repo
- **Tool**: Chrome MCP

### K4: Esc — deselect agent
- **Action**: Select an agent, then press `Esc`
- **Expected**: Agent deselected, properties panel closes, dashboard shown
- **Tool**: Chrome MCP

### K5: R — refresh
- **Action**: Press `R`
- **Expected**: Agent/repo data refreshes (calls `window.bridge.getAgents()` or equivalent)
- **Tool**: Chrome MCP

---

## Preserved Functionality

### P1: Settings modal still works
- **Action**: Open settings via gear icon, change a setting, close
- **Expected**: Modal opens, accepts input, closes — same as before refactor
- **Tool**: Chrome MCP

### P2: Role picker still works
- **Action**: Open role picker via [+] button or N key
- **Expected**: Role picker modal appears with all roles, selection creates agent
- **Tool**: Chrome MCP

### P3: Real-time updates
- **Action**: While UI is open, start/stop agents externally
- **Expected**: Sidebar and dashboard update in real-time via `onStatusUpdate` / `onTrackerUpdate` IPC
- **Tool**: Chrome MCP + observe

---

## Edge Cases

### E1: Zero agents — empty state
- **Action**: Launch with no agents configured
- **Expected**: Sidebar shows empty repos section, dashboard shows 0/0 agents, $0.00 cost, 0 tasks. No JS errors.
- **Tool**: Chrome MCP + console check

### E2: Many agents — stress test sidebar
- **Action**: Configure 20+ agents across multiple repos
- **Expected**: Sidebar scrolls smoothly, no layout break, performance acceptable
- **Tool**: Chrome MCP

### E3: Long agent ID / repo name
- **Action**: Use an agent with a very long ID and a long repo slug
- **Expected**: Text truncates with ellipsis or wraps gracefully, no overflow
- **Tool**: Chrome MCP

### E4: Keyboard shortcuts don't fire in text inputs
- **Action**: Focus a text input (e.g., in settings modal), press `N` or `R`
- **Expected**: Character typed in input, shortcut does NOT fire
- **Tool**: Chrome MCP

### E5: Rapid agent switching
- **Action**: Quickly press 1, 2, 3, 4 in succession
- **Expected**: Terminal switches cleanly to agent 4, no stale terminals, no errors
- **Tool**: Chrome MCP + console check

---

## Coverage Matrix

| Acceptance Criterion (from #2) | Test Steps |
|-------------------------------|------------|
| Three-panel layout | U1, U2, U6 |
| Sidebar: title, inbox, repos | U7-U13 |
| Breadcrumb bar | U14-U16 |
| Dashboard (no selection) | U17-U20 |
| Terminal (agent selected) | U21-U23 |
| Properties panel | U24-U30 |
| Cost bar colors | U25-U27 |
| Stop/Restart buttons | U29-U30 |
| Keyboard shortcuts | K1-K5 |
| Settings + Role picker | P1-P2 |
| IPC calls preserved | P3 |
