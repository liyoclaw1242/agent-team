# Rule — Feedback Discipline

Same shape as FE's `feedback-discipline.md`. BE-specific patterns:

## When to write feedback

Write feedback when, after Phase 1 reading, **you cannot proceed faithfully** without arch's input. BE-specific triggers:

- Schema conflict / migration impossibility
- Service chain drift
- Bounded context violation
- Contract conflict (between this task and a sibling FE / consumer expectation)
- Code conflict (function / library / pattern referenced in spec doesn't exist)
- Missing AC / over-prescription / wrong outcome (same as FE)

Don't write feedback for:

- "I'd prefer a different approach" with no conflict — implement to spec
- "The spec is harder than I thought" — that's not feedback, that's work
- "I don't like how this codebase is structured" — taste isn't feedback

## Strong feedback vs weak feedback

Same as FE. Strong feedback cites evidence (file:line, schema, mermaid line). Weak is vague. Make it strong.

## One concern per feedback

Same as FE. Don't bundle. Pick the most blocking concern; mention others briefly.

## Tone

Same as FE. Neutral, professional, concrete.

## BE-specific traps

### Trap: writing feedback as a code review

You may notice things that are wrong with adjacent code while reading. Resist the urge to enumerate them in feedback.

Feedback is about THIS task's spec vs reality. Adjacent issues are "out of scope, separate intake".

If you observed something genuinely critical (security bug, data corruption risk), file a separate `intake-kind:bug` issue rather than including it in feedback.

### Trap: presenting yourself as the source of truth

```
WRONG:
> The spec says X, but I think it should say Y. Y is what we should do.

BETTER:
> The spec says X. The codebase shows Y (cite). Two options to reconcile:
> 1. Update spec to say Y
> 2. Update codebase to match spec X
> My preference: option 1, because Y is the established pattern.
```

The first framing positions arch-shape as wrong and you as the corrector. The second framing presents the conflict and lets arch-feedback decide. The second produces better outcomes — both because it's more accurate (arch may have context you don't) and because it preserves arch's role.

### Trap: feedback that's really a design preference

You think the spec's API shape is awkward; you'd prefer a different shape. The spec isn't wrong, it just isn't your favourite.

This is not feedback. Implement the spec; if your concern is real, raise it as a design discussion separately.

The exception: if your design concern translates to a concrete consequence (poor performance, hard-to-test, security gap), that IS feedback because you've identified an objective problem. State it that way:

```
NOT feedback:
> The spec's shape feels awkward; I prefer X instead.

FEEDBACK:
> The spec's shape requires N+1 query in the hot path. Specifically, it
> returns subscription IDs that the client then fetches details for. We
> can include subscription details in the response with no extra cost.
```

The second one is feedback because it has a measurable consequence.

## Round limit awareness

Same as FE. 2 rounds, then automatic escalation to arch-judgment. Don't try to win round 3.

## Anti-patterns (BE-specific)

- **Writing feedback that re-shapes the spec for arch** — your job is to flag, not to redesign. Suggesting options is fine; rewriting the spec is not.
- **Mode C as a refactor backdoor** — "while the spec is unclear, let me refactor this entire module". Refactor is a separate intake.
- **Feedback as time-stalling** — "the spec is unclear, let me think on it". If you have specific evidence, post; if not, you're not ready to feedback yet.
