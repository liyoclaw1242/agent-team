# Case — Alert Investigation

The starting point for `workflow/investigation.md`. An alert fired or a human reported an infra issue. This case shows the typical investigation pattern with concrete examples.

## Worked example: error rate spike

Alert fires:

```
Alert: CancelSvcErrorRateHigh
Severity: warning
Started: 2026-04-25 14:18 UTC
Service: cancel-svc
Condition: error rate > 5% for 5min
Current value: 12.3%
Runbook: https://github.com/owner/repo/blob/main/runbooks/cancel-svc/high-error-rate.md
```

You're triaged to this issue. Mode: investigate.

## Phase 1: read

```bash
# The alert body
gh issue view $ISSUE_N

# Recent OPS changes to cancel-svc
grep -A 1 '"event":"applied"' skills/ops/log/$(date -u +%Y-%m-%d).jsonl \
  | grep cancel-svc | tail -10

# The runbook
cat runbooks/cancel-svc/high-error-rate.md
```

What you find:
- Alert payload says error rate is 12.3%
- Last apply: 25 minutes ago, deployed `cancel-svc:abc1234`
- Runbook says "Check recent deploys; if recent, roll back"

Time elapsed since alert fire: 8 minutes. Customer impact: cancellation feature broken for 12% of users.

## Phase 2: triage — Lane 1 (mitigate)

Per `workflow/investigation.md` Lane 1, customer impact + recent deploy → mitigate first.

```bash
kubectl rollout undo deployment/cancel-svc -n production
kubectl rollout status deployment/cancel-svc -n production --timeout=2m
```

Wait for rollout. Watch metrics:

```bash
# Either the dashboard, or:
kubectl logs -f deployment/cancel-svc -n production --tail=20 | grep -i error
```

Within 90 seconds, error rate returns to baseline (~0.1%).

Post the mitigation as a comment:

```markdown
## Mitigation applied

- Rolled back cancel-svc deployment from `abc1234` to previous (`xyz9876`)
- Error rate returned to baseline (0.1%) within 90 seconds of rollback
- Customer impact: ~5 minutes of elevated error rate before mitigation
- Now investigating root cause; this issue stays open until cause is identified
```

## Phase 3: investigate root cause

The bug fired immediately after deploy → almost certainly something in `abc1234`.

```bash
# What did abc1234 change?
git log --oneline xyz9876..abc1234 -- services/cancel-svc/

# Diff
git diff xyz9876..abc1234 -- services/cancel-svc/
```

You see:
- Commit `def4567`: "feat: add cancellation reason persistence"
- The diff adds a new column lookup that wasn't in the schema yet

Hypothesis: code was deployed but a corresponding schema migration wasn't run. The new column lookup fails for every cancellation request.

### Test the hypothesis

```bash
# Check the schema state of the prod DB
psql -h prod-db -U readonly billing -c "\d subscriptions"
```

Confirmed: no `cancellation_reason` column exists in production. The migration was created but not applied.

### Why did this happen?

Two possibilities:
1. The migration was supposed to ship in a sibling task that didn't merge first
2. The migration was bundled into the cancel-svc PR but the deploy pipeline doesn't run migrations

Check the PR for `abc1234`:

```bash
gh pr view --search "abc1234"
# Found: PR #501 says "this depends on migration in #500"
```

Issue #500 (the migration) hasn't merged yet. The cancel-svc PR shipped without its migration dependency.

## Phase 4: root cause + categorisation

**Root cause**: cancel-svc PR #501 was merged + deployed before its required migration #500. The deploy pipeline doesn't enforce migration-before-code ordering.

**Category** (per `workflow/investigation.md` Phase 4):

- The immediate fix is "ship the migration" — that's an OPS task, but trivial
- The structural fix is "deploy pipeline should enforce migration ordering" — that's an OPS task too, but bigger
- The contributing factor is "PR #501 lacked a deps marker on #500" — process, not technical

This is **Category A (OPS-side fix)** with a structural follow-up.

## Phase 5: file fix(es)

```bash
# Fix #1: ship the migration that should have shipped first
gh issue create --repo $REPO \
  --title "[OPS] Fix: apply pending cancellation_reason migration to prod" \
  --body-file /tmp/fix-migration.md \
  --label "source:arch,agent:ops,status:ready"

# Fix #2 (structural): improve deploy pipeline to enforce migration-before-code
gh issue create --repo $REPO \
  --title "[OPS] Improve: deploy pipeline should run migrations before code" \
  --body-file /tmp/structural.md \
  --label "source:arch,agent:ops,status:ready,intake-kind:architecture"
```

Where `fix-migration.md` is:

```markdown
## Goal
Apply migration from #500 to production database; then re-deploy cancel-svc:abc1234.

## Acceptance criteria
- [ ] Migration applied to prod
- [ ] cancel-svc:abc1234 redeployed
- [ ] Error rate returns to baseline post-deploy
- [ ] cancellation_reason field is populated for new cancellations

<!-- bug-of: #ALERT_ISSUE_N -->
<!-- intake-kind: bug -->
```

## Phase 6: link the issues

```bash
bash _shared/actions/issue-meta.sh set $ALERT_ISSUE_N fix "#$FIX_ISSUE_N"
bash _shared/actions/issue-meta.sh set $ALERT_ISSUE_N deps "#$FIX_ISSUE_N"
```

The alert issue stays open with `<!-- deps: -->` on the fix. When the fix lands, scan-unblock automatically transitions this alert issue.

## Phase 7: route the alert issue

```bash
bash route.sh $ALERT_ISSUE_N ops \
  --reason "investigation complete; mitigation in place; fix at #$FIX_ISSUE_N" \
  --status blocked
```

The issue is no longer in your immediate queue but it's not closed — it'll re-emerge when the fix lands so you can verify mitigation can be removed.

## Phase 8: self-test record

```markdown
# Self-test record — issue #ALERT_ISSUE_N (alert investigation)

## Acceptance criteria
- [x] Alert acknowledged within 10 min of fire
  - Verified: triaged at 14:26 UTC; alert fired 14:18 UTC (8 min)
- [x] Mitigation applied (customer-impacting alert)
  - Verified: rollback at 14:27 UTC; error rate baseline at 14:28 UTC
- [x] Root cause identified
  - Verified: cancel-svc PR shipped before required migration #500
- [x] Fix routed correctly
  - Verified: filed #FIX_ISSUE_N for migration apply; #STRUCTURAL_N for pipeline fix
- [x] Both alert + fix issues properly linked
  - Verified: alert issue has fix marker pointing to #FIX_ISSUE_N

## Mitigation
Active: cancel-svc on revision-44 (was attempting revision-45)

## Root cause
Migration in #500 not applied to prod before cancel-svc PR #501 was deployed.
The new column lookup fails on every request → error rate spike.

## Routing
- #FIX_ISSUE_N: apply migration + redeploy
- #STRUCTURAL_N: improve pipeline to prevent recurrence
- This alert issue blocks on #FIX_ISSUE_N

## Ready for review: yes
```

## Worked example: latency degradation

Alert: `CancelSvcLatencyHigh` (p99 > 500ms for 10min). No deploy in last 4h. No customer error rate increase, just latency.

### Phase 1: read

- Alert: latency p99 was 200ms, now 580ms
- No recent deploys
- Recent metrics: latency rose gradually over the last 30 min, not a step change

### Phase 2: triage

Latency without errors → no immediate customer outage; Lane 2 (investigate first, mitigate if needed).

### Phase 3: investigate

Gradual rise rules out "deploy broke it". Look at:

- Database metrics: query duration up?
  - Yes: average query duration on `subscriptions` rose from 10ms to 200ms
- Database CPU: rising? IO?
  - CPU at 85% (was 30%); IO normal
- Slow query log: what's slow?
  - Specific query: `SELECT * FROM subscriptions WHERE user_id = ? AND status = ?`
- Query plan:
  - Sequential scan on subscriptions (was index scan before)
- Why no index?
  - The (user_id, status) index was dropped in #480 last week (apparent cleanup)

Root cause: index drop in #480 wasn't safe; the query was still using it.

### Phase 4: categorise

Category A (OPS-side fix). Recreate the index.

```bash
# Mitigation = fix here:
psql -h prod-db ... <<EOF
CREATE INDEX CONCURRENTLY idx_subscriptions_user_status
  ON subscriptions(user_id, status);
EOF
```

Within 5 minutes of CREATE INDEX completing, query plans flip back to index scan; latency returns to baseline.

File a structural follow-up: "improve index drop process — verify usage before dropping".

## Worked example: CPU pressure cascade

Alert: `cancel-svc OOMKilled` — pods restarting due to memory limits.

### Phase 1: read

- Alert: cancel-svc pods OOM-killed twice in the last 10 min
- Pod memory limit: 512MB
- Recent traffic: surge from a marketing campaign launched 30 min ago
- No recent deploys

### Phase 2: triage

Customer impact: each OOM kills a pod, which abandons in-flight requests; some users see errors. Lane 1 (mitigate).

### Phase 3: mitigate

Two paths:

```bash
# Path A: scale up replicas
kubectl scale deployment/cancel-svc -n production --replicas=10
# Was at 3; spread the load

# Path B: bump memory limit
kubectl set resources deployment/cancel-svc -n production \
  --limits=memory=1Gi
```

Choose A first (no restart needed; pods spread load immediately). Watch:

```bash
watch kubectl top pods -l app=cancel-svc -n production
```

Memory per pod drops to ~250MB after replicas added. OOMs stop.

### Phase 4: root cause

Was the original 512MB limit too tight, or did the marketing campaign push beyond reasonable load?

```bash
# Look at memory headroom over the last week
# (via your metrics dashboard)
```

You see: memory was usually ~300MB but with frequent spikes to 480MB. Headroom was thin even before the campaign; the campaign just pushed it over.

Category A. File two follow-ups:

- Bump memory limit to 1GB permanently (not just while replicas are 10)
- Add memory-pressure metric to dashboards so future trends are visible before alerting

## Anti-patterns

- **Investigating before mitigating Sev 1** — bleeding first, archaeology second
- **Rolling back without confirming the rollback is the fix** — sometimes the deploy is innocent and the alert is a separate issue
- **"Restart and see if it goes away"** — restart can mask root cause; capture diagnostic info first
- **Mitigating without filing a fix** — mitigation is temporary; without a fix issue, the temporary state lasts forever
- **Filing fix without root cause confirmed** — Iron Law equivalent
- **Closing alert issue before mitigation is lifted** — alert closure should signal "fully resolved", not "we worked around it"
