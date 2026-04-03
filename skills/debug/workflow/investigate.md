# Investigation Workflow

Reproduce → Observe → Trace → Diagnose → Report → Dispatch → Journal

Each phase has a gate. Do not skip ahead.

---

## Phase 1: Reproduce

> "A bug you can't reproduce is a bug you can't diagnose."

1. **Read the bug report** — extract: symptoms, affected endpoint/page, timestamp, user impact.
2. **Set up env** — check out the relevant branch, install deps, start services.
3. **Attempt reproduction** — follow the exact steps from the report.
4. **Record what happens** — copy error messages, HTTP status codes, console output verbatim.

If reproduction fails:
- Check if the bug is environment-specific (staging vs prod, specific browser, specific data)
- Check if a deploy happened between report time and now (`git log --after=...`)
- If still unreproducible after 3 attempts, note this in the report and proceed to Phase 2 with the original timestamp

**Gate**: You have either reproduced the bug OR documented why you cannot with the original evidence.

---

## Phase 2: Observe

> "Before reading code, read the signals."

Use the observability stack to gather evidence. Work from high-level to specific.

### 2a. Metrics — PromQL (Is there a pattern?)

```bash
# Error rate spike around the reported time
actions/query-metrics.sh 'sum(rate(http_server_request_duration_seconds_count{http_response_status_code=~"5.."}[5m]))' '2h'

# Latency P99 for the affected service
actions/query-metrics.sh 'histogram_quantile(0.99, sum(rate(http_server_request_duration_seconds_bucket{service_name="SERVICE"}[5m])) by (le))' '2h'
```

Look for: sudden spikes, trend changes, correlation with deploys.

### 2b. Logs — LogQL (What error messages?)

```bash
# Errors from the affected service in the time window
actions/query-logs.sh '{service_name="SERVICE"} |= "error" | json' '1h'

# Stack traces
actions/query-logs.sh '{service_name="SERVICE"} |= "Exception" or |= "Error" | json | line_format "{{.trace_id}} {{.message}}"' '1h'
```

Extract any `trace_id` from the logs — you'll need it in the next step.

### 2c. Traces — TraceQL (What's the request path?)

```bash
# Find error traces for the service
actions/query-traces.sh '{ resource.service.name = "SERVICE" && status = error }' '1h'

# Slow requests
actions/query-traces.sh '{ resource.service.name = "SERVICE" && duration > 1s }' '1h'

# If you have a trace ID from logs
actions/query-traces.sh --id <TRACE_ID>
```

In Grafana (http://localhost:3002):
1. Go to **Explore → Tempo**
2. Paste the trace ID or run a TraceQL query
3. Examine the waterfall — which span is slow or errored?
4. Click a span → check attributes (`db.statement`, `http.route`, `error.message`)
5. Click **Logs for this span** to jump to Loki with trace correlation

### 2d. Frontend — Faro (If browser-side)

If the bug involves the frontend:
1. Go to **Explore → Loki**
2. Query: `{service_name="faro"} | json | kind = "error"`
3. Look for: JS errors, failed fetches, web vitals degradation
4. Extract `trace_id` from Faro logs to correlate with backend traces

**Gate**: You have concrete observability evidence — timestamps, trace IDs, error messages, metric trends. Not just "the user said it was slow."

---

## Phase 3: Trace

> "Follow the code path with evidence in hand."

Now read code, guided by what you found in Phase 2.

1. **Identify the entry point** — from trace data, find the HTTP route or event handler.
2. **Follow the span tree** — each span maps to a function call, DB query, or external request.
3. **Check git blame** — who changed the relevant code and when?
   ```bash
   git log --oneline --after="2 weeks ago" -- <file>
   git blame -L <start>,<end> <file>
   ```
4. **Find related issues** — search for similar symptoms in issue tracker.
5. **Check recent deploys** — does the bug timeline correlate with a specific commit?
   ```bash
   git log --oneline --since="<bug_reported_time>" --until="<now>"
   ```

**Gate**: You can point to specific lines of code that are involved.

---

## Phase 4: Diagnose

> "Root cause is not where the error appears. It's why the error exists."

Apply the root cause test:

**Can you explain it in one paragraph without "might be" or "probably"?**

If not, go back to Phase 2 or 3.

### Root cause categories

| Category | Example | Evidence needed |
|----------|---------|-----------------|
| Logic error | Off-by-one, wrong condition | Code + failing test case |
| Race condition | Concurrent writes, stale cache | Trace showing timing overlap |
| Data issue | Null field, schema mismatch | DB query + trace showing bad data |
| Integration | API contract change, timeout | Trace showing failed external call |
| Resource | OOM, connection pool exhausted | Metrics showing resource trend |
| Configuration | Wrong env var, missing flag | Config diff between working/broken |
| Regression | Previous fix reverted/broken | Git bisect result |

### Distinguish symptom from cause

- Symptom: "500 error on /api/orders"
- Intermediate: "NULL pointer in orderService.getTotal()"
- Root cause: "Migration 042 added `discount_amount` column as NOT NULL without default, existing rows have NULL via a pre-migration insert race"

Go deeper until you hit the **first wrong thing** in the causal chain.

**Gate**: One paragraph, no hedging, with trace ID and file:line references.

---

## Phase 5: Report

Post diagnosis on the issue. Use this structure:

```markdown
## Root Cause Analysis — #{ISSUE_N}

**Trace ID**: `<trace_id>`
**Affected service**: `<service_name>`
**Severity**: critical | high | medium | low

### Root Cause

<one paragraph, no hedging>

### Evidence

1. **Trace**: `<TraceQL query>` shows <what>
2. **Logs**: `<LogQL query>` shows <what>
3. **Metrics**: `<PromQL query>` shows <what>
4. **Code**: `<file>:<line>` — <what's wrong>
5. **Git**: `<commit_sha>` introduced on <date>

### Impact

- <who is affected, how many, since when>

### Recommended Fix

- <specific change with file paths and line numbers>
- <estimated complexity: trivial | small | medium | large>

### Suggested Role

`fe` | `be` | `ops` — because <reason>
```

**Gate**: Report is posted on the issue.

---

## Phase 6: Route Back to ARCH

DEBUG diagnoses. **ARCH dispatches.** You do NOT create fix bounties or assign roles.

Post your diagnosis on the issue (Phase 5), then hand back to ARCH:

```bash
curl -s -X PATCH "${API_URL}/bounties/${REPO_SLUG}/issues/${ISSUE_N}" \
  -H "Content-Type: application/json" \
  -d '{"status": "ready", "agent_type": "arch"}'
curl -s -X DELETE "${API_URL}/claims/${REPO_SLUG}/issues/${ISSUE_N}?agent_id=${AGENT_ID}"
```

Your Phase 5 report already includes `### Suggested Role` and `### Recommended Fix` — ARCH uses this to create the fix bounty with the correct `agent_type`.

**Gate**: Diagnosis posted, issue routed back to ARCH.

---

## Phase 7: Journal

Write entry via `actions/write-journal.sh`. Focus on:
- Which observability signals were most useful
- Dead ends and false leads (save others the time)
- Patterns — is this a recurring type of bug?
- Query templates that worked well (save to `cases/`)
