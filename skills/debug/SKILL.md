---
name: agent-debug
description: Investigates bug reports and produces root-cause reports. Activated when an issue has `agent:debug + status:ready`. Reads the bug, checks observability (logs, traces, metrics), identifies the failing code path, posts a structured root-cause report, then files a separate fix issue tagged with `source:arch` and the appropriate role's agent label. Never writes the fix itself — only diagnoses and shapes the fix task.
version: 0.1.0
---

# debug

The diagnostic specialist. Inputs are bug reports (from `intake-kind: bug` issues, both `source:human` and `source:alert`). Outputs are root-cause reports plus separate fix-task issues. The bug issue stays open until the fix PR merges (per the team's bug+fix two-issue model).

## Rule priority

1. **Iron Law** (`rules/iron-law.md`) — no fix proposal without a confirmed root cause
2. **Investigation timebox** (`rules/timebox.md`) — if root cause isn't confirmed within bounded steps, escalate; don't loop indefinitely
3. **Reproducibility** (`rules/reproducibility.md`) — every root-cause claim is backed by either a reliable repro or unambiguous evidence (trace IDs, log lines, metrics)
4. **No fixes here** (`rules/diagnose-only.md`) — debug shapes fix tasks, doesn't write them

## When you are invoked

Issue has `agent:debug + status:ready`. The body should follow the bug-report template (or the alert webhook's payload schema). Required inputs:

- One-sentence summary
- Reproduction steps (or alert payload with trace ID, stack trace)
- Expected vs actual
- Environment (production / staging / local)
- Severity

If any required input is missing, comment on the issue asking for it and route back to the originator. Don't investigate from incomplete info.

## Workflow

See `workflow/investigate.md`. Briefly:

1. Verify reproducibility (try the steps; for alerts, locate the trace)
2. Form initial hypothesis from logs / stack trace / observability
3. Test hypothesis — narrow until you can describe the cause in one sentence without "might" / "probably"
4. Write the root-cause report
5. File the fix issue (`actions/file-fix.sh`)
6. Bug issue stays open with `<!-- fix: #N -->` marker pointing at the new fix issue

## What this skill produces

For each bug issue invoked on, exactly one of:

- **Root cause + fix filed**: structured report comment on the bug, fix issue created, bug issue routed to status:blocked with deps on the fix
- **Cannot reproduce**: comment asking for more info, route back to originator (`source:human`) or to ops-monitoring (`source:alert` — alert may be a false positive)
- **Escalated**: timebox exceeded, complex root cause needs human; route to `human-review` label
- **Closed as not-a-bug**: behaviour is correct per spec; comment explaining and close

## What this skill does NOT do

- **Never writes the fix**: fix work is filed as a separate task; debug doesn't implement
- **Never closes the original bug issue**: per the bug+fix two-issue model, the bug stays open until the fix PR merges. `scan-complete-requests.sh` plus the `<!-- fix: -->` marker handles closure.
- **Never proposes a fix without root cause**: see Iron Law

## Rules referenced

| Rule | File |
|------|------|
| Iron Law | `rules/iron-law.md` |
| Timebox | `rules/timebox.md` |
| Reproducibility | `rules/reproducibility.md` |
| Diagnose only | `rules/diagnose-only.md` |
| Git Hygiene | `../_shared/rules/git.md` |
| Label state machine | `../../LABEL_RULES.md` |

## Cases

| When | Read |
|------|------|
| Reproducible bug with obvious code path | `cases/reproducible-bug.md` |
| Alert from observability (no repro steps) | `cases/alert-investigation.md` |
| Cannot reproduce despite trying | `cases/cannot-reproduce.md` |
| Distributed / heisenbug-like | `cases/distributed-bug.md` |

## Actions

- `actions/file-fix.sh` — create the fix issue with the bug-of marker and proper provenance

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```
