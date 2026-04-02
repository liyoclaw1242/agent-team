# Case: API Latency Spike

## Symptom
P99 latency on `POST /api/orders` jumped from 200ms to 3s after a deploy.

## Investigation

### Step 1: Metrics
```
actions/query-metrics.sh 'histogram_quantile(0.99, sum(rate(http_server_request_duration_seconds_bucket{http_route="/api/orders"}[5m])) by (le))' '6h'
```
Result: sharp jump at 14:32 UTC — correlates with deploy `abc123`.

### Step 2: Traces
```
actions/query-traces.sh '{ resource.service.name = "order-service" && span.http.route = "/api/orders" && duration > 2s }' '2h'
```
Result: 47 slow traces found. Waterfall shows `db.query` span taking 2.8s.

### Step 3: DB Span Details
Span attributes:
- `db.system`: postgresql
- `db.statement`: `SELECT * FROM products WHERE id IN (...)`
- `db.operation`: SELECT

The `IN` clause contains 500+ IDs — no pagination.

### Step 4: Git Blame
```bash
git log --oneline --after="2024-03-01" -- src/services/order.ts
```
Commit `abc123` changed `getProducts()` to fetch all related products in a single query instead of batched.

## Root Cause
Commit `abc123` removed the batch-fetch logic (50 IDs per query) and replaced it with a single `WHERE id IN (...)` containing up to 800 IDs. PostgreSQL's query planner switches from index scan to sequential scan above ~100 values, causing 10-15x slowdown.

## Dispatch
Assigned to `be` — restore batch-fetch with configurable batch size, add index on `products.id` if missing.
