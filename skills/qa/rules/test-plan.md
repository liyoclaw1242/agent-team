# Rule: Test Plan Writing

## Structure

Every test plan is a markdown file with numbered steps. Each step has:
- **Action**: exactly what to do (no ambiguity)
- **Expected**: exactly what should happen
- **Tool**: which tool to use (Chrome MCP / curl / DB CLI / load tool)

## Coverage Requirements

- Every acceptance criterion in the spec → at least one step
- Every dimension that applies → at least one happy path + one error case
- If the spec is vague, ask for clarification via issue comment before writing the plan

## Naming

- File: `test-plans/{ISSUE_N}-{short-slug}.md`
- Steps: `U{N}` (UI), `A{N}` (API), `D{N}` (DB), `L{N}` (Load), `E{N}` (Edge case)

## Timing

- Write the plan as soon as the spec is claimed — do NOT wait for implementation to finish
- Update the plan if the spec changes (note the change in the plan header)

## Failure Triage — Surface-Level Classification

When a verification step fails, QA does NOT debug. QA does **surface-level triage** (10 seconds) to route the issue accurately.

### Triage Steps (Chrome MCP)

After any UI failure:

1. **Check Console** — open DevTools Console, look for red errors
2. **Check Network** — open DevTools Network tab, find the relevant request
3. **Classify** based on what you see:

```
Failure observed (e.g., button click does nothing)
  ↓
Check Network tab
  ↓
├─ No request sent         → FE issue (event handler broken)
├─ Request sent, API 4xx   → FE issue (wrong payload or missing param)
├─ Request sent, API 5xx   → BE issue (server error)
├─ Request sent, API 200   → FE issue (response handling broken)
│   but UI didn't update
└─ Can't tell / complex    → DEBUG (attach all context)
```

### Routing Rules

| Route to | When | QA provides |
|----------|------|-------------|
| **FE** | No request sent, or API succeeded but UI broken | Operation steps + screenshot + console errors |
| **BE** | API returned 5xx, or response body is wrong | curl command + actual response |
| **DEBUG** | Can't determine from surface, or involves multiple systems | Operation steps + network log + console log + curl |

**QA never:**
- Reads source code to find the bug
- Traces call stacks
- Attempts to fix anything
- Spends more than 1 minute on triage

If 1 minute passes and it's unclear → route to DEBUG with all collected context.

## Rejection Feedback Format

Feedback must be **immediately actionable** — reproduction steps in the receiving agent's language.

### → FE: provide operation steps

```
## QA Feedback — FAIL → FE

### Steps to reproduce:
1. Open http://localhost:3000/dashboard
2. Click "Create New" button (top right)
3. Fill in "Name" field with "Test Project"
4. Click "Submit"
5. **Expected**: redirect to /dashboard with new item in list
6. **Actual**: stays on form, no error message shown

### Console errors:
TypeError: Cannot read properties of undefined (reading 'id')
  at handleSubmit (CreateForm.tsx:42)

### Network:
No request was sent to /api/projects

### Screenshot:
(attach)
```

### → BE: provide curl + response

```
## QA Feedback — FAIL → BE

### curl to reproduce:
curl -X POST http://localhost:8000/api/projects \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"name": "Test Project"}'

**Expected**: 201 with `{ "id": ..., "name": "Test Project" }`
**Actual**: 500 with `{ "error": "column \"created_at\" cannot be null" }`

### DB state after request:
psql -c "SELECT id, name, created_at FROM projects ORDER BY id DESC LIMIT 3"
(no new row inserted)
```

### → DEBUG: provide full context

```
## QA Feedback — FAIL → DEBUG

### What happened:
Clicked "Add to Cart" on product page, nothing happened.

### Steps to reproduce:
1. Open http://localhost:3000/products/123
2. Click "Add to Cart" button

### Network:
POST /api/cart/items → 200 OK
Response: { "success": true, "cartId": "abc-123" }

### Console:
No errors

### UI state:
Cart badge still shows "0", no feedback to user.
Page did not navigate. No toast/notification appeared.

### Notes:
API says success but UI doesn't reflect it.
Could be FE state management, SSE/WebSocket issue, or API returning wrong data.
Cannot determine from surface — needs deeper investigation.
```

This format lets receiving agents reproduce the issue in one step without guessing.
