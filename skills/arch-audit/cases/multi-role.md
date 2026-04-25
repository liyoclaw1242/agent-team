# Case — Findings span multiple roles

A QA audit of an end-to-end flow finds problems on both FE and BE sides. Each finding belongs to one role; arch-audit produces multiple fix tasks across roles.

## Example

```markdown
## Audit scope
End-to-end test of subscription upgrade flow, both shipped and dev branches.

## Findings

1. **[Sev 2]** Upgrade endpoint returns 500 when current plan is null
   - Location: src/handlers/billing/upgrade.go:47
   - Expected: 400 with reason "missing current plan"

2. **[Sev 3]** Upgrade UI doesn't show error message when 500 is returned
   - Location: src/pages/billing/Upgrade.tsx:122
   - Expected: error toast with message from response

3. **[Sev 2]** Upgrade endpoint allows downgrade when plan_id <= current
   - Location: src/handlers/billing/upgrade.go:80
   - Expected: 422 with reason "cannot downgrade via this endpoint"

4. **[Sev 3]** Pricing display rounds incorrectly when plan price has fractional cents
   - Location: src/components/PricingDisplay.tsx:33
   - Expected: half-cent rounded up consistently

## Pattern observed
1 and 2 are causally linked (BE bug + FE not displaying). 3 is independent
BE bug. 4 is independent FE bug.
```

## Decomposition

Four fixes, three of which are obvious. The interesting one is finding 1:

### Decision: do 1 and 2 become one fix or two?

**Two fixes**, with deps:
- BE fix for finding 1 (validate input, return 400 not 500)
- FE fix for finding 2 (display error from response)

Why not one fix?
- Different roles
- The FE fix is genuinely useful even if BE keeps returning 500 (display whatever error comes back)
- Splitting allows the FE fix to ship even if BE work is delayed

Deps?
- The FE fix depends on the BE fix returning a sensible error message format. So:

```markdown
[FE] Show server error in upgrade error toast

<!-- deps: #401 -->
```

The FE fix waits for BE's contract to be finalised. (If FE wants to start in parallel, they can — they just won't know the exact error shape until BE merges. Often this is fine.)

### Decision: 3 and 4 are independent

3 is BE, 4 is FE. No relationship. Two separate fix tasks.

## Result: 4 fixes from 4 findings, with 1 dep edge

```
#401  [BE] Validate current_plan in upgrade endpoint, return 400        (finding 1)
#402  [FE] Show server error in upgrade error toast (deps: #401)        (finding 2)
#403  [BE] Reject downgrade in upgrade endpoint, return 422             (finding 3)
#404  [FE] Round pricing display half-cents up consistently              (finding 4)
```

The audit closes; #401, #403, #404 go straight to `status:ready`; #402 is `status:blocked` until #401 closes.

## What we did NOT produce

- One BE fix bundling 1 + 3 — they're different concerns (input validation vs business rule)
- One mega-fix touching everything — no.

## Comparing to systemic-pattern case

Systemic pattern: many findings, one root → fewer fixes than findings.
Multi-role: findings touch multiple areas → roughly one fix per finding (with occasional consolidation when the area is the same).

The decisive question is **shared root**, not "which roles are involved."
