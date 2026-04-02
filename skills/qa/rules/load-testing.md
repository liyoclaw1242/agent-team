# Rule: Load Testing

## Tools (pick what's available)

| Tool | Install | Best for |
|------|---------|----------|
| **k6** | `brew install k6` | Scripted scenarios, thresholds |
| **autocannon** | `npx autocannon` | Quick HTTP benchmarks |
| **ab** | Pre-installed (macOS) | Simple single-endpoint tests |

## Default Thresholds

Unless the spec defines thresholds, use these baselines:

| Metric | Acceptable | Warning | Fail |
|--------|-----------|---------|------|
| p95 latency | < 500ms | 500-1000ms | > 1000ms |
| p99 latency | < 1000ms | 1-2s | > 2s |
| Error rate | < 1% | 1-5% | > 5% |
| Throughput | > 50 rps | 20-50 rps | < 20 rps |

These are conservative defaults for typical web apps. Adjust based on the project's SLA if known.

## When to Load Test

- Spec mentions performance, scale, or throughput
- New endpoint that could be hit frequently (list pages, search, public APIs)
- Database-heavy operations (reports, aggregations, bulk operations)
- NOT needed for: admin-only pages, one-time setup endpoints, static content

## Quick Test Patterns

```bash
# ab — simplest, already installed
ab -n 1000 -c 50 http://localhost:8000/api/items/

# autocannon — quick with nice output
npx autocannon -c 50 -d 30 http://localhost:8000/api/items/

# k6 — scripted scenario
k6 run --vus 50 --duration 30s scripts/load-test.js
```

Use `actions/run-load-test.sh` for a standardized wrapper.

## Recording Results

Report must include:
- Tool + exact command used
- VUs (virtual users) and duration
- p50, p95, p99 latency
- Total requests and error count
- Verdict against thresholds
