# Case — Implementer suggests a different approach

The implementer doesn't argue the spec is wrong, but proposes a different way to achieve the same outcome.

## Example

Original task #144 spec:

```markdown
[FE] Cancellation confirmation modal

## Acceptance criteria
- Modal shown when user clicks Cancel button
- Modal includes: "Are you sure?" text, current effective date, Cancel + Keep buttons
- On confirm: API call, success toast, parent refresh
- On dismiss: nothing happens
```

Feedback from FE:

```markdown
## Technical Feedback from fe-agent

Proposing an alternative: instead of a modal, use an inline expansion
on the subscription card. Modal pattern is heavier; we already have
inline expansion for the upgrade flow on the same page.

Trade-offs:
- (+) Consistent with upgrade UX
- (+) Lighter weight, no z-index issues
- (-) Less prominent (modal forces attention)
- (-) Easier to dismiss accidentally

Happy to go either way; flagging that the spec's modal choice may not
be the best UX given context.
```

## Decision

This is **a UX call, not a technical infeasibility**. arch-feedback should not be deciding UX patterns. Two options:

### Option A: route to design-advisor for input

If we have a design-advisor available, this is the time:

```bash
bash open-consultation.sh \
  --parent-issue $PARENT_N \
  --advisor design-advisor \
  --questions-file /tmp/q.md
```

Where the questions file says: "FE proposes inline expansion vs the spec's modal. From a design perspective, which is better for this confirmation flow?"

While waiting, route the child to status:blocked.

### Option B: counter and let the implementer follow spec

If design-advisor isn't available or we want to keep moving:

```markdown
## arch-feedback: stick with spec for now

Both patterns are valid. The spec specified modal because cancellation
is destructive enough to warrant interrupting the user (similar to how
delete confirmations are typically modal). Inline expansion makes
sense for upgrade because upgrade is a "do you want to do this?"
question, not a "are you sure?" question.

If you have strong UX evidence for the inline pattern (user research,
accessibility argument), file a follow-up issue and we can revisit.
For this task, please proceed with the modal as spec'd.

`<!-- feedback-rounds: 1 -->`

Routing back to fe-agent.
```

## Default

Lean toward Option A (consult) when:
- The implementer's alternative is well-reasoned
- design-advisor is responsive
- The parent isn't blocked on this child

Lean toward Option B (counter) when:
- The implementer's alternative is a quick suggestion, not deeply considered
- Time pressure
- The spec's choice has documented rationale (read parent / arch-ddd; if you find none, that's a flag — accept and update)

## Anti-pattern: "implementer suggests, arch agrees, both move on"

If you accept based on implementer's preference alone (without consulting the relevant role's advisor), you've effectively let one role's preference override the original arch-shape decision. Sometimes that's right, sometimes not — but doing it without triangulation is risky.

The exception: if the implementer is the design-affected role themselves and arch-ddd doesn't speak to this, accepting their UX call is fine. (e.g., FE deciding UX of a UI primarily for FE-tooling internal users.)
