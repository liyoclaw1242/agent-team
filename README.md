# Agent Team

Autonomous agent team for Claude Code. 7 specialized roles that poll GitHub Issues, claim tasks, execute, and deliver PRs — orchestrated by ARCH as the sole dispatcher and merge authority.

**GitHub-native.** No external API. Issues + Labels + `gh` CLI manage the entire task pipeline.

## Architecture

```
FE / BE / OPS (implement) ──┐
QA (verify)                 ──┼──→ ARCH (sole dispatcher + merge) ──→ next step
Design (visual review)      ──┤
DEBUG (root cause)          ──┘
```

ARCH is the hub. All completed work routes back to ARCH for triage.

## Roles

| # | Role | Description |
|---|------|-------------|
| 1 | **BE** | Backend engineer — APIs, DB, business logic |
| 2 | **FE** | Frontend engineer — UI, components, styling |
| 3 | **OPS** | DevOps — CI/CD, deployment, infrastructure |
| 4 | **ARCH** | Software architect — sole dispatcher + merge authority, triage, decomposition |
| 5 | **DESIGN** | UI/UX designer — design audit, component design, a11y |
| 6 | **QA** | QA engineer — test plans, multi-dimensional verification |
| 7 | **DEBUG** | Investigator — root cause analysis, bug diagnosis |

## Install

```bash
git clone https://github.com/youruser/agent-team.git
cd agent-team
./sync.sh           # installs to ~/.claude/
```

Or for a single project:

```bash
./sync.sh --project  # installs to .claude/ in current directory
```

## Usage

### CLI

In any Claude Code terminal:

```
/create-agent-employ arch owner/my-repo
```

Or interactively — select a role and repo when prompted.

### Supervisor (Electron app)

The supervisor manages multiple agents with a dashboard UI, health monitoring, and auto-restart.

```bash
cd supervisor
npm install
npm run dev          # development
npm run pack         # build .dmg
```

### Supervisor HTTP API

The supervisor exposes a local API on port 3200:

```bash
# List all agents (simple)
curl http://127.0.0.1:3200/api/agents

# Agent detail (full status + health check)
curl http://127.0.0.1:3200/api/agents/{agent-id}

# Health overview
curl http://127.0.0.1:3200/api/health

# Create agent
curl -X POST http://127.0.0.1:3200/api/agents \
  -H "Content-Type: application/json" \
  -d '{"role":"fe","repo":"owner/repo"}'

# Stop agent
curl -X DELETE http://127.0.0.1:3200/api/agents/{agent-id}
```

**Create validation:**
- Role must be one of: be, fe, ops, arch, design, qa, debug
- Repo must be `owner/repo` format
- No duplicate (same role + repo already running → 409)
- Repo must exist on GitHub (verified via API)

## Configuration

Edit `agent-team.config.md`:

```markdown
---
cycle_interval: 30    # Minutes between polls
---

## inject

- Commit messages in Traditional Chinese
- Run `pnpm lint` before every commit
```

The `## inject` section is appended to every role's context.

## Label Convention

All task management uses GitHub Issue labels:

| Label | Meaning |
|-------|---------|
| `agent:fe`, `agent:be`, etc. | Which role should work on this |
| `agent:arch` | Routed to ARCH for triage/merge |
| `status:ready` | Available for claiming |
| `status:in-progress` | Claimed by an agent |
| `status:blocked` | Waiting on dependencies (`<!-- deps: 1,2 -->` in body) |
| `status:done` | Completed (issue closed) |

## Task Pipeline

1. Create a GitHub issue with labels `agent:arch` + `status:ready`
2. ARCH decomposes into sub-tasks with `agent:{role}` labels
3. Agents poll → claim → execute → deliver PR → route back to ARCH
4. `pre-triage.sh` (deterministic): QA PASS → auto-merge, PR delivered → auto-route to QA
5. ARCH handles remaining cases: QA FAIL routing, Design review, audit decomposition
6. Repeat until all issues closed

## Scripts

| Script | Purpose |
|--------|---------|
| `scripts/poll.sh` | Poll for tasks (embeds pre-triage for ARCH) |
| `scripts/claims.sh` | Claim an issue (label swap + race detection) |
| `scripts/release-claim.sh` | Release a claim |
| `scripts/route.sh` | Route issue to a role (validates, prevents loops) |
| `scripts/verify-labels.sh` | Verify exactly 1 agent + 1 status label |
| `scripts/pre-triage.sh` | Auto-handle deterministic triage cases |

## Supervisor Features

- **Three-panel UI**: Sidebar (repos + agents) | Terminal | Properties
- **Health check**: Per-agent countdown to auto-restart, visible in properties panel
- **Stale detection**: Auto-restart agents with no PTY output (exponential backoff)
- **API error detection**: Detects "API Error" / "Internal server error" → fast restart (10min)
- **Trust prompt auto-confirm**: Sends Enter at startup to bypass workspace trust dialog
- **Cost tracking**: Per-agent cost display with budget bar

## Structure

```
commands/
  └── create-agent-employ.md    # Factory command (entry point)
scripts/
  ├── poll.sh                   # Polling (embeds pre-triage)
  ├── claims.sh                 # Claim with race detection
  ├── release-claim.sh          # Release claim
  ├── route.sh                  # Validated routing
  ├── verify-labels.sh          # Label integrity check
  └── pre-triage.sh             # Deterministic auto-merge/route
skills/
  └── {role}/                   # 7 skill packs
      ├── SKILL.md              # Identity + patterns
      ├── workflow/              # Phase-gated process
      ├── rules/                # Enforceable standards
      ├── validate/             # Verification scripts
      ├── actions/              # Executable scripts (deliver.sh, etc.)
      ├── cases/                # Reference implementations
      └── log/                  # Runtime journal
supervisor/
  ├── src/main/                 # Electron main process
  ├── renderer/                 # Dashboard UI
  └── release/                  # Built .dmg
agent-team.config.md            # Default configuration
sync.sh                         # Install to ~/.claude/
```

## Requirements

- [Claude Code](https://claude.ai/code) CLI
- `gh` CLI authenticated (for issue/PR operations)
- Node.js 18+ (for supervisor)
