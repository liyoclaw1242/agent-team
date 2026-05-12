---
name: api-contract-test
description: |
  Sub-skill of `blackbox-validator`. HTTP-level verification of an AC against
  the sandbox app. Used when the AC concerns API endpoints (request/response
  shapes, status codes, auth requirements, error modes) rather than UI flows.

  Reads the relevant `.rlm/contracts/*.md` if applicable — those declare the
  externally-observable invariants the producer (this app) commits to.

  Faster + more deterministic than `e2e-browser-test`. For full-stack WPs,
  the orchestrator typically runs `api-contract-test` first (fails fast on
  backend bugs), then `e2e-browser-test`.
allowed-tools:
  - Bash
  - Read
agent-class: BlackBoxValidator (sub-skill)
chained-from: blackbox-validator
---

# api-contract-test

You verify an AC by making HTTP calls to the sandbox app and asserting on responses. Like `e2e-browser-test` but at the protocol layer — no DOM, no JS, just request/response.

You verify the **specific AC** the orchestrator handed you. One AC = one set of probes = one PASS/FAIL.

---

## Inputs (passed by orchestrator)

- The specific AC to verify
- Sandbox URL
- Optional: `.rlm/contracts/<slug>.md` slug if the WP touches a contract
- Optional: pre-issued auth token / session cookie for authenticated probes
- Optional: seed data references

---

## When to use vs `e2e-browser-test`

| AC says | Use |
|---|---|
| "endpoint X returns Y" / "401 for unauthenticated" / "response body has field Z" | `api-contract-test` |
| "event of shape S fires when ..." (server-side event) | `api-contract-test` (subscribe / poll endpoint) |
| "user clicks X and sees Y" | `e2e-browser-test` |
| "mobile rendering of Z" | `e2e-browser-test` |
| "p95 < 200ms" | `api-contract-test` (measure latency via repeated probes) |
| Both UI + API claims | Run **both** — `api-contract-test` first |

---

## Process

### 1. Translate the AC into probes

For each assertion in the AC, identify:
- HTTP method + path
- Required headers (auth, content-type)
- Request body (if any)
- Expected status code
- Expected response body shape (or specific field values)
- Expected response time bounds (if AC mentions latency)

If the AC references a contract (`.rlm/contracts/<slug>.md`), read it and extract:
- The endpoint's declared shape
- Its invariants
- Its error modes

The probes must verify **all of**: the AC + the contract's declared invariants.

### 2. Run probes

Use `curl` (always available) or `httpx` if richer features needed.

```bash
# Happy path
curl -sS -w "\nstatus=%{http_code}\nlatency=%{time_total}\n" \
  -X POST "https://wp4-xxx.vercel.app/api/household" \
  -H "Cookie: session=$AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test household"}'

# Negative: missing auth
curl -sS -w "\nstatus=%{http_code}\n" \
  -X POST "https://wp4-xxx.vercel.app/api/household" \
  -H "Content-Type: application/json" \
  -d '{"name": "Test"}'

# Negative: malformed body
curl -sS -w "\nstatus=%{http_code}\n" \
  -X POST "https://wp4-xxx.vercel.app/api/household" \
  -H "Cookie: session=$AUTH_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{}'
```

For latency ACs: run the probe 10× and compute p50/p95 from the `time_total` values.

### 3. Verify against expectations

For each probe:
- Status code matches?
- Body shape matches (parse JSON, check keys)?
- Specific field values match?
- Latency within bound?

If using a contract, also verify:
- Response shape conforms to the contract's declared schema
- Error responses match the contract's error modes
- Headers conform to contract requirements

### 4. Decide PASS / FAIL + classify

- **PASS**: all probes match expectations + contract invariants hold
- **FAIL — implementation-defect**: AC is clear, response doesn't match; cause is code
- **FAIL — ac-ambiguity**: AC is unverifiable — no single response shape satisfies it, OR the AC refers to internal state not exposed via API
- **error**: sandbox unreachable / DNS error / timeout > 30s

### 5. Return structured result

```json
{
  "ac_id": "AC#3",
  "method": "api-contract-test",
  "verdict": "pass" | "fail" | "error",
  "evidence": [
    {
      "type": "http-call",
      "request": "POST /api/invite (no auth)",
      "status": 200,
      "expected_status": 401,
      "body_excerpt": "{\"token\":\"magic-xyz...\"}"
    },
    {
      "type": "http-call",
      "request": "POST /api/invite (with auth)",
      "status": 200,
      "latency_ms": 87
    }
  ],
  "failure_classification": "implementation-defect",
  "message": "POST /api/invite without auth cookie returns 200 + creates invite. AC says auth is required (401 expected). Inferred: middleware missing on /api/invite/* route.",
  "contract_violations": [
    {
      "contract": "household-api",
      "invariant": "All endpoints return 401 if session cookie is missing or invalid",
      "violation": "POST /api/invite returned 200 without session"
    }
  ]
}
```

---

## Decision rules

- **Verify both happy and negative paths.** If AC mentions any error semantics ("returns 401 on X", "rejects malformed body"), probe both the success and the error path. Negative-path bugs are the most common.
- **Contract invariants are mandatory checks.** If the WP touches a contract, every invariant in the contract gets probed. A pass on the AC alone but a contract violation = FAIL with `contract_violations` populated.
- **Latency ACs need ≥10 samples.** p95 from 3 samples is noise.
- **Cite the specific gap.** "Response status was X, expected Y" not "API didn't work".
- **DNS / connection refused → `verdict: error`.** Don't classify as implementation-defect; the sandbox itself is broken (Stage 3 deploy issue). Orchestrator escalates to Arbiter.
- **Idempotency probes**: if the contract declares an endpoint idempotent, call it twice and verify both outcomes match. Skip if not declared.

---

## Examples

### Pass
```json
{
  "ac_id": "AC#1",
  "method": "api-contract-test",
  "verdict": "pass",
  "evidence": [
    {"type": "http-call", "request": "POST /api/household (auth)", "status": 201, "body_excerpt": "{\"id\":\"...\",\"members\":[...]}"},
    {"type": "http-call", "request": "POST /api/household (no auth)", "status": 401}
  ],
  "message": "Endpoint /api/household correctly returns 201 with auth + 401 without. Response shape matches household-api contract."
}
```

### Fail — implementation defect
```json
{
  "ac_id": "AC#2",
  "method": "api-contract-test",
  "verdict": "fail",
  "evidence": [
    {"type": "http-call", "request": "POST /api/invite (no auth)", "status": 200, "expected_status": 401}
  ],
  "failure_classification": "implementation-defect",
  "message": "POST /api/invite returns 200 without auth cookie. AC and contract both require 401. Likely middleware missing for /api/invite/* — a code fix Worker can make in attempt 2.",
  "contract_violations": [
    {"contract": "invite-flow", "invariant": "auth required", "violation": "200 returned with no session"}
  ]
}
```

### Fail — AC ambiguity
```json
{
  "ac_id": "AC#5",
  "method": "api-contract-test",
  "verdict": "fail",
  "failure_classification": "ac-ambiguity",
  "message": "AC says 'API should be fast'. No threshold given, no measurement window stated. No probe can verify 'fast' — needs a measurable target (e.g., p95 < 300ms over 7d). Recommending Spec refinement via business-model-probe."
}
```

### Error (sandbox unreachable)
```json
{
  "ac_id": "AC#1",
  "method": "api-contract-test",
  "verdict": "error",
  "message": "Sandbox URL https://wp4-xxx.vercel.app unreachable: DNS resolution failed after 3 attempts. Stage 3 sandbox deploy may have failed. Escalate to Arbiter."
}
```

---

## Access boundaries (per ADR-0009)

| Resource | Access |
|---|---|
| Sandbox URL via HTTP (curl / httpx) | ✅ |
| Spec AC text | ✅ |
| `.rlm/contracts/*.md` | ✅ read |
| Code | ❌ |
| `.rlm/facts/*` | ❌ |
| Discord | ❌ |
| RLM write | ❌ |

---

## What this skill does NOT do

- Does not test UI (`e2e-browser-test` for that)
- Does not read source code
- Does not write code
- Does not aggregate findings — returns per-AC result to `blackbox-validator`
- Does not run a load test (`stress-test` under WhiteBox does targeted probing; full load testing is a v2 expansion)
