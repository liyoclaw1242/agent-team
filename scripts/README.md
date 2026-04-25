# Orchestrator Scripts

These scripts live outside `skills/` because they are infrastructure, not skill content. They're invoked by skill `actions/*.sh` and by the dispatcher.

## Discovery

Skill scripts auto-detect these in two locations, in this order:

1. `$HOME/.claude/scripts/{name}.sh` (user-level install)
2. `<repo-root>/scripts/{name}.sh` (repo-level fallback)

Set `ROUTE_SH`, `CLAIMS_SH`, etc. environment variables to override.

## Inventory

| Script | Purpose |
|--------|---------|
| `route.sh` | The only legal way to mutate `agent:*` and `status:*` labels |
| `claims.sh` | Atomic claim of an issue by an agent (concurrency safety) |
| `poll.sh` | Find issues an agent should work on next |
| `pre-triage.sh` | Deterministic post-implementation handlers (PR verdicts → label state) |
| `scan-unblock.sh` | Sweep blocked issues, unblock those whose deps are resolved |
| `scan-complete-requests.sh` | Sweep parent issues; close when all children are done |

## Common conventions

All scripts:

- Take `--repo OWNER/NAME` (or read `REPO` env var as fallback)
- Take `--agent-id IDENTIFIER` where applicable (the GitHub login or App slug acting)
- Emit JSON-Lines logs to stderr if `LOG_FORMAT=jsonl` is set; human-readable otherwise
- Exit 0 on success, 1 on argument/env error, 2 on partial failure, 3 on conflict (e.g., already claimed)
- Are idempotent: running twice with the same args is safe

## Required tools

- `gh` CLI, authenticated with sufficient scope
- `jq`
- `flock` (for scripts that lock)
- `bash` >= 4

## Versioning

Signature changes (renamed flags, removed args) are breaking changes that require a major version bump and coordinated migration of all callers. Add new flags freely; remove or rename via deprecation cycle.

## Deviation from old `arch/scripts/`

This rewrite breaks compatibility with the previous orchestrator scripts. Notable changes:

- All flags use `--long-form` instead of positional args, except `route.sh` which keeps two positional args for ergonomics
- `--reason` is required on every label-mutating call for audit trail
- `route.sh` validates the source→target transition against LABEL_RULES.md and refuses illegal moves
- `claims.sh` now writes a structured comment on claim, not just a label
- `pre-triage.sh` is split: pure handlers in `handlers/`, dispatch logic in main
