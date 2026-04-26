# Rule — Schema Compliance

The advice comment is mechanically validated. Format violations cause `actions/respond.sh` to refuse posting.

## The exact schema

```markdown
## Advice from be-advisor

### Existing constraints
- {bullet}
- {bullet}

### Suggested approach
- {bullet}
- {bullet}

### Conflicts with request
- {bullet}
(or single line: "none")

### Estimated scope
- {S | M | L} — {file count} files, {contract / migration count} contracts/migrations

### Risks
- {bullet}

### Drift noticed
- {bullet}
(or single line: "none")
```

## What the validator checks

`validate/advice-format.sh --role be-advisor`:

1. First non-empty line is exactly `## Advice from be-advisor`
2. All six required `### ` sections present:
   - `### Existing constraints`
   - `### Suggested approach`
   - `### Conflicts with request`
   - `### Estimated scope`
   - `### Risks`
   - `### Drift noticed`
3. Each section has at least one non-empty line of content
4. The estimated scope section contains exactly one of `S`, `M`, `L`, or `L+`

The validator does not check semantic quality — that's arch-shape's job during synthesis.

## Why a strict schema

arch-shape's brainstorm flow extracts each section by exact name. If be-advisor uses `### Approach` instead of `### Suggested approach`, the extraction silently drops it. The strict format is the contract.

The same schema applies for `fe-advisor`, `ops-advisor`, and `design-advisor` — only the `## Advice from {role}` header changes. Cross-advisor synthesis depends on this consistency.

## Sections in detail (backend specifics)

### Existing constraints

Cite locations:

```
- Payment service at services/payments/handler.go:42 exposes /charge,
  /refund, /capture endpoints; handler functions in service.go
- Contract for /charge defined in contracts/payments.proto:34 (Charge RPC);
  client SDK generated at gen/payments/payments_pb.ts
- 4 services consume payments contract: orders (orders/internal/payments_client.go),
  billing (billing/internal/charge.go), refunds (refunds/handler.go),
  webhook-handler (handlers/webhooks/payment.go)
- Database: payments.charges table, schema at db/migrations/2024-03-15-charges.sql;
  primary indexes on (user_id), (created_at)
```

### Suggested approach

Direction with rationale; propose contract shapes as text, not files:

```
- Add a new RPC `RefundCharge` to payments.proto rather than overloading
  the existing `Refund` (existing has different semantics — partial
  refund of un-captured authorization, not full refund of captured charge)
- New table column `refunded_at TIMESTAMPTZ NULL` on `charges` rather
  than separate refunds table — refund is 1:1 with charge in our model;
  separate table over-engineers
- Proposed contract shape:
    rpc RefundCharge(RefundChargeRequest) returns (RefundChargeResponse);
    message RefundChargeRequest { string charge_id = 1; string reason = 2; }
    message RefundChargeResponse { string refund_id = 1; Status status = 2; }
- Idempotency key: client passes one in metadata header; we dedupe via
  Redis cache (existing pattern in services/payments/idempotency.go)
```

### Conflicts with request

Be specific about contract / data integrity / semantic conflicts:

```
- Request says "refunds are instant". Stripe API refund is async; webhook
  arrives N seconds later. Either change the request to "refund initiated"
  language, or add a polling loop on the response.
- Request implies one refund per charge. Existing data model assumes
  this. If partial refunds are wanted in future, this PR's schema (single
  refunded_at column) would need migration. Worth noting.
```

If genuinely no conflicts:

```
- none
```

### Estimated scope

Includes file count + contract/migration count:

```
- M — ~10 files, 1 contract change, 1 migration:
  - contracts/payments.proto (add RefundCharge RPC)
  - services/payments/refund_handler.go (new — implement RPC)
  - services/payments/refund_test.go (new)
  - db/migrations/{date}-refunded-at-charges.sql (add column)
  - 4 client services updated to use new RPC (orders, billing, refunds, admin)
  - generated code (gen/payments/payments_pb.{go,ts}) — regenerated
```

If it's L+, say so:

```
- L+ — request implies multi-currency refund support; current code is
  USD-only at the schema level. Adding currency requires:
  1. Schema migration adding currency column to all monetary tables (8 tables)
  2. Service-layer changes for FX rate resolution
  3. Client SDK regeneration across 4 consumers
  4. Backfill strategy for legacy USD-only rows
  Strongly suggest decomposing into "introduce currency model" then
  "currency-aware refunds".
```

### Risks

Backend-specific failure modes:

```
- Idempotency: if client retries during webhook processing, double-refund
  risk if dedup window is too short. Recommend 24h dedup window with
  monitoring on duplicate-key hits.
- Data integrity: webhook may arrive before /charge response returns.
  Existing pattern (services/payments/webhook.go:88) handles this via
  optimistic record creation; verify new RPC follows same pattern.
- Performance: every refund triggers a webhook + DB write + cache
  invalidation. At 1000 refunds/min the existing webhook queue would
  saturate (current capacity ~500/min); load-test before launching.
- Breaking-change risk: if RefundCharge ever needs a field added,
  contract evolution rules apply (new fields must be optional; field
  numbers can't be reused).
```

### Drift noticed

```
- arch-ddd/bounded-contexts/payments.md describes a single payment provider
  (Stripe). Codebase has Adyen integration merged in PR #145 not yet in arch-ddd.
- contracts/payments.proto has 3 deprecated RPCs (deprecated="true" annotation):
  ChargeOnce, ChargeOnceWithFee, ChargeOnceLegacy. arch-ddd doesn't
  mention deprecation status; worth aligning before adding new RPCs.
```

## Common violations

- **Wrong header level** — `# Advice from be-advisor` instead of `## `
- **Wrong header role** — `## Advice from fe-advisor` posted on a be-advisor consultation
- **Missing section** — skipping "Drift noticed" because nothing seems wrong; even then, write `- none`
- **Empty section** — section header with no content
- **Wrong section names** — `### Approach`, `### Issues`, `### Cost`
- **Scope without S/M/L/L+** — "about 10 files" is not the contract
- **SQL or code blocks longer than ~10 lines** — advice is high-level; for long examples, link to a file or write prose
- **Adding extra sections** — your own bonus sections aren't read by arch-shape

## Quick checklist

Before running `respond.sh`:

- [ ] Header is exactly `## Advice from be-advisor`
- [ ] All six required sections with exact wording
- [ ] Every section has at least one bullet (or `- none` where applicable)
- [ ] Estimated scope contains S, M, L, or L+
- [ ] No extra sections
- [ ] No long code blocks (advice is direction, not implementation)
