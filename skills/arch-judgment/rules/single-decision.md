# Rule — Single Decision

Judgment makes one decision per invocation, then exits. It does not loop, does not iterate, does not call other specialists synchronously, does not invite back-and-forth.

## Why this rule

Judgment is the final layer. If it iterates, it becomes another participant in the loop it was supposed to break. The whole point of escape-hatch design is to be terminal — once judgment rules, the issue moves forward (even if "forward" means "back to arch-shape for re-decomposition").

## What "single decision" means in practice

- Read all the context you need
- Choose one of the five categories
- Take that category's canonical action
- Comment, route, exit

You don't:
- Make a tentative decision and wait for confirmation
- Open a consultation issue to verify your read
- Rule conditionally ("if X, do A; else do B" — pick X or not-X yourself)
- Hand off to "arch-judgment" recursively (you can't route to yourself)

## What if you're not confident?

If after Phase 2 reading you genuinely can't tell which category applies, the right move is:

> Route to a `human-review` label with a comment that lays out:
> - What you read
> - What the categories you considered were
> - Why each didn't quite fit
> - What information would resolve it

This is **not** failure. It's the appropriate use of the escape hatch's escape hatch. Some cases really do need a human, and judgment's value here is identifying that fact cleanly rather than guessing.

## What if the right answer would require you to take multiple actions?

Two examples:

**1. The issue needs both an arch-ddd update AND a re-decomposition.**

- Action 1: update arch-ddd (Category D)
- Action 2: route the original issue to arch-shape for re-decomposition (Category B's structural smell)

This is allowed: do the arch-ddd edit (it's a content change, not a routing decision), then take the routing decision (route to arch-shape). The routing is the "single decision" — the ddd edit is preparation.

**2. The issue needs the parent re-decomposed AND the children cancelled.**

- Action 1: cancel each child issue (closing comments)
- Action 2: route the parent to arch-shape

Same pattern: cleanup is preparation; the route is the decision. Make sure the cleanup is documented in the decision-log comment so reviewers see the full action.

## Anti-pattern: conditional decisions

Don't write decisions like:

> "Route to arch-shape unless the implementer responds within 24 hours, in which case proceed with the original spec."

This is not a decision; it's a tentative state. The issue ends up in limbo. Pick one path now.

If the right answer genuinely depends on something that hasn't happened yet (e.g., waiting for an external event), use the deps system (`<!-- deps: -->` marker) and route to status:blocked. But "I'm not sure yet" is not what deps are for.
