# Case: Frontend Error → Backend Trace Correlation

## Symptom
Users report "Something went wrong" on the checkout page. No specific error message.

## Investigation

### Step 1: Faro Logs (Frontend Errors)
```
actions/query-logs.sh '{service_name="faro"} | json | kind = "error"' '2h'
```
Result: `TypeError: Cannot read properties of undefined (reading 'amount')` in `CheckoutSummary.tsx:42`.

Faro log includes `trace_id: "d4e5f6a7b8c9d0e1..."`.

### Step 2: Backend Trace
```
actions/query-traces.sh --id d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9
```
Waterfall:
1. `GET /api/cart` → 200, 45ms
2. `GET /api/pricing/calculate` → 200, 120ms — but response body has `discount: null` instead of `discount: { amount: 0 }`.

### Step 3: Logs for the Pricing Service
```
actions/query-logs.sh '{service_name="pricing-service"} | json | trace_id = "d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9"' '1h'
```
Result: `WARN: no active promotions found, returning null discount`.

### Step 4: Code
`pricing-service/src/calculate.ts:87` — when no promotions exist, returns `{ discount: null }` instead of `{ discount: { amount: 0, type: "none" } }`.

## Root Cause
The pricing service returns `discount: null` when no promotions are active. The frontend's `CheckoutSummary` component accesses `discount.amount` without null check. The API contract (arch.md) specifies `discount` should always be an object with `amount` field — the pricing service violates the contract.

## Dispatch
- `be` — pricing service must return `{ amount: 0, type: "none" }` when no promotions exist (API contract fix)
- `fe` — add defensive null check on `discount` as a safety measure (belt and suspenders)
