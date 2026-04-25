# Dispatcher Runbook

Operating guide for `dispatcher.sh`. Read after `decision-table.md`.

## How it runs

Single-shot, triggered by cron. Each invocation:

1. Acquires shared orchestrator lock (mutually exclusive with `pre-triage.sh`, `scan-unblock.sh`, `scan-complete-requests.sh`)
2. Lists open issues matching `agent:arch + status:ready`
3. For each issue, classifies and re-tags via `route.sh`
4. Logs to `$LOG_FILE`
5. Exits

## Cron setup

```cron
# Run all four orchestrator scripts every minute. Lock file ensures they
# don't trip over each other.
* * * * *  REPO=owner/repo /opt/agent-team/skills/arch/dispatcher/dispatcher.sh   >> /var/log/orchestrator.log 2>&1
* * * * *  REPO=owner/repo /opt/agent-team/scripts/pre-triage.sh                  >> /var/log/orchestrator.log 2>&1
* * * * *  REPO=owner/repo /opt/agent-team/scripts/scan-unblock.sh                >> /var/log/orchestrator.log 2>&1
* * * * *  REPO=owner/repo /opt/agent-team/scripts/scan-complete-requests.sh      >> /var/log/orchestrator.log 2>&1
```

The scripts share `$LOCK_FILE`; whichever starts first wins, others exit 0 silently.

## Required environment

| Var | Required | Default | Notes |
|-----|----------|---------|-------|
| `REPO` | yes | — | `owner/repo` |
| `ROUTE_SH` | no | auto | path to `scripts/route.sh` |
| `ISSUE_META_SH` | no | auto | path to `_shared/actions/issue-meta.sh` |
| `LOCK_FILE` | no | `/tmp/arch-orchestrator-{repo}.lock` | shared with other orchestrator scripts |
| `LOG_FILE` | no | `/tmp/dispatcher-{repo}.log` | append-only |
| `DRY_RUN` | no | `0` | set `1` to log without applying |
| `MAX_ISSUES_PER_RUN` | no | `50` | safety cap |

## First-time validation

```bash
# 1. Unit tests for classifier
bash skills/arch/dispatcher/test-fixtures/test-classify.sh

# 2. Dry-run against real repo
DRY_RUN=1 REPO=owner/repo bash skills/arch/dispatcher/dispatcher.sh

# 3. Inspect log
tail -50 /tmp/dispatcher-owner-repo.log
```

If dry-run output looks correct, drop `DRY_RUN=1` for one invocation, verify on a single test issue, then add to cron.

## Common diagnostics

**An issue isn't being routed.** Check:
- Does it have `agent:arch + status:ready`? Dispatcher only sees those.
- Does it have `status:blocked`? `scan-unblock.sh` handles that, not dispatcher.
- Is the orchestrator lock held? `lsof $LOCK_FILE`

**Too many issues route to arch-judgment.** Means escape hatch is firing too often. Likely causes:
- Intake templates aren't emitting `<!-- intake-kind: ... -->`. Run `intake-validator` workflow.
- A new pattern needs explicit handling. Add a rule to `decision-table.md` and `classify()`.

**Two dispatchers running.** Lock failure mode is silent (exit 0). If lockfile exists but no process holds it, a previous run died ungracefully. `rm $LOCK_FILE` and rerun.

## Adding a new rule

1. Edit `decision-table.md` — add the rule with rationale.
2. Edit `dispatcher.sh` `classify()` to match.
3. Add a positive and a negative test case in `test-fixtures/test-classify.sh`.
4. Run tests. PR all three together.

## What dispatcher does NOT do

- Read or modify body content (only reads, via `issue-meta.sh`).
- Process PRs, verdicts, or post-implementation state (that's `pre-triage.sh`).
- Modify any label other than `agent:*` (and `status:*` indirectly via `route.sh`).
- Make any LLM call.

If you find yourself wanting to add LLM logic to dispatcher, you've found a new specialist. Create a new skill instead.

## Future: cross-host workers

Single-host operation is the current design. To run multiple dispatcher workers across hosts, add per-issue claim labels — see `scripts/README.md` for the pattern. Don't do this until you've outgrown single-host throughput.
