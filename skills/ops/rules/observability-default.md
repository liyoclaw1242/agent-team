# Rule — Observability Default

Every new service ships with metrics, logs, and at least one alert. Adding observability after the service is in production is the most common reason for slow incident response.

## What "ships with" means

For new services, the OPS task that brings them to production includes setting up:

1. **Logs**: structured (JSON), at appropriate level, shipped to the log platform
2. **Metrics**: at least RED metrics (Rate, Errors, Duration) for the service's main operations
3. **At least one alert**: typically on error rate or availability
4. **A runbook** (per service): what to do when the alert fires

Without these, the service ships but is operating blind. When something goes wrong, the team is in a worse position than if the service didn't exist.

## Logs

### Format

Structured JSON, one event per line:

```json
{
  "ts": "2026-04-25T14:22:18.000Z",
  "level": "error",
  "service": "cancel-svc",
  "msg": "failed to compute effective date",
  "error": "subscription not found",
  "tracking_id": "ABCD123456",
  "trace_id": "5b8aa5..."
}
```

Required fields:
- `ts` — ISO 8601 UTC
- `level` — debug / info / warn / error
- `service` — service name
- `msg` — human-readable message
- `trace_id` — distributed trace ID (when applicable)

Optional but encouraged: domain-relevant IDs (user_id, request_id, resource_id). Never include secrets, full credit card numbers, full tokens.

### Levels

- `debug`: useful in dev; rarely shipped to prod
- `info`: normal operation events worth recording (request received, job completed)
- `warn`: expected-but-noteworthy events (retry, fallback, degraded path)
- `error`: failures that need investigation

Log volume budget: error-level events should be a tiny fraction of total. A service whose logs are >50% errors is failing or has wrong-leveled logs.

## Metrics

### RED metrics (minimum)

For every service, every endpoint:

- **Rate**: requests per second
- **Errors**: error rate or count (broken out by status class — 4xx vs 5xx)
- **Duration**: p50 / p95 / p99 latency

### USE metrics (for resources)

For databases, caches, queues:

- **Utilisation**: percent of capacity
- **Saturation**: queue depth, waiting requests
- **Errors**: connection failures, timeouts

### Domain-specific metrics

Beyond technical metrics, capture business signals:

- `cancel.requests.total` — counter of cancellation attempts
- `cancel.success.total` — counter of successful cancellations
- `cancel.errors.total{reason}` — counter broken out by error type

These let you answer "is the feature working?" not just "is the service responding?".

## At least one alert

For every new service, at least one alert exists. The minimum useful alert:

```yaml
# Example: PromQL-style
alert: CancelSvcErrorRateHigh
expr: |
  rate(cancel_errors_total[5m]) / rate(cancel_requests_total[5m]) > 0.05
for: 5m
severity: warning
runbook: https://github.com/owner/repo/blob/main/runbooks/cancel-svc/high-error-rate.md
```

Required alert metadata:
- **Severity** (warning / critical) — informs paging behaviour
- **For duration** — avoid flapping (5 min minimum)
- **Runbook link** — what to do when this fires

### Don't fire on every quirk

The most useful alert is one that always means action. If an alert fires multiple times per week with no action, it's training the team to ignore alerts.

Tune alerts so that:
- An alert fire = "human must look now"
- Background noise (one slow request, single 500) doesn't fire
- Trends and dashboards (not alerts) cover the "watch but not urgent" cases

## Runbook per alert

Every alert has a runbook. The runbook answers:

```markdown
# CancelSvcErrorRateHigh

## What this alert means
Cancellation error rate (5xx + 4xx) exceeded 5% of requests for 5 minutes.

## Immediate actions
1. Check cancel-svc deployment status: `kubectl get pods -l app=cancel-svc -n production`
2. Check recent deploys: was there a rollout in the last hour?
3. Check downstream dependencies (subscription-svc, billing-svc) for incidents

## Likely causes (in rough order)
- Recent deploy with a regression → roll back
- Database connection pool exhausted → check db metrics, scale connection pool
- Downstream service degraded → check circuit breaker state
- Surge traffic → check rate metrics, scale replicas

## Mitigation paths
- Roll back: `kubectl rollout undo deployment/cancel-svc -n production`
- Scale up: `kubectl scale deployment/cancel-svc --replicas=N`
- Reroute: failover toggle in feature-flags

## Escalate to
@oncall-be if root cause appears to be in code; arch-judgment if structural.
```

The runbook is the difference between "alert fires, oncall person panics" and "alert fires, oncall person follows checklist".

## Observability is a deliverable, not an extra

In the OPS deliver gate, the self-test for any new-service deploy includes:

```markdown
## Observability checklist
- [x] Service emits structured logs to stackdriver
- [x] RED metrics exposed at /metrics endpoint, scraped by Prometheus
- [x] Alert rule defined: CancelSvcErrorRateHigh; verified to fire under simulated load test
- [x] Runbook at runbooks/cancel-svc/high-error-rate.md
- [x] Domain metrics: cancel.requests.total, cancel.success.total, cancel.errors.total
```

If any item is unchecked, the service isn't done. Don't ship.

## Existing services without observability

If you're working on a service that didn't ship with observability (legacy gap), you have two options:

1. **Add it as part of this task**: scope expansion but often the right call if the task touches the service
2. **File a separate task**: scope creep avoidance; specifically file a follow-up before shipping

Don't ship more changes to an unobservable service without addressing it eventually.

## Anti-patterns

- **"We'll add metrics later when we have time"** — later never comes
- **One alert that fires for everything** — alerts must be specific and actionable
- **Alerts without runbooks** — pages someone who doesn't know what to do
- **Observability that requires SSH-ing into pods** (logging to files, exec into running containers) — doesn't scale, isn't auditable
- **Logs at debug level in prod** — fills disk, costs money, no one reads them
- **Alerts on conditions that can't be acted on** — "disk usage 80%" with no automation to scale = alert fatigue
