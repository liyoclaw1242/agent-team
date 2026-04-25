# Case — Alert Investigation (no human repro)

`source:alert` issues come from observability platforms via webhook. There's no human to ask "how did you trigger it"; instead you have a trace ID, stack trace, or metric anomaly.

## Example incoming bug

```markdown
[Alert] Sentry: TypeError in CheckoutHandler — 47 occurrences in 5 minutes

## Alert details
- Service: checkout-svc
- Environment: production
- First seen: 2026-04-25T14:22:18Z
- Sample trace: https://sentry.example.com/issues/12345
- Stack trace head:
    TypeError: Cannot read property 'amount' of null
      at applyDiscount (src/billing/discount.go:88)
      at CheckoutHandler.process (src/handlers/checkout.go:142)

## Affected users
~3% of checkout requests in the past 5 minutes (based on rate)

<!-- alert-id: sentry-12345 -->
```

## Phase 1 — Read intake + alert payload

```bash
# Fetch alert details from Sentry/Datadog/etc. Implementation depends on platform.
# Pseudo:
gh_api_get "$SENTRY_API/issues/12345" > /tmp/alert.json

# Extract:
# - Recent occurrences (≥3 to triangulate)
# - Common attributes across occurrences (user IDs, plan IDs, geos, browser, etc.)
# - Time correlation (deploys, traffic spikes, dependent service incidents)
```

The alert payload usually has more structure than the bug body. Look for:
- All distinct stack traces (sometimes one alert groups slightly different errors)
- The most common request attributes (often points at a specific code path or input)
- Deployment markers near the time of first occurrence

## Phase 2 — No local repro; instead, build evidence triangulation

Since you can't reproduce manually, you build confidence from multiple traces. Take 3 separate occurrences from the alert and record:

| Trace | User | Input | Stack head | Time |
|-------|------|-------|-----------|------|
| ABC | u_001 | plan_99, code:SAVE10 | discount.go:88 | T+0:01 |
| DEF | u_042 | plan_44, code:SAVE10 | discount.go:88 | T+0:03 |
| XYZ | u_123 | plan_22, code:SAVE10 | discount.go:88 | T+0:08 |

If three independent occurrences all share specific attributes, that's evidence. Here: all three used `code:SAVE10`. Hypothesis: the SAVE10 promo code triggers the bug.

## Phase 3 — Hypothesis test without local repro

Read the suspect code:

```go
// src/billing/discount.go:80–95
func applyDiscount(plan *Plan, code string) (*Plan, error) {
    promo, err := promoStore.Find(code)
    if err != nil {
        return plan, nil  // fall through if no promo
    }
    discounted := *plan
    discounted.Amount = plan.Amount - promo.Amount  // line 88
    return &discounted, nil
}
```

Inspect the SAVE10 promo record in production:

```bash
psql -c "SELECT id, code, amount FROM promos WHERE code = 'SAVE10'"
# Returns: id=7, code='SAVE10', amount=NULL
```

**Confirmed**: SAVE10 has `amount: NULL` (likely from a recent admin action). The code dereferences `promo.Amount` without checking for null.

In Go terms: `*int` field, dereferenced as if non-nil. Panics → caught and reported by the runtime hook → fires Sentry alert.

## Phase 4 — Root cause report

```markdown
## Root cause report (debug)

### Reproduction
Cannot reproduce locally without seeding a promo record with NULL amount.
Verified via production data inspection:

```sql
SELECT id, code, amount FROM promos WHERE code = 'SAVE10';
-- id=7, code='SAVE10', amount=NULL
```

Triangulated from 3 separate Sentry occurrences (traces: ABC, DEF, XYZ),
all sharing `code:SAVE10` as the input.

### Hypothesis confirmed
`applyDiscount` in `src/billing/discount.go:88` dereferences `promo.Amount`
without nil-checking. The SAVE10 promo has `amount: NULL` (set during
recent admin action), causing the dereference to panic on every checkout
that uses this code.

### Evidence
- `src/billing/discount.go:88` reads `promo.Amount` (typed `*int`) without nil check
- DB query confirms SAVE10 has NULL amount
- All 3 sampled traces share `code:SAVE10`
- Promo record was last updated 2026-04-25T14:18Z (4 minutes before first alert; matches admin audit log)

### Why this happens
The promo schema treats `amount` as nullable (legacy column for "open-ended
promos that grant other rewards"). Recent admin tooling allowed editing amount
to NULL. The discount path doesn't account for this case.

### Suggested owning role
be — primary fix in discount.go. Possibly also ops/admin if the admin tool
should have rejected NULL amount on save.

### Suggested approach (high-level)
- Treat NULL amount as "no amount discount" (fall through, no error)
- Consider whether the admin tool should reject NULL amount on save (separate concern)
- Add regression test exercising the NULL-amount path

### Severity confirmation
Sev 2 → escalate to Sev 1: 47 occurrences in 5 min, ~3% of checkout traffic,
ongoing. Recommend mitigation (disable SAVE10) while fix is in flight.

### Mitigation suggestion
File a separate OPS task to disable the SAVE10 promo immediately. This
stops the bleeding while the fix is implemented + reviewed + deployed.
```

## Phase 5 — File two issues

Two outputs:

### Output 1: the fix (BE)

```bash
bash actions/file-fix.sh \
  --bug-issue $BUG_N \
  --owning-role be \
  --severity 1 \
  --report-file /tmp/root-cause.md
```

### Output 2: mitigation (OPS) — separate from the fix

For Sev 1 alerts with ongoing impact, the right move is to file a mitigation task in parallel:

```bash
bash actions/file-fix.sh \
  --bug-issue $BUG_N \
  --owning-role ops \
  --severity 1 \
  --report-file /tmp/mitigation.md
```

Where `mitigation.md` says:

```markdown
[OPS] Mitigation: disable SAVE10 promo until fix lands

## Bug
Mitigates the live incident from #BUG_N. NOT the fix — the fix is #FIX_N.

## Acceptance criteria
- [ ] SAVE10 promo set to inactive in production within 15 minutes
- [ ] Confirm error rate on checkout-svc returns to baseline
- [ ] Note in #incident channel that mitigation is in place pending #FIX_N
```

Per `rules/iron-law.md`, mitigation is not a fix — it's stopping the bleeding while the fix is properly developed. Filing both is the right move.

## Anti-patterns

- **Acting on one trace only** — confirmation bias is high. Triangulate.
- **Skipping mitigation for Sev 1** — Iron Law says no fix without confirmed cause; it doesn't say no mitigation. Mitigation is fine and often urgent.
- **Reproducing locally with synthetic data and pretending that's the bug** — sometimes you can synthesise repro by seeding state. That's evidence, not proof. Cite the production data confirmation, not just your local seeded test.
