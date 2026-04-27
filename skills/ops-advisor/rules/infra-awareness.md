# Rule — Infra Awareness

Ops decisions have unusual properties that don't appear in fe / be code:

- **Blast radius**: a single change can affect many running services
- **Capacity**: resources are shared and finite
- **Change windows**: not all times are equally safe to deploy
- **Stateful asymmetry**: some changes are easy to apply, hard to undo

ops-advisor must surface these dimensions explicitly when the request implies them.

## Blast radius

The set of components / users affected if the change goes wrong.

### Levels

- **Single-pod**: change affects one pod (e.g., raising memory limit on a worker). Failure: that pod restarts. Mostly contained.
- **Single-service**: change affects all replicas of one service. Failure: that service degrades. Other services that depend on it may degrade transitively.
- **Cross-service-shared-dep**: change affects shared infrastructure (queue, cache, DB, ingress). Failure: anything using that dep can be affected.
- **Cluster-wide**: change affects the whole cluster (network policy, RBAC, CRD, mesh config). Failure: whole-cluster impact.
- **Multi-cluster / multi-region**: change spans environments. Failure: wide blast radius across regions.

When the request implies a change, name the blast radius:

```markdown
### Risks

- Blast radius: this change modifies the shared rabbitmq cluster. 
  Affected services if the queue becomes unavailable: payments, 
  notifications, audit-log, outbound-webhooks (4 services). Recommend 
  staging this in a dedicated vhost first to isolate from existing queues.
```

### Mitigations to suggest

- **Feature flags**: the new path is dark-launched; old path stays
- **Vhosts / namespaces**: separate the new resources from existing
- **Canary / blue-green**: roll out gradually with traffic split
- **Per-service rollout**: when affecting many consumers, roll out one consumer at a time

Surface the available mitigation, not just the risk.

## Capacity

Resources are finite. ops-advisor checks:

### Compute

- CPU / memory request + limit per workload
- Cluster-level utilisation
- Headroom for autoscaling
- Whether HPA / cluster autoscaler are configured

```markdown
### Existing constraints

- Cluster prod-tw-1: 4-node node pool ("default"), each n2-standard-8.
  Current commitment: ~75% CPU, ~60% memory.
- HPA configured for 8 of 12 services; api-gateway and webhook-handler
  intentionally fixed-replica.
- Cluster autoscaler set 2-8 nodes. Last scaled to 6 during 2025-12-31
  traffic spike (reverted to 4 within 4 hours).
```

### Storage / I/O

- DB connection pool size; current usage
- Object store quotas
- Network bandwidth (if hitting external APIs heavily)

### Quota / rate limits

- Cloud provider quotas (GCP / AWS rate limits)
- Third-party API rate limits (e.g., ECPay's API rate limit)
- Internal rate limits (e.g., webhook ingestion rate)

When the request implies capacity:

```markdown
### Risks

- Capacity: feature implies ~50 RPS additional load on the payments 
  service. Current p99 latency at 30 RPS is 200ms. Adding 50 RPS may 
  push p99 to 400ms+ (reasonable extrapolation but unverified). 
  Recommend load test before launch.
- Quota: feature relies on ECPay refund API which has a 10 RPS rate 
  limit per merchant ID. Current usage ~2 RPS; new usage estimate 
  +1 RPS; well within bounds, but worth noting.
```

## Change windows

Not all deploy times are equal:

- **Anytime** (low-risk): adding a stateless replica, logging changes
- **Off-hours** (medium-risk): rolling deploys to user-facing services
- **Maintenance window** (high-risk): DB migrations, ingress changes, secrets rotation
- **No-deploy** (forbidden): peak traffic hours, business-critical events (e.g., Double 11)

Identify the right window based on:
- The service's traffic pattern
- The change's reversibility
- The team's on-call coverage

Surface in the advice when relevant:

```markdown
### Suggested approach

- Standard rolling deploy is safe any time for the new worker.
- However, the rabbitmq queue resource creation should be done during 
  a defined maintenance window; queue topology changes have caused 
  brief connection drops in past incidents (PR #312 retro). Recommend 
  scheduling for off-hours.
```

## Stateful asymmetry

Some changes are easy to apply but hard to undo:

| Change type | Apply | Rollback |
|-------------|-------|----------|
| Stateless deploy | seconds | seconds |
| HPA config | seconds | seconds |
| Resource limit increase | seconds | seconds (service may restart) |
| New ingress rule | seconds | seconds |
| DB schema migration (additive) | seconds-minutes | minutes |
| DB schema migration (drop column) | seconds | requires backfill |
| Queue creation | seconds | requires drain + delete |
| Secret rotation | seconds | rotation-aware code only |
| Cluster API server change | varies | hard-to-impossible |

When suggesting a change, note the rollback profile:

```markdown
### Risks

- Rollback complexity: this PR adds a new RabbitMQ queue. To roll back:
  1. Stop new producers (deploy old code)
  2. Drain existing messages (manual; can take time depending on queue depth)
  3. Delete queue resource
  Recommend a defined rollback runbook before launch, with a 
  pre-tested drain script.
```

## SLO awareness

Existing user-facing services have SLOs. ops-advisor checks if the change affects SLO compliance:

```bash
# SLOs documented somewhere
ls infra/slo/ monitoring/slo/ 2>/dev/null
```

When relevant:

```markdown
### Risks

- SLO impact: payments service has a 99.5% availability SLO 
  (infra/slo/payments.yaml). New worker shares the same DB connection 
  pool; under failure, connection contention could degrade payments 
  availability. Recommend separate connection pool or DB per service.
```

## Common ops-specific patterns

### "Add monitoring for X"

Trivial-looking. Real scope:
- The metric / dashboard / alert (3 manifests)
- Updating the runbook (1 doc)
- Verifying the alert fires correctly (test runbook)
- On-call training if it's a new alert pattern

S typically; M if the dashboard is novel or alert needs careful tuning.

### "Add a CronJob"

Looks like 1 manifest. Real scope:
- The CronJob manifest
- The Job's container image (built somewhere)
- Logs / monitoring for the job
- Failure alerting
- Backfill strategy if the job missed runs during outage

S if extending a pattern; M if introducing first cron in a service.

### "Rotate secrets"

One value change → potentially affects every consumer of that secret. Plan needed:
- Pre-rotation: deploy code that accepts both old and new values
- Rotation: update secret
- Post-rotation: deploy code that only accepts new
- Verification: rolled-out completely before final deploy

M to L depending on consumer count.

### "Migrate from X to Y" (DB, queue, mesh)

Almost always L+. Defaults:
- Run both in parallel during transition
- Migrate consumers one at a time
- Verify each migration before next
- Decommission old after stable period

Surface as L+ unless surgical; recommend decomposition.

## What to surface in advice

For requests touching infrastructure:

### In "Existing constraints"

- The infra resource shape (manifest, helm chart, terraform)
- Current capacity and headroom
- Recent incidents involving the area

### In "Suggested approach"

- Whether the proposed change is contained or wide blast-radius
- Mitigation patterns (feature flags, namespacing, canary)
- Change-window recommendation
- Rollback strategy

### In "Conflicts with request"

- If the proposed change exceeds capacity
- If blast radius is unacceptable for what's being proposed
- If change-window constraints conflict with the request's urgency

### In "Risks"

- Blast radius
- Capacity / quota implications
- Rollback complexity
- SLO impact

## Anti-patterns

- **Treating ops changes like fe code changes** — fe rollback is git-revert; ops rollback can require state migration
- **Ignoring shared dependencies** — "we have rabbitmq" doesn't mean adding a queue is free
- **Missing change windows** — timing matters as much as content
- **Forgetting on-call** — new alerts add load to humans
- **"Just deploy it"** — many ops changes need pre/post verification

## Quick checklist

For any ops-touching request:

- [ ] Identified the blast radius level
- [ ] Checked capacity (CPU / memory / quota / rate limits)
- [ ] Considered change-window implications
- [ ] Assessed rollback complexity (apply vs undo asymmetry)
- [ ] Checked SLO impact for affected services
- [ ] Surfaced mitigations (feature flags, namespacing, canary)
- [ ] Flagged stateful changes that need pre-tested rollback
