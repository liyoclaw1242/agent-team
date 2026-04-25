# Case — Reproducible Bug with Obvious Code Path

The cleanest case. Repro works, stack trace points at a specific function, root cause becomes clear quickly.

## Example

Bug report:

```markdown
[Bug] Checkout page crashes when payment method has no expiration date

## Reproduction
1. Log in as test user with payment method ID 99
2. Go to /checkout with any plan in cart
3. Observe blank page; console shows: "TypeError: Cannot read properties of undefined (reading 'getMonth')"

## Frequency: 100%
```

## Phase 1 reading

The repro is clear, severity is Sev 2, console error names the failing operation. Investigation should be quick.

## Phase 2 reproduction

```bash
# Logged in as the test user, navigated to /checkout, confirmed the error.
# Stack trace from devtools points at:
#   src/checkout/PaymentSummary.tsx:88
#   src/lib/dateFormat.ts:23
```

## Phase 3 hypothesis

`dateFormat.ts:23` calls `.getMonth()` on a date object. Hypothesis: payment method 99 has a null `expirationDate` field, and the format function doesn't guard against it.

## Phase 4 hypothesis test

Read `dateFormat.ts:23`:

```javascript
export function formatExpiry(date: Date): string {
  return `${date.getMonth() + 1}/${date.getFullYear() % 100}`;
}
```

Confirmed: signature says `Date`, but TypeScript can't enforce non-null at runtime. Reading `PaymentSummary.tsx:88`:

```jsx
<span>{formatExpiry(paymentMethod.expirationDate)}</span>
```

Where `paymentMethod.expirationDate` is typed `Date | null` (verified by reading the type definition). The component doesn't guard.

Querying the database: payment method 99 indeed has `expiration_date: null`.

**Root cause confirmed**: `PaymentSummary.tsx` passes `paymentMethod.expirationDate` directly to `formatExpiry` without checking for null, and `formatExpiry` calls `.getMonth()` on the value, which fails when null.

## Phase 5 root-cause report

```markdown
## Root cause report (debug)

### Reproduction
1. Log in as user with a payment method that has `expiration_date: null` (test user has PM #99)
2. Visit /checkout
3. Page goes blank, console: "TypeError: Cannot read properties of undefined (reading 'getMonth')"
Reproduces 100% of the time.

### Hypothesis confirmed
`PaymentSummary.tsx:88` passes a possibly-null `Date` to `formatExpiry`, which calls `.getMonth()` without null-checking.

### Evidence
- `src/lib/dateFormat.ts:23` — `formatExpiry` signature is `(date: Date) => string` but body uses `date.getMonth()` directly with no null check
- `src/checkout/PaymentSummary.tsx:88` — `formatExpiry(paymentMethod.expirationDate)` with `expirationDate` typed `Date | null`
- DB row for PM 99: `expiration_date: NULL` confirmed via `psql -c "SELECT expiration_date FROM payment_methods WHERE id = 99"`

### Why this happens
Some payment methods (legacy data) have null expiration dates. The component renders all payment methods uniformly; when expiration is null, the format function crashes the whole page render.

### Suggested owning role
fe

### Suggested approach (high-level)
- Display "—" or "No expiry" when expiration is null
- Either guard at the call site (PaymentSummary) or at the function (formatExpiry); team should pick the more idiomatic spot
- Consider whether other places that format dates have the same vulnerability

### Severity confirmation
Sev 2 (page-blocking, no workaround for affected users). Original report was Sev 2, confirmed.
```

## Phase 6 file fix

```bash
bash actions/file-fix.sh \
  --bug-issue $BUG_N \
  --owning-role fe \
  --severity 2 \
  --report-file /tmp/root-cause-report.md
```

Resulting fix issue body:

```markdown
[FE] Fix: handle null expiration date in payment method display

## Bug
This fixes #BUG_N — checkout crashes for users with legacy payment
methods that lack expiration dates.

## Acceptance criteria
- [ ] /checkout no longer crashes when a payment method has expiration_date = null
- [ ] Null expiration is displayed as "—" or "No expiry" (FE picks consistent text)
- [ ] Repro from the bug report is verified to pass
- [ ] Regression test added covering this path

## Root cause
See full report on #BUG_N. TL;DR: PaymentSummary passes possibly-null
expiration to formatExpiry which doesn't guard.

## Severity: 2

<!-- bug-of: #BUG_N -->
<!-- parent: #BUG_N -->
<!-- severity: 2 -->
```

## Phase 7 verify state

```bash
# Bug issue should now have:
# - The root-cause report comment
# - <!-- fix: #FIX_N --> marker
# - status:blocked with deps on fix issue

# Fix issue should have:
# - source:arch label (debug is arch-family)
# - agent:fe label
# - status:ready
# - bug-of marker pointing to bug issue
```

When the FE PR for the fix merges, `scan-complete-requests.sh` (or a dedicated bug-closer if implemented) closes both issues.
