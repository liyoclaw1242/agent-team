# Workflow — Investigation (alert response)

When an alert fires or a human reports an infra-side incident. Mostly mirrors `debug/workflow/investigate.md` but with OPS-specific routing decisions.

## Phase 1 — Read

Required:

1. The issue body (alert payload or human report)
2. The `<!-- alert-id: -->` marker — fetch the alert from the observability platform
3. Recent journal entries for the affected service (any deploys / config changes in the last few hours?)
4. Any active or recently-resolved incidents on the same service

```bash
# Get recent applies of the affected service
grep -A 1 '"event": "applied"' skills/ops/log/$(date -u +%Y-%m-%d).jsonl | tail -10
```

## Phase 2 — Triage immediately

Within the first 5 minutes, decide which lane:

### Lane 1: Mitigate first (Sev 1, ongoing customer impact)

If customers are visibly affected (errors, outages, data not flowing), **mitigate before investigating**:

- Roll back the most recent deploy of the affected service (if recent)
- Disable the offending feature flag
- Reduce traffic via load balancer / CDN
- Scale up if it's a load issue
- Failover to a standby / different region

Mitigation is not the same as the fix. It just stops the bleeding. Document what you did:

```markdown
## Mitigation applied

Rolled back deployment `cancel-svc` to previous ReplicaSet (sha=abc1234).
Error rate returned to baseline within 90 seconds.

This is mitigation only. Root cause investigation continues.
```

Then continue to investigation phases.

### Lane 2: Investigate without mitigation (Sev 2-3 or no customer impact yet)

Skip directly to Phase 3.

### Lane 3: Not actually OPS

Sometimes alerts route here mistakenly. If you read the alert and conclude it's a code-level bug that should be debug's, route immediately:

```bash
bash route.sh $ISSUE_N debug \
  --reason "alert is code-level (stack trace shows app code path); rerouting to debug"
```

Don't try to fix code-level bugs from OPS. That's debug → fe/be flow.

## Phase 3 — Investigate

Same shape as `debug/workflow/investigate.md`:

1. Reproduce or triangulate from traces
2. Form hypothesis
3. Test hypothesis
4. Confirm root cause

OPS-specific things to check first:

- **Recent deploys** — did this start within minutes of a deploy? Likely related.
- **Recent IaC changes** — terraform / config changes can cascade unexpectedly
- **Resource pressure** — CPU / memory / disk / IOPS on the affected service
- **Dependency health** — is a downstream service / database / external API degraded?
- **Network** — DNS resolution, TLS expiry, connectivity between services
- **Quota / rate limits** — cloud provider quotas, third-party API limits

## Phase 4 — Categorise the root cause

Once you've found it, decide where the fix lives:

### Category A: OPS-side fix

The cause is config / IaC / infra. Fix is yours:

- Resource limits too low → scale up / add replicas
- DNS misconfiguration → correct DNS records
- Secret expired → rotate
- Quota hit → request quota increase + add monitoring

File a normal OPS task (could be the same issue, retasked) per `workflow/implement.md`. The mitigation comment stays as record.

### Category B: Code-level fix

The cause is in fe/be code:

- Memory leak → fe/be needs to fix
- Missing error handling → fe/be
- Slow query → be (or whoever owns the query)

File a debug-shape fix issue:

```bash
# Conceptually similar to debug's file-fix.sh — file a bug task
gh issue create --repo $REPO \
  --title "[BE] Fix: memory leak in cancel-svc handler causing pod OOM" \
  --body-file /tmp/fix-issue.md \
  --label "source:arch,agent:be,status:ready"
```

The OPS issue's mitigation stays in place until the BE fix lands.

### Category C: Architectural

The cause is a structural problem that needs re-decomposition:

- Service A and B share a database that's now bottlenecking
- Coupling between services means a downstream slow-down cascades

Route to `agent:arch` for arch-shape to consider. Mitigation stays.

## Phase 5 — Self-test (investigation mode)

```markdown
# Self-test record — issue #200 (alert investigation)

## Acceptance criteria for this OPS task
- [x] Alert acknowledged and triaged within {SLO} of fire
  - Verified: triaged at 14:25 UTC; alert fired 14:18 UTC (7 min)
- [x] Mitigation applied if customer-impacting
  - Verified: rolled back cancel-svc deployment; error rate baseline at 14:28 UTC
- [x] Root cause identified
  - Verified: memory leak in CancelHandler.Process traced to leaking SQL prepared statements
- [x] Fix routed to correct role
  - Verified: filed #201 [BE] for the leak fix; this issue stays open until #201 lands

## Mitigation
Active: cancel-svc rolled back to revision-44 (was at revision-45)

## Root cause
SQL prepared statements in CancelHandler.Process are not closed after use,
leaking ~50KB per request. Pod OOMs at ~10K requests under load. Confirmed
via heap dump from one of the OOM'd pods.

## Routing
Filed #201 to BE for the leak fix. This issue stays at status:blocked with
deps:#201 until fix lands; then mitigation rolls forward and this closes.

## Ready for review: yes
```

## Phase 6 — Deliver

For investigation mode, "deliver" usually means:

```bash
# If a fix issue was filed:
bash _shared/actions/issue-meta.sh set $ISSUE_N fix "#$FIX_N"
bash _shared/actions/issue-meta.sh set $ISSUE_N deps "#$FIX_N"
bash route.sh $ISSUE_N ops \
  --reason "investigation complete; fix at #$FIX_N; mitigation in place" \
  --status blocked
```

The issue stays open with deps on the fix. When the fix merges, the issue auto-unblocks; OPS reviews whether mitigation needs lifting.

## Anti-patterns

- **Investigating before mitigating Sev 1** — Iron Law equivalent for ops. Stop the bleeding first.
- **Mitigating without documenting** — future you doesn't know the system was modified
- **"Restart and see" as investigation** — restart can mask the cause; if you must restart, capture diagnostic info first (heap dump, goroutine dump, profile)
- **Rolling back without confirming the rollback is the fix** — sometimes the deploy is fine and the alert is a separate cause. Don't blindly attribute.
- **Filing fix issue without root cause** — same as debug's Iron Law. No "probably" fixes.

## When to escalate

If after timebox (default: 1 hour for Sev 1, 4 hours for Sev 2) you don't have root cause, escalate to human-review with everything you've found so far. Don't keep investigating alone.

```bash
bash route.sh $ISSUE_N human-review \
  --reason "investigation timebox exceeded; mitigation in place; see comments for current hypothesis"
```
