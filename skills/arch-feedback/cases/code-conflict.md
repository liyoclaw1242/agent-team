# Case — Implementer cites file:line evidence of conflict

The cleanest case of all. The implementer has done the work to point at concrete code that contradicts the spec.

## Example

Original task #143 spec:

```markdown
[BE] Cancellation endpoint with effective-date computation

## Acceptance criteria
- POST /billing/subscriptions/{id}/cancel
- Use the existing `BillingCycle.computeEnd` method to determine effective date
- Return 200 with `{effectiveDate: ISO8601}`
```

Feedback comment from BE:

```markdown
## Technical Feedback from be-agent

The spec assumes `BillingCycle.computeEnd` exists, but per
`src/billing/cycle.go:42`, that method was renamed to `EndOfPeriod` in
PR #501 (last sprint). It also no longer takes a Subscription —
it takes a `Plan` (the cycle is plan-scoped now, not subscription-scoped).

This means either:
1. I switch the spec to use `EndOfPeriod` with a Plan param, OR
2. I introduce a thin adapter that takes a Subscription and looks up its Plan

I'd prefer option 1 (no new code) but the spec said use the
named method. Routing back for clarification.
```

## Decision

**Accept.** Update spec to remove the prescribed method name, since the prescribed method no longer exists.

The new spec says "compute effective date using the cycle-end logic for the subscription's current plan" — outcome-level. The implementer can pick option 1 (call `EndOfPeriod` with the plan) without further checking.

## Updated body

```markdown
## Acceptance criteria
- POST /billing/subscriptions/{id}/cancel
- Compute effective date using the subscription's current plan's billing cycle end
- Return 200 with `{effectiveDate: ISO8601}`
```

(Spec dropped the named method; everything else unchanged.)

## Comment posted on the issue

```markdown
## arch-feedback: accepted

Updated AC #2 to remove the named `BillingCycle.computeEnd` reference
since it no longer exists (renamed to `EndOfPeriod` in PR #501).

The new wording is outcome-level: "compute effective date using the
subscription's current plan's billing cycle end". This lets you use
`EndOfPeriod(plan)` directly without further check-back.

`<!-- feedback-rounds: 1 -->`

Routing back to be-agent.
```

## What we did NOT do

- Argue that the spec was right and the implementer should figure it out
- Re-decompose the parent
- Open a new issue
- Switch to option 2 (add an adapter) — that would have been over-prescribing again

## Why this is the easy case

The implementer:
- Cited specific evidence (`src/billing/cycle.go:42`, PR #501)
- Identified concrete options
- Stated a preference with rationale

Easy to validate, easy to accept, low risk of error. Aim for this clarity in feedback templates.
