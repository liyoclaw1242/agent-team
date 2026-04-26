# Rule — Self-Test Gate

OPS self-test gate is structurally similar to fe/be but with OPS-specific required sections. The gate exists to catch the failure mode "agent applies a change without thinking through rollback / dry-run / observation".

## What the gate checks

`actions/deliver.sh` runs these checks before opening the PR:

1. File exists: `/tmp/self-test-issue-{N}.md`
2. File contains `## Acceptance criteria` section
3. Every line starting with `- [` in that section is `- [x]`
4. File contains `## Ready for review: yes` line
5. **OPS-specific**: file contains `## Dry-run captured` section
6. **OPS-specific**: file contains `## Rollback` section (or "## Change is irreversible" with acknowledgement)
7. **OPS-specific**: file contains `## Change-window awareness` section

The OPS-specific checks ensure the agent actually thought through the OPS-specific concerns; without them, the gate refuses.

## The required sections

### `## Dry-run captured`

States what dry-run was performed and where the output is:

```markdown
## Dry-run captured
Plan output at /tmp/plan-issue-150.txt; embedded in issue body via plan-change.sh.
- Resources to add: 0
- Resources to change: 1 (Deployment cancel-svc, replicas: 1 -> 3)
- Resources to destroy: 0
```

For changes that genuinely cannot be dry-run (per `rules/dry-run-first.md`):

```markdown
## Dry-run captured
This change cannot be dry-run (DNS record change; no preview available). 
Mitigations applied:
- TTL was reduced 24h ago to 60s, minimising propagation impact
- Smallest possible change (single record); rollback plan rehearsed in staging
```

### `## Rollback`

The rollback steps, copied or referenced from the PR description:

```markdown
## Rollback
- Steps documented in PR description's "Rollback" section
- Estimated time: 1-2 minutes
- Rehearsed in staging: yes (date)
- Special considerations: in-flight requests may fail (clients retry)
```

For irreversible changes:

```markdown
## Change is irreversible
Acknowledged: this DNS change cannot be undone within the 24h TTL window.
Stakeholder approval: @approver (link to comment)
```

### `## Change-window awareness`

Risk classification per `rules/change-windows.md`:

```markdown
## Change-window awareness
Risk class: medium (single-service deploy of new code release)
Plan: apply during business hours, Tue-Thu morning. Avoiding Friday.
```

For high-risk:

```markdown
## Change-window awareness
Risk class: high (DNS change, propagation up to 24h, irreversible during propagation)
Window: scheduled Tue 10:00 UTC, announced in #announcements (link)
Standby: @teammate
Success criteria: ...
```

## Why these checks aren't optional

Each addresses a specific OPS failure mode that has caused real incidents:

- **No dry-run check**: agent applies and discovers the change is broken; partial state
- **No rollback documented**: 3am incident, oncall person can't restore quickly
- **No window awareness**: high-risk change shipped Friday afternoon, weekend disaster

The gate forces the agent to address each. Even if the agent knows what they're doing, writing it down protects future readers (and future agents).

## The gate is mechanical

Like fe/be's gates, this one is mechanical — it checks for section presence, not section quality. An agent could write `## Dry-run captured\nyes` and pass the gate.

The downstream defences for shoddy self-tests:

- **PR review** — humans read the self-test and the PR; shoddy self-tests are visible
- **Apply-time observation** — even if the change ships, the post-apply observation phase catches issues early
- **Change-window discipline** — high-risk changes have a second person watching apply

The gate is a commitment ceremony, not a code review.

## What the gate does NOT check

- **Quality of the rollback plan** — that's review's job
- **Accuracy of risk classification** — sometimes the agent classifies low-risk what's actually high-risk; review catches
- **Whether the dry-run was actually performed** — the file's existence is necessary, not sufficient
- **Whether anyone is on standby for the apply** — process discipline, not gate

## Anti-patterns

(All of fe/be's apply, plus OPS-specific:)

- **Boilerplate self-tests across OPS issues** — copy-pasting "dry-run captured" without actually doing it. Review tends to catch but lying here is dangerous.
- **`## Dry-run captured\nNot applicable`** — almost always indicates the agent didn't think; truly non-dry-runnable changes are rare. If you wrote "N/A", question yourself.
- **Risk class self-classified as "low" for clearly medium changes** — applies the wrong window discipline. When uncertain, pick higher risk class.
