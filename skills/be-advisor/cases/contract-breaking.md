# Case — Contract-Breaking Request

A request that, taken at face value, would force a breaking contract change. be-advisor surfaces the breaking-vs-additive trade-off and proposes a non-breaking path when one exists.

## The consultation

Parent issue #815: "Change the `amount` field in payment responses from cents (int64) to a Money struct (with currency)."

arch-shape opened consultation #816 to be-advisor:

```
- What's the current shape of payment amount fields?
- Is the change breaking? What's the consumer impact?
- Recommended path?
```

## Phase 1 — Investigate

```bash
# Current contract
cat contracts/payments.proto | grep -B2 -A8 "amount"
# → message Charge {
#     int64 amount_cents = 2;
#     ...
#   }
# → No currency field on Charge currently

# Other amount fields in proto
grep -rn "amount\|cents" contracts/
# → payments.proto has 'amount_cents' on Charge, RefundResponse, FeeBreakdown
# → no Money type defined anywhere

# Consumers of Charge.amount_cents
git grep -l "amount_cents\|AmountCents" services/ apps/
# → 11 files: orders, billing, refunds, admin, accounting, ...

# Existing currency handling
git grep -l "currency\|Currency\|USD\|EUR" services/payments/
# → some hardcoded "USD" in services/payments/handler.go
# → no currency field in DB schema for charges

# DB schema
grep -A5 "CREATE TABLE charges" db/migrations/*.sql
# → CREATE TABLE charges (
#     id UUID PRIMARY KEY,
#     amount_cents BIGINT NOT NULL,  -- no currency column
#     ...
#   )

# Recent contract evolution patterns
git log --oneline -20 -- contracts/payments.proto
# → mostly additive changes; one deprecation marker exists for ChargeOnceLegacy
# → suggests deprecation pattern is used in this codebase

# arch-ddd
cat arch-ddd/bounded-contexts/payments.md | grep -A3 -i currency
# → "Currently USD-only; multi-currency is post-MVP"
```

## Phase 2 — Compose response

```markdown
## Advice from be-advisor

### Existing constraints

- Current contract (contracts/payments.proto):
  - `Charge` message has `int64 amount_cents = 2`; no currency field
  - `RefundResponse` has `int64 amount_cents`
  - `FeeBreakdown` has multiple `_cents` fields
- No `Money` type or currency abstraction exists in the contract or codebase.
- Database schema (charges, refunds, fees tables) stores amount as BIGINT
  cents only; no currency column anywhere (verified across migrations).
- Currency is implicitly USD, hardcoded in 4 places: services/payments/handler.go,
  services/payments/refund.go, services/billing/invoice.go, services/payments/fee.go.
- 11 consumer files use `amount_cents` / `AmountCents`.
- arch-ddd states: "Currently USD-only; multi-currency is post-MVP".

### Suggested approach

The literal request — change `int64 amount_cents` to a Money struct —
would be a **type change on an existing field**, which is breaking in
proto. Two paths:

- **A) Type change in place (breaking)**: rename or repurpose field 2.
  Every consumer breaks until updated. Coordination cost is high.
  This is the path requested but not the recommended one.

- **B) Add Money fields alongside, deprecate cents (additive then
  cleanup)**:
  - Add a new `Money amount = 10` field on Charge (using a fresh field
    number; introduce a `Money` message with `amount_cents int64` and
    `currency string`)
  - Mark `amount_cents = 2` as deprecated via comment
  - During transition, set both fields server-side; consumers can
    use either
  - Once all consumers migrate to Money, schedule a follow-up to remove
    `amount_cents` (still field number 2; reserve it after removal)
  - Schema change: add `currency` column to charges, refunds, fees
    tables (defaulting to 'USD' for existing rows)

Direction B is non-breaking, follows the codebase's deprecation pattern,
and gives a clear migration path.

### Conflicts with request

- The request as literally stated is breaking. If arch-shape wants the
  non-breaking path (B), the request should be reframed: "Introduce
  multi-currency support; old amount_cents field deprecated".
- Direction B makes the contract larger (new fields alongside old);
  some teams prefer breaking + clean over compatible + cluttered.
  Surface to arch-shape; not advisor's call.

### Estimated scope

- For Direction A (breaking type change): L — ~15 files:
  - 1 contract change (Charge, RefundResponse, FeeBreakdown all updated)
  - 11 consumer files updated to handle new type
  - 1 migration (add currency column)
  - 2-3 test files
  - Coordination: all consumer PRs must merge in lockstep with the
    contract change. Realistically requires careful release planning.

- For Direction B (additive + deprecation): M — ~10 files:
  - 1 contract change (additive only)
  - Server-side dual-write logic (~3 files: handler, refund, fee)
  - 1 migration (add currency column with default)
  - Consumers updated incrementally over time (not in this PR)
  - Less test churn since old paths still work

- For Direction B's eventual cleanup PR (90 days later): S — 1
  contract change, ~3 files removing dual-write logic, 1 migration to
  drop the old column if desired.

### Risks

- Direction A risks: consumer drift if any service is missed in the
  lockstep release; data corruption if a migration runs before code
  catches up; rollback complexity (can't easily revert just one part).

- Direction B risks: dual-write inconsistency (server writes both
  amount_cents and amount.cents; if they ever disagree, which is
  truth?). Mitigate with: server always derives amount_cents from
  amount.cents during the transition; never accept both as input.

- Both: currency value validation. Open question whether to use ISO
  4217 codes (USD, EUR, JPY) or numeric (840, 978, 392). Codebase
  doesn't have prior art; recommend ISO 4217 alpha (more readable;
  used by Stripe API).

- Storage: monetary values across currencies need careful summation.
  Adding 100 EUR + 100 USD is meaningless; existing reporting code
  (services/accounting/reports.go) sums amount_cents across charges
  globally. That code becomes incorrect as soon as multi-currency
  is real, even if it doesn't break compilation. Worth flagging.

### Drift noticed

- arch-ddd/bounded-contexts/payments.md says "USD-only is intentional
  pre-MVP". This consultation reveals MVP is post-shipped (multi-currency
  is now wanted). arch-ddd should be updated to reflect the architectural
  decision being made here.
- contracts/payments.proto has 3 deprecated RPCs marked but no
  documented "deprecation policy" elsewhere; the codebase's deprecation
  practice is implicit. Worth documenting somewhere (CONTRIBUTING?
  arch-ddd? a contracts/README.md?) so future Direction-B-style changes
  follow consistent rules.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 816 \
  --advice-file /tmp/advice-issue-816.md
```

## What this case demonstrates

- **Surfaced the breaking nature**: didn't silently accept "change the type"; named it as breaking and showed why
- **Proposed non-breaking alternative**: not just "say no"; offered Direction B with concrete steps
- **Followed codebase's existing pattern**: deprecation pattern is already used; recommended Direction B fits
- **Multi-step scope**: Direction B has a "now" PR + a "later" cleanup PR; called both out
- **Adjacent-concern surfacing**: reporting code (cross-currency sums) becomes wrong even without compilation breaking; called this out
- **Cross-domain implications**: currency code format (ISO 4217 alpha vs numeric) is a small but consequential decision; mentioned with rationale
- **Drift surfaced**: arch-ddd is stale; this PR's decision should update it

## Key lessons

1. Type changes on existing fields are always breaking. The non-breaking path is "add new field + deprecate old".
2. "Breaking + clean" vs "additive + cluttered" is a real trade-off; surface it for arch-shape rather than picking unilaterally
3. Multi-step migration paths (now PR + 90-day-later cleanup PR) are common for contract evolution; estimate both
4. Adjacent code that compiles but becomes semantically wrong (the cross-currency sum problem) is a special category of risk worth surfacing
5. Codebase patterns matter — find the existing deprecation pattern (or absence of one) and align
