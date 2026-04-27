# Rule — Evidence Over Opinion

Every claim cites concrete evidence: manifest path, config field, dashboard reference, metric value, recent incident, deploy log. Opinions without evidence dilute the consultation's value.

## The contrast

**Opinion** (low value):
```
- The cluster is over-utilised
- Deployments take a while
- Adding a worker is easy
```

**Evidence** (high value):
```
- Cluster prod-tw-1 currently at ~75% CPU committed (verified: kubectl
  describe nodes | grep cpu/limit). 4 nodes; node pool autoscaler
  configured 2-8.
- Standard rolling deployment for stateless services takes 2-3 minutes
  end-to-end (verified: GH Actions run history for last 10 deploys
  averaged 2m41s).
- Adding a stateless worker follows established pattern: 5 manifests
  (deployment, service, configmap, prometheus rule, ingress if
  needed). Templates exist at k8s/templates/stateless-worker/.
```

The evidence answers "how do you know?" before arch-shape has to ask.

## How to gather evidence (ops tools)

```bash
# Cluster state (read-only)
kubectl get pods -A
kubectl get deployments -A
kubectl describe node <node-name>
kubectl top nodes      # if metrics-server present
kubectl top pods -n <namespace>

# IaC inspection
find . -name "*.tf" | xargs grep -l "resource"
helm list -A
helm get values <release-name>

# Pipeline history
gh run list --limit 30
gh workflow view "deploy-prod.yml"

# Logs (read-only, sample)
kubectl logs -n payments deployment/api --tail=100

# Recent commits / PRs to infra
git log --oneline -30 -- k8s/ infra/ helm/
gh pr list --state merged --search "label:ops" --limit 10

# Monitoring config
ls monitoring/alerts/ monitoring/dashboards/
cat monitoring/slo/*.md

# Capacity
grep -A2 "resources:" k8s/services/*/deployment.yaml | head -50
```

The investigation is most of the work. The writeup is summary.

## Citation conventions

In the advice:

- **manifest:line** — `k8s/services/api/deployment.yaml:42`
- **helm reference** — `helm/notifications values.yaml`
- **terraform reference** — `terraform/modules/postgres/main.tf:resource.aws_db_instance.primary`
- **commit / PR** — `(commit a1b2c3d)` or `(PR #145)`
- **kubectl output** — `(verified: kubectl get nodes → 4 nodes)`
- **CI run** — `(verified: GH Actions run #1234, deploy succeeded in 2m30s)`
- **arch-ddd reference** — `(arch-ddd/operations/deployment-patterns.md)`
- **runbook reference** — `(runbooks/incident-response/payments-down.md)`
- **dashboard reference** — `(Grafana → Payments → Latency)`
- **metric value** — `(p99 webhook lag = 800ms over last 24h)`

## When evidence is unavailable

Sometimes you can't gather evidence in 2 hours — infra unfamiliar, monitoring undocumented, etc. Two options:

### Option 1: Acknowledge limit explicitly

```markdown
### Existing constraints

- Deployment pattern: confident from manifest inspection that all stateless
  services use rolling update; haven't verified the actual deploy outcome
  in production for the last quarter
- Capacity: I read the resource limits in manifests but haven't checked
  utilisation against current load via metrics
- Monitoring: alerts configured per the alerts/ directory; haven't
  verified Alertmanager → PagerDuty integration is currently active
```

### Option 2: Defer with a follow-up

```markdown
### Conflicts with request

- Request implies real-time autoscaling. I can describe HPA presence
  in manifests, but I haven't verified scaling behavior under real
  load. Recommend a follow-up consultation specifically focused on
  autoscaling behavior validation if real-time scaling is critical.
```

## Counts vs estimates

When possible, count:

- "many services" — opinion
- "~30 services" — estimate
- "23 services in production cluster (verified: kubectl get deployments -A | wc -l)" — measured
- "uses Kubernetes" — opinion
- "8 services on k8s, 4 services on EC2 via legacy ASG, 1 service on Lambda" — measured

## Ops-specific evidence priorities

For ops, certain evidence types matter more than others:

### Capacity fingerprints

When a request implies capacity allocation:
- Current resource committed (CPU, memory; from `kubectl describe node`)
- Headroom (% utilisation; from metrics)
- Autoscaling status (HPA configured? boundaries?)
- Known peaks (incident reports of capacity events)

### Blast-radius fingerprints

When a request introduces shared dependencies:
- What else uses this dependency (other services using rabbitmq, Redis, DB)
- Failure isolation (vhosts, namespaces, separate clusters)
- Recent incidents involving the dependency

### Change-window fingerprints

When a request implies non-trivial deploys:
- Established change windows (off-hours? feature flags? blue-green?)
- Past similar deploys (success rate, rollback rate)
- On-call coverage (deploy during low-coverage periods is risky)

### SLO fingerprints

When a request affects user-facing reliability:
- Existing SLO for the affected surface
- Current burn rate
- Error budget status

## Anti-patterns

- **"Capacity will be tight"** without measurements
- **"Deployment is slow"** without timing
- **"This service is fragile"** without past-incident reference
- **"Easy to add a CronJob"** without checking node pool capacity for the cadence
- **Citing memory of cluster state** — cluster state changes; verify via kubectl
- **Reporting only what supports the conclusion** — confirmation bias
- **Inferring infra from arch-ddd alone** — arch-ddd is often stale; verify
- **Confusing "we have monitoring" with "monitoring is sufficient"**

## Why this matters most for advisors

For implementer roles (ops), opinion shows up in deploys — incidents catch it. For advisor roles, opinion shows up in the advice arch-shape uses to decide. Bad advice → bad decomposition → wasted ops cycles, possibly outages. The error compounds.

The rule isn't "be exhaustive". It's "every assertion should be one a reader can verify in 30 seconds — by reading a manifest, running a `kubectl get`, or checking a dashboard". If that's possible, the assertion is sound.

## Quick checklist

- [ ] Every constraint bullet has a manifest / config / dashboard / metric reference
- [ ] Suggested approach cites which existing infra pattern it extends
- [ ] Conflicts give specific reasons (not vague concerns)
- [ ] Scope estimate has counts (manifests, services, phases)
- [ ] Risks describe concrete failure modes (not just "risky")
- [ ] Drift includes both arch-ddd / IaC reference and runtime reality
