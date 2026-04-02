# Case: Database Slow Query

## Symptom
Dashboard page takes 8+ seconds to load. Only affects users with large datasets (100k+ records).

## Investigation

### Step 1: Traces
```
actions/query-traces.sh '{ resource.service.name = "dashboard-api" && span.db.system = "postgresql" && duration > 2s }' '4h'
```
Result: repeated slow span on `SELECT ... FROM analytics_events WHERE user_id = $1 ORDER BY created_at DESC`.

Span attributes:
- Duration: 6.2s
- `db.operation`: SELECT
- No LIMIT in the query

### Step 2: Metrics (DB-Level)
```
actions/query-metrics.sh 'postgresql_rows_fetched_total{table="analytics_events"}' '24h' '5m'
```
Result: rows fetched spikes to 500k+ during slow queries. Normal is ~1k.

### Step 3: Check Index
```sql
-- Run via psql (read-only)
SELECT indexname, indexdef
FROM pg_indexes
WHERE tablename = 'analytics_events';
```
Result: index exists on `user_id` but NOT a compound index on `(user_id, created_at)`. The `ORDER BY created_at` triggers a sort on all matching rows.

### Step 4: Verify
```
-- Check table stats
SELECT n_live_tup FROM pg_stat_user_tables WHERE relname = 'analytics_events';
```
Result: 12M rows. For users with 100k+ events, sorting without index is O(n log n) on 100k rows.

## Root Cause
The query `SELECT ... FROM analytics_events WHERE user_id = $1 ORDER BY created_at DESC` has an index on `user_id` but no compound index covering the `ORDER BY`. For users with >100k events, PostgreSQL performs an in-memory sort that takes 5-8 seconds. Adding `LIMIT` would help symptomatically, but the real fix is the compound index.

## Dispatch
Assigned to `be`:
1. Add migration: `CREATE INDEX CONCURRENTLY idx_analytics_events_user_created ON analytics_events (user_id, created_at DESC)`
2. Add `LIMIT 1000` to the query as a safety cap
3. Consider pagination for the dashboard API endpoint
