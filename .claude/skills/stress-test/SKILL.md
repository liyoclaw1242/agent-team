---
name: stress-test
description: |
  Conditional sub-skill of `whitebox-validator`. Examines performance-
  sensitive code paths in the PR diff against the sandbox-deployed app: DB
  query plans, request-latency envelopes, concurrency hazards, hot-path
  allocations, N+1 patterns, queue back-pressure.

  Not invoked on every WP — only when impact_scope.estimated_complexity is
  large, OR the WP touches a request handler / DB module / pipeline, OR an
  AC mentions latency/throughput/concurrent users.

  Does not run a full load test (that's a v2 expansion). Does targeted
  micro-benchmarks + static plan analysis.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
agent-class: WhiteBoxValidator (sub-skill)
chained-from: whitebox-validator
---

# stress-test

You are running the `stress-test` sub-skill on behalf of WhiteBoxValidator. Your job: identify performance hazards in the PR's changes — query plans, hot paths, concurrent-access concerns, async resource leaks — and return structured findings.

You are **not** running a full load test (no JMeter, no k6 setup, no 10k-request runs). You're inspecting **what the PR does** under realistic load, with targeted probes if the sandbox is available.

---

## When to skip (signal "no findings, skipped")

Some WPs trip the orchestrator's stress-test invocation rule but on closer look genuinely don't need it. Return an empty finding set with explicit reason if:

- Diff is < 50 lines AND only touches static assets / config / docs
- Touched module has no hot-path call site (Grep callers; if all callers are init / setup / batch tooling, skip)
- AC mentions throughput but in qualitative terms only ("should feel snappy") with no measurable threshold

Don't invent stress concerns. False positives are worse than no test in v1.

---

## Inputs (passed by orchestrator)

- Same as `code-review` (PR diff, WP body, Spec AC, contracts)
- Plus: **sandbox URL** if available (Stage 3 deployed; otherwise this skill is static-only)

---

## What to look at

### Static analysis (always)

1. **DB queries in diff** — `prisma.X.findMany`, raw SQL, `.where({...})`:
   - Missing index? Grep the schema for index declarations matching the query's `where` columns.
   - N+1 risk? Find loops that call DB inside.
   - Unbounded result set? `findMany` with no `take` / pagination.
   - Composite where without composite index.

2. **External-system calls** — `fetch`, `axios`, gRPC, queue.publish:
   - Timeout configured?
   - Retry policy explicit?
   - Idempotency key when retrying?
   - Concurrency cap?

3. **In-process loops** — for/while with non-trivial work per iteration:
   - O(n²) or worse algorithmic complexity?
   - Memory accumulating per iteration without bound?

4. **Async patterns**:
   - `await` inside loops where `Promise.all` would parallelize?
   - Conversely: `Promise.all` without concurrency cap on large arrays?
   - Unhandled rejection paths?

5. **Caching**:
   - Hot read with no cache and no obvious reason?
   - Cache write but no invalidation strategy?

### Dynamic probing (only if sandbox URL provided)

For request-handling code:
- `curl` the affected endpoint 10× with realistic payload, measure p50/p95.
- If endpoint has variants (auth'd vs not, with-data vs empty), probe each.
- Look for: p95 > 500ms on a CRUD endpoint, p95 > 200ms on a read endpoint.

For DB-heavy paths:
- If you can extract the SQL (Prisma `prisma.X.findMany({...})` → log or trace), run `EXPLAIN ANALYZE` against the sandbox DB (only if sandbox has a `psql` exposure or admin endpoint).
- Look for: sequential scans on tables with > 1000 rows, missing index hits, large planning time.

---

## Finding categories

| Category | What it catches |
|---|---|
| `perf-query` | DB query plan / N+1 / missing index / unbounded result |
| `perf-latency` | Endpoint p95 above threshold; expensive sync call in request path |
| `perf-memory` | Unbounded accumulation; large in-process buffer |
| `perf-concurrency` | Missing rate-limit / retry cap / queue back-pressure |
| `perf-async` | `await` in loop where Promise.all is right; missing concurrency cap |

---

## Severity rubric

| Severity | When |
|---|---|
| `blocking` | Will OOM under realistic prod load OR p95 > 5× the AC threshold OR query plan does sequential scan on table > 10k rows |
| `major` | p95 over AC threshold by 1-5× OR N+1 detected in request path OR external call without timeout |
| `minor` | Sub-optimal pattern but works within v1 scale (will surface if scale grows 10×) |
| `note` | Pattern worth tracking for a future perf-tuning pass |

**Hold the bar.** v1 is "make it work for first 100 users" — don't block on "won't scale to 1M". Surface as `note` for tracking.

---

## Output shape

```json
{
  "skill": "stress-test",
  "verdict": "pass" | "fail" | "skipped",
  "skipped_reason": "(if skipped)",
  "probes_run": [
    {"endpoint": "POST /api/invite", "p50_ms": 80, "p95_ms": 240, "samples": 10}
  ],
  "findings": [
    {
      "severity": "major",
      "category": "perf-query",
      "file": "app/api/household/route.ts",
      "line": 25,
      "message": "GET /api/household runs `prisma.household.findMany({include: {members: true}})` without limit. With 1k households × 10 members each, this returns 10k rows + does N+1 on members. Fix: add take:50 + cursor pagination."
    }
  ]
}
```

---

## Decision rules

- **Static first, dynamic second.** Always do the read-through. Dynamic probing is a confirmation, not a replacement.
- **Cite the AC threshold.** If the AC says "p95 < 200ms" and the probe shows 300ms, the finding's `message` includes both numbers + the gap.
- **External system unreachable** (sandbox doesn't have access to Postgres, etc.): degrade to static-only and note this in `skipped_reason` for the dynamic part.
- **No N+1 without proof.** If you suspect N+1, find the inner loop OR show the query log. "Looks N+1-shaped" without evidence is `note` severity.
- **Cache without invalidation = `minor`, not `major`.** Stale cache bugs are real but usually surface in QA before prod.

---

## Examples

### Blocking
```json
{
  "severity": "blocking",
  "category": "perf-query",
  "file": "app/api/list/route.ts",
  "line": 18,
  "message": "GET /api/list runs `findMany({})` (no where, no take) over the global Items table. At 100 users × 50 items = 5k rows returned per request. At 1k users × 50 = 50k rows → OOM risk. Spec AC #2 says response < 500ms; current p95 against sandbox with seeded 5k rows is 1.2s. Fix: scope query by current household, add take/cursor."
}
```

### Major
```json
{
  "severity": "major",
  "category": "perf-async",
  "file": "src/notify.ts",
  "line": 33,
  "message": "Email-notification loop runs `await sendEmail()` sequentially over `members` array. 10 members → 10× single-email latency. Push notifications fan-out should use Promise.all with a concurrency cap of 5. Spec AC #4 mentions 'notifications within 30s'; current sequential pattern blows past at >5 members."
}
```

### Minor
```json
{
  "severity": "minor",
  "category": "perf-query",
  "file": "app/dashboard/page.tsx",
  "line": 8,
  "message": "Dashboard server component fetches user counts via 3 separate queries (households, lists, items). Could be one prepared statement. Not blocking at v1 scale (<100 users); flag for follow-up if dashboard becomes hot."
}
```

### Skipped
```json
{
  "skill": "stress-test",
  "verdict": "skipped",
  "skipped_reason": "WP touches only CONTEXT.md typography + a help text string. No code path stress to evaluate.",
  "findings": []
}
```

---

## Access boundaries (WhiteBoxValidator sub-skill, per ADR-0009)

| Resource | Access |
|---|---|
| Code | ✅ read-only |
| Sandbox URL (HTTP probes) | ✅ via Bash/curl when provided |
| Sandbox DB admin (EXPLAIN ANALYZE) | ✅ only if URL passed explicitly |
| WP / Spec / contracts / facts | ✅ read |
| Code write | ❌ |
| Discord | ❌ |

---

## What this skill does NOT do

- Does not run a real load test (no 10k-request scenarios) — v2 expansion
- Does not modify code
- Does not stress-test the entire app — only the diff's touched paths
- Does not predict scale (v1 = "first 100 users"); future-scale concerns → `note`
- Does not post the verdict — returns findings to whitebox-validator
- Does not validate against running app from a user's POV (that's `e2e-browser-test` under BlackBox)
