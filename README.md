# Agent Team

Configurable agent team for Claude Code. Spawn autonomous polling agents with 8 specialized roles that claim and execute tasks from a bounty board API.

## Roles

| # | Role | Description |
|---|------|-------------|
| 1 | **BE** | Backend engineer — APIs, DB, business logic |
| 2 | **FE** | Frontend engineer — UI, components, styling |
| 3 | **OPS** | DevOps — CI/CD, deployment, infrastructure |
| 4 | **ARCH** | Software architect — system design, ADRs, API contracts, request decomposition |
| 5 | **DESIGN** | UI/UX designer — design audit, component design, a11y |
| 6 | **QA** | Code reviewer — reviews agent PRs, hands-on verification |
| 7 | **DEBUG** | Investigator — root cause analysis, bug diagnosis |
| 8 | **PM** | Project manager — dependency tracking, issue triage, unblocking |

## Install

Clone this repo, then copy the files into your `.claude/` directory.

### Global install (all projects)

```bash
git clone https://github.com/youruser/agent-team.git
cp -r agent-team/commands/ ~/.claude/commands/
cp -r agent-team/roles/ ~/.claude/roles/
cp -r agent-team/skills/ ~/.claude/skills/
cp agent-team/agent-team.config.md ~/.claude/agent-team.config.md
```

### Project install (single repo, shareable with team)

```bash
git clone https://github.com/youruser/agent-team.git
cp -r agent-team/commands/ .claude/commands/
cp -r agent-team/roles/ .claude/roles/
cp -r agent-team/skills/ .claude/skills/
cp agent-team/agent-team.config.md .claude/agent-team.config.md
```

## Usage

In any Claude Code terminal:

```
/create-agent-employ
```

Select a role, confirm the contract, and the agent starts polling.

Run multiple agents by opening multiple terminals — e.g. 2x FE + 1x BE + 1x QA.

## Configuration

Edit `agent-team.config.md` to customize behavior:

```markdown
---
api_url: http://localhost:8000    # Bounty board API
cycle_interval: 30                 # Minutes between polls
---

# Agent Team Configuration

## inject

- Commit messages in Traditional Chinese
- Run `pnpm lint` before every commit
- Never auto-merge — always wait for human review
```

The `## inject` section is free-form text appended to every role's context.

### Config priority

If both exist, project-level overrides user-level:

1. `.claude/agent-team.config.md` (project)
2. `~/.claude/agent-team.config.md` (global)
3. Defaults: `api_url=http://localhost:8000`, `cycle_interval=30`

## Customization

Since these are plain files in your `.claude/` directory, you can:

- **Edit any role** — modify `roles/be.md` to add your team's coding standards
- **Add a new role** — create `roles/sre.md`, add it to the menu in `commands/create-agent-employ.md`
- **Remove roles you don't need** — delete the file, remove from menu
- **Change the polling source** — edit `roles/_base.md` Step 2 to poll a different API
- **Change the output behavior** — edit `roles/_base.md` Step 7 (e.g. skip PR, just commit)

## Supervisor (auto-heal)

Instead of manually opening terminals, use the supervisor to manage agents programmatically. It monitors heartbeats and auto-restarts dead agents.

### Setup

```bash
cd agent-team/supervisor
pip install -r requirements.txt
```

### Configure

Edit `supervisor/agents.json`:

```json
{
  "agents": [
    { "role": "be", "count": 1 },
    { "role": "fe", "count": 2 },
    { "role": "qa", "count": 1 },
    { "role": "arch", "count": 1 }
  ],
  "heartbeat_timeout_minutes": 45,
  "check_interval_seconds": 60,
  "max_restarts": 5,
  "max_budget_per_agent_usd": 10.0
}
```

| Field | Description |
|-------|-------------|
| `agents[].role` | Role name (be, fe, ops, arch, design, qa, debug, pm) |
| `agents[].count` | How many agents of this role to spawn |
| `heartbeat_timeout_minutes` | Kill + restart if no heartbeat within this window |
| `check_interval_seconds` | How often the supervisor checks heartbeats |
| `max_restarts` | Max restart attempts per agent before giving up |
| `max_budget_per_agent_usd` | API cost cap per agent session |

### Run

```bash
python supervisor/supervisor.py                  # default config
python supervisor/supervisor.py my-config.json   # custom config
```

The supervisor will:
1. Spawn all agents via Claude Agent SDK
2. Check heartbeats every `check_interval_seconds`
3. Restart any agent that misses its heartbeat window
4. Log to `~/.agent-team/logs/{agent-id}.log`
5. Stop gracefully on Ctrl+C or SIGTERM

### How heartbeats work

Each agent cycle starts by touching `~/.agent-team/heartbeats/{AGENT_ID}`. The supervisor watches file mtime. If an agent's cycle takes longer than expected (stuck, crashed, rate-limited), the supervisor kills the session and spawns a fresh one.

```
Supervisor ──check──▶ ~/.agent-team/heartbeats/be-20260401-143022
                       mtime = 12 min ago  ✓ alive

Supervisor ──check──▶ ~/.agent-team/heartbeats/fe-20260401-143055
                       mtime = 50 min ago  ✗ stale → restart
```

## Structure

```
commands/
  └── create-agent-employ.md    # Factory command (user entry point)
roles/
  ├── _base.md                  # Shared polling loop protocol (with heartbeat)
  ├── be.md                     # Backend Engineer
  ├── fe.md                     # Frontend Engineer
  ├── ops.md                    # DevOps Engineer
  ├── arch.md                   # Software Architect
  ├── design.md                 # UI/UX Designer
  ├── qa.md                     # QA Engineer
  ├── debug.md                  # Investigator
  └── pm.md                     # Project Manager
skills/
  ├── bounty-agent/SKILL.md     # Execution discipline (auto-triggered)
  └── ui-icons/SKILL.md         # Icon selection (auto-triggered for DESIGN)
supervisor/
  ├── supervisor.py             # Watchdog process (Claude Agent SDK)
  ├── agents.json               # Which agents to spawn
  └── requirements.txt
agent-team.config.md            # Default configuration
```

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- A running bounty board API (default: `http://localhost:8000`)
- `gh` CLI authenticated (for PR creation)
- Python 3.11+ and `claude-agent-sdk` (for supervisor only)
