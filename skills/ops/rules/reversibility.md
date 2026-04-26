# Rule — Reversibility

Every change has a documented rollback path before merge. If a change is genuinely irreversible, that's recorded explicitly in the PR with an acknowledgement that human approval is required.

## Why this rule

Production things break. The question isn't whether they'll break, it's how fast you can return to a known-good state when they do.

A documented rollback:
- Forces you to think through the failure mode before causing it
- Lets the next OPS person (often you, at 3am) execute without rediscovering
- Establishes time-to-recover budget that informs the change's risk classification

## What goes in the rollback section

The PR description includes a `## Rollback` section with at minimum:

```markdown
## Rollback

If this change misbehaves after apply:

1. {Step 1 — specific command or action}
2. {Step 2}
3. ...

**Verification after rollback**: {how to confirm the rollback worked}

**Estimated rollback time**: {minutes}

**Special considerations**: {data state, downstream effects, etc — or "none"}
```

For most changes, this is straightforward:

```markdown
## Rollback

If `cancel-svc` deployment misbehaves:

1. `kubectl rollout undo deployment/cancel-svc -n production`
2. Wait for rollout to complete (~30s)

**Verification**: `kubectl get pods -l app=cancel-svc -n production` shows previous ReplicaSet pods running; error rate metric (cancel.errors.rate) returns to baseline within 2 minutes.

**Estimated rollback time**: 1-2 minutes

**Special considerations**: in-flight requests may fail during rollout (these are retried by clients).
```

## Categorising change reversibility

Not all changes are equal. The PR's reversibility falls into one of:

### Category A: Trivially reversible

`git revert` undoes the change cleanly and re-applying restores the previous state. Most code-only / IaC-only changes are here.

Rollback section: standard 3-5 steps.

### Category B: Reversible with state restoration

Rollback requires also restoring data state — backup restore, message replay, cache rebuild.

Rollback section includes the data-restoration steps. Estimated time is honest — backup restores can be hours.

### Category C: Multi-step destructive (expand-contract)

Destructive changes (drop column, delete resource, change schema) are decomposed per `be/rules/migration-discipline.md`'s expand-contract pattern. Each step is its own PR; only the final step is irreversible.

The OPS PR for each step has a rollback for THAT step's change, not for the whole migration.

### Category D: Inherently irreversible

Some operations cannot be undone:

- DNS changes propagated globally (24-48 hour TTL means rollback delay)
- Public API surface releases (clients integrate; can't take it back)
- Released compliance / regulatory data (retention requirements)
- Hard-deleted historical data without backup

For these, the PR description includes an explicit acknowledgement:

```markdown
## Rollback

**This change is irreversible.**

Reasons:
- DNS TTL is 24h; reverting the record would not be visible to clients for 24h
- Some clients have cached the old value; even after revert, mixed state for ~24h

Risk acknowledgement:
- I have confirmed with @{stakeholder} that proceeding is acceptable
- Mitigations:
  - DNS TTL was reduced to 60s 24h ago to minimise propagation delay
  - Communication to affected clients sent {date}
  - Monitor: any error rate increase will be noticed within 5min of apply
- Apply window: scheduled for {time} per change-windows.md
```

This pattern requires explicit human review before merge. It's the right amount of friction.

## Reversibility checklist

For every PR, before opening:

- [ ] Identified the rollback steps
- [ ] If steps include "restore from backup", I've verified backup exists and is readable
- [ ] Estimated rollback time matches the change's risk profile
- [ ] If the change is in Category D, the irreversibility is explicit + acknowledged
- [ ] If a sibling change (BE migration, FE feature flag) makes rollback complicated, that's noted

## Rehearsing the rollback

For high-risk changes, rehearse rollback in staging before applying to prod:

```bash
# In staging:
git checkout <new-change-sha>
terraform apply  # apply the new change
# wait for apply
# observe behaviour matches expectation
git checkout main  # back to old
terraform apply  # rollback
# verify state matches pre-change
```

This validates the rollback procedure actually works, not just that you wrote down something.

## When rollback differs from spec's rollback

Sometimes the spec has its own rollback expectations ("if user complaints exceed X, revert"). Those are product-level rollback triggers — separate from the technical rollback steps. Both can co-exist:

```markdown
## Rollback

**Technical rollback**: see steps below.

**Trigger conditions**: per the parent issue, technical rollback is initiated if:
- Error rate exceeds 1% for >5 minutes
- p99 latency exceeds 500ms for >10 minutes
- User-reported issues exceed 5 in 1 hour

**Steps** (when triggered):
1. ...
```

## Anti-patterns

- **"Should be safe" as rollback section** — not a rollback. Write the steps.
- **Rollback by re-running the entire deploy** — sometimes works, sometimes leaves intermediate state. Specific steps preferred.
- **"It auto-rolls back" without verification** — kubernetes auto-rollback exists for some failure modes (failed liveness, image pull failure) but not all. Don't assume it covers your case.
- **Documenting rollback as "revert PR + manual recovery"** — manual recovery means a human at 3am figuring it out under pressure. Make it specific.
- **Skipping rehearsal for risky changes** — if you didn't rehearse it, you don't know it works. For high-risk changes, rehearse.
