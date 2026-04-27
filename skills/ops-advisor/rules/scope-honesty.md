# Rule — Scope Honesty

The S/M/L estimate is the most consequential part of the advice. arch-shape uses it to decide whether to decompose further. An estimate wrong by 3-5x leads to wrong decompositions and rework cycles.

## The S/M/L scale (ops)

For ops, "scope" is manifests + services + deployment phases + coordination cost:

- **S (Small)**: 1-3 manifests, 1 service, 1 deployment phase. No cross-service coordination. Single PR, comfortable.
- **M (Medium)**: 4-10 manifests, 1-2 services, 1-2 deployment phases. Some coordination but containable. Single PR but substantive.
- **L (Large)**: 11+ manifests, 3-5 services, 2-3 phases. Likely coordinated deploy across services. May warrant decomposition.
- **L+ (Beyond Large)**: would touch the cluster topology, introduce new infra patterns (new managed service, new region, new mesh), or require coordinated migration across many services. **Should be decomposed at the arch-shape level**.

Ops has higher coordination cost than fe — a single infra change can affect multiple running services. The thresholds reflect that.

If L+, say so explicitly:

```markdown
### Estimated scope

- L+ — request to "introduce multi-region active-active" would:
  - Provision second region (terraform: ~50 resources)
  - Cross-region service mesh expansion
  - Cross-region database replication
  - DNS routing updates
  - Coordinated chaos testing
  - Updates to ~15 service manifests for region-aware config
  Strongly suggest decomposing into:
  1. Provision second region infra (no traffic) (M)
  2. Cross-region mesh + replication (no failover) (M)
  3. Active-passive DR (failover tested but not active) (M)
  4. Active-active rollout per service (M each, ~3-4 batches)
```

This kind of pushback is the consultation's most valuable possible output.

## How to estimate

The estimate is grep-driven, not vibe-driven.

### Step 1: Identify touched infrastructure

What services / dependencies / pipelines does the request affect?

```bash
# For "add notification worker":
ls k8s/services/  # see what's there
ls k8s/cronjobs/  # see existing batch patterns
grep -r "rabbitmq\|kafka\|sqs" k8s/  # existing queue infra
ls helm/  # existing helm releases
```

### Step 2: Count modifications

For each existing service / manifest in scope, decide: would this need to change?

```bash
# Services using the same queue
grep -r "rabbitmq" k8s/services/ | head
# How many would need config update?
```

### Step 3: Count additions

New manifests, new services, new resources:

```
- 1 new Deployment manifest
- 1 new Service manifest
- 1 new ConfigMap manifest
- 1 RabbitMQ queue resource (custom resource)
- 1 PrometheusRule for alerts
- 1 ServiceMonitor for scrape config
= 6 new manifests
```

### Step 4: Count deployment phases

A "phase" is "things that must roll out together for the system to remain consistent":

- Phase 1: deploy the new worker (no traffic yet, behind feature flag)
- Phase 2: enable feature flag (worker starts processing events)
- Phase 3: deprecate old code path (later cleanup)

A 1-phase deploy is simple; a 3-phase deploy needs runbook + coordination + rollback per phase.

### Step 5: Sum + factor

```
Modified: 0 existing manifests changed
Added: 6 new manifests
Services: 1 new service (notification-worker)
Phases: 1 (deploy + activate via feature flag in same window)
Coordination: minimal (new service, no existing service depends on it yet)
= S/M boundary; lean M because of the queue resource (cross-team)
```

Round up if uncertain.

## What "manifests" means

Count meaningful infra resources:

- Deployment / StatefulSet / DaemonSet — 1 manifest each
- Service / Ingress — 1 manifest each
- ConfigMap / Secret reference (not the secret itself) — 1 manifest each
- HPA / VPA / PodDisruptionBudget — 1 manifest each
- PrometheusRule / ServiceMonitor — 1 manifest each
- Custom resources (RabbitMQ queue, Cert) — 1 each
- Terraform resource — 1 each
- GH Actions workflow — 1 file = 1 deploy phase concern

Don't count:

- Auto-generated resources (e.g., things created by an operator from a CRD)
- Lockfiles, state files

## Ops-specific bias traps

### Underestimating coordination

A "single new service" is rarely just the manifest:
- Add to monitoring (alerts + dashboards)
- Add to runbook coverage
- Verify scrape config picks it up
- Sometimes update ingress / routing
- Update on-call rotation if it's stateful or has a tight SLO
- Document in arch-ddd

A bare "add a Deployment" might be S; "add a Deployment + monitoring + runbook + arch-ddd update" is M.

### Underestimating change windows

A change might be 1 manifest but require:
- Coordination with another team's deploy schedule
- Off-hours deploy because traffic is high during business hours
- Pre-deploy verification (load test, canary in dev)

These add coordination cost without changing manifest count. Surface in Risks even if scope estimate stays S/M.

### Underestimating cross-region / cross-cluster

Anything touching multi-region or multi-cluster is L by default unless extremely surgical.

### Optimism on rollback

"Rollback is just `kubectl rollout undo`" — true for stateless. Stateful or persistent changes (DB migrations, queue resources, secrets rotation) have asymmetric difficulty: easy to apply, hard to undo. Surface in Risks; may push scope up.

## When the request is vague

If the request says "make payments more reliable" and you can't tell what's meant:

```markdown
### Estimated scope

- Cannot estimate without clarification. Range:
  - "Add retry to the existing flow" (1-2 file change in code, no infra): S
  - "Add reconciliation job + dead-letter queue + alerting": M
  - "Multi-region active-active for payments service": L+
  Suggest arch-shape narrow the request before scope is estimated.
```

## Calibration

After several consultations, check estimates against actual implementation PRs. If your M estimates routinely become L PRs, recalibrate. Note in journal:

```
2026-04-26: estimated M for #410, actual was 14 manifests + 3 phase deploy
(L). The cross-cluster coordination overhead was underestimated.
Going forward, anything touching >1 cluster bumps the estimate up.
```

## Anti-patterns

- **"Should be quick to deploy"** — not an estimate
- **"Just a config change"** — config changes that affect running services have rollout/rollback cost
- **Defaulting to M** for everything
- **Ignoring monitoring/runbook/docs effort** — these are real ops work
- **Estimating only "the new service"** — connected services often need updates too
- **Hand-waving over cross-cluster coordination** — multi-cluster is L by default
- **Conflating "additive" with "free"** — additive infra still has rollout, monitoring, doc cost

## Quick checklist

- [ ] Used `kubectl` / `find` / `grep` to find affected infra
- [ ] Counted manifests (modified + added)
- [ ] Counted services touched
- [ ] Counted deployment phases
- [ ] Considered monitoring / runbook / arch-ddd updates
- [ ] Marked L+ if applicable, with a decomposition suggestion
- [ ] Gave a range with named scenarios if the request is vague
