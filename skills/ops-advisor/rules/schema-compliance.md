# Rule — Schema Compliance

The advice comment is mechanically validated. Format violations cause `actions/respond.sh` to refuse posting.

## The exact schema

```markdown
## Advice from ops-advisor

### Existing constraints
- {bullet}
- {bullet}

### Suggested approach
- {bullet}
- {bullet}

### Conflicts with request
- {bullet}
(or single line: "none")

### Estimated scope
- {S | M | L | L+} — {N manifests / M services / Y deployment phases}

### Risks
- {bullet}

### Drift noticed
- {bullet}
(or single line: "none")
```

## What the validator checks

`validate/advice-format.sh --role ops-advisor`:

1. First non-empty line is exactly `## Advice from ops-advisor`
2. All six required `### ` sections present:
   - `### Existing constraints`
   - `### Suggested approach`
   - `### Conflicts with request`
   - `### Estimated scope`
   - `### Risks`
   - `### Drift noticed`
3. Each section has at least one non-empty line of content
4. The estimated scope section contains exactly one of `S`, `M`, `L`, or `L+`

The validator does not check semantic quality — that's arch-shape's job during synthesis.

## Sections in detail (ops specifics)

### Existing constraints

Cite locations:

```
- 12 services deployed in cluster prod-tw-1; manifests at k8s/services/
- Message queue: RabbitMQ at rabbitmq.infra.svc.cluster.local; deployed
  via helm/rabbitmq (chart version 11.4.2)
- Webhook ingress: nginx-ingress with sticky session annotations on
  k8s/services/webhook-ingress/ingress.yaml:23-31
- Existing cron infrastructure: 4 CronJobs in k8s/cronjobs/, all running
  on the same node pool ("batch")
- Monitoring: Prometheus + Grafana; 23 dashboards; alerts via
  Alertmanager → PagerDuty integration; SLO docs at infra/slo/*
- Secrets: stored in AWS Secrets Manager; loaded into pods via
  external-secrets operator at runtime
- Deployment pattern: rolling update for stateless services; manual
  blue-green for the api gateway (k8s/services/api-gateway/deployment.yaml
  has strategy: Recreate)
```

### Suggested approach

Direction with rationale; propose YAML / config shapes as text:

```
- Add notification-worker as a new Deployment (stateless, ~2 replicas)
  in the existing notifications namespace.
- Reuse the existing RabbitMQ queue infrastructure; create a new
  queue `notifications.shipment_email` via the rabbitmq-operator CRD
  rather than direct admin API calls.
- Standard deployment shape (rolling update, 2 replicas):
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: notification-worker
      namespace: notifications
    spec:
      replicas: 2
      strategy: { type: RollingUpdate, rollingUpdate: { maxUnavailable: 1 } }
      ...
- Monitoring: add 3 standard metrics (jobs_processed, jobs_failed,
  queue_depth); reuse existing Prometheus scrape config (annotation-based
  discovery already in cluster).
```

### Conflicts with request

Be specific about infra / capacity / blast radius conflicts:

```
- Request says "high availability with zero downtime". Current cluster
  is single-AZ; "zero downtime" is bounded by AZ availability. True HA
  requires multi-AZ which is out of scope for this consultation.
- Cron strategy: request implies 1-minute reconciliation interval; existing
  CronJobs run on a node pool sized for hourly+ cadences. Per-minute jobs
  would push beyond current node pool capacity.
- Webhook latency: request says "process within 5 seconds". Current
  ingress -> service -> queue path is ~200ms p99; adding the new worker
  is fine, but the existing alert threshold is 1s — would need adjustment.
```

If genuinely no conflicts:

```
- none
```

### Estimated scope

Includes manifest count + services touched + deployment phases:

```
- M — ~6 manifests, 1 new service, 1 deployment phase:
  - k8s/services/notification-worker/{deployment,service,configmap}.yaml (new)
  - rabbitmq queue resource (1 manifest under rabbitmq-resources/)
  - prometheus alerts (1 PrometheusRule manifest under monitoring/)
  - existing notifications namespace (no change)
  - 1 deployment (rolling update, no coordination needed with other services)
```

If L+, decompose:

```
- L+ — request implies multi-region active-active deployment. This requires:
  1. Infrastructure: provision second region (terraform module)
  2. Networking: cross-region service mesh (Linkerd or Istio mesh expansion)
  3. Data: cross-region database replication (pgsql logical replication)
  4. DNS: GeoDNS or Anycast routing
  5. Operations: runbooks, alert routing, chaos testing
  Strongly suggest decomposing — each step is itself M-L.
```

### Risks

Ops-specific failure modes:

```
- Blast radius: new worker shares the rabbitmq cluster with 4 existing
  services. If the new worker creates a poison-message loop, queue
  pressure could affect the others. Mitigation: separate vhost or
  queue-level rate limiting.
- Capacity: new worker at 2 replicas is fine; if traffic ramps to
  10x estimated load (sometimes happens), would need HPA
  configuration. Recommend HPA from the start (cheap, prevents pages).
- Change windows: rolling deployment is safe any time, but the new
  worker would start consuming events immediately on rollout. If the
  feature flag isn't ready when ops deploys, the worker would fail
  noisily until config arrives. Recommend deploying behind a feature flag.
- Rollback complexity: the rabbitmq queue resource, once created, is
  awkward to remove (would need to drain consumers + delete queue).
  Worth a defined rollback runbook before launch.
- Observability: new worker emits metrics; standard scrape works,
  but dashboards aren't auto-generated. Without a dashboard, on-call
  has reduced visibility for the first incident. Recommend pre-building.
```

### Drift noticed

Codebase / IaC vs running infra; documented arch vs reality:

```
- arch-ddd/operations/deployment-patterns.md describes "all services
  use rolling update". api-gateway is configured Recreate
  (k8s/services/api-gateway/deployment.yaml:42); the doc is stale.
- IaC says rabbitmq has 3 replicas; cluster shows 5 (verified: kubectl
  get sts rabbitmq → 5/5). Drift from 2024-12 incident; never
  reflected in helm values.
- monitoring/alerts/payments.yaml has 8 alerts; arch-ddd lists 6.
  2 alerts added in PR #422 weren't documented.
```

## Common violations

- **Wrong header level** — `# Advice from ops-advisor` instead of `## `
- **Wrong header role** — `## Advice from be-advisor` posted on an ops-advisor consultation
- **Missing section** — skipping "Drift noticed"; even then write `- none`
- **Empty section** — header without content
- **Wrong section names** — `### Approach`, `### Issues`, `### Cost`
- **Scope without S/M/L/L+** — "about 6 manifests" not the contract
- **YAML / scripts longer than ~15 lines** — advice is direction, not implementation; for long examples, link to the relevant existing manifest as a template
- **Adding extra sections** — your bonus sections aren't read by arch-shape

## Quick checklist

Before running `respond.sh`:

- [ ] Header is exactly `## Advice from ops-advisor`
- [ ] All six required sections with exact wording
- [ ] Every section has at least one bullet (or `- none` where applicable)
- [ ] Estimated scope contains S, M, L, or L+
- [ ] No extra sections
- [ ] No long config blocks (advice is direction, not implementation)
