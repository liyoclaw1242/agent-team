# Workflow — Handle Pushback

## Phase 1 — Read history

Required reads:

1. The child issue's full body (current spec)
2. All comments on the child issue, in order
3. The `Technical Feedback from {role}` block — usually most recent comment
4. The parent issue body (so you understand the broader context the spec lives in)
5. `<!-- feedback-rounds: N -->` marker if present (defaults to 0 if absent)

Optional, when relevant:
6. `arch-ddd/bounded-contexts/{ctx}.md` for the affected surface
7. Sibling child issues if the feedback alleges a conflict with sibling work

## Phase 2 — Check escalation count

Read `<!-- feedback-rounds: N -->`. If N ≥ 2, this is round 3 or later. Escalate to arch-judgment immediately, regardless of feedback content. See `rules/escalation-limit.md` for why.

```bash
bash route.sh $CHILD_N arch-judgment \
  --reason "feedback round limit reached (was round $((N+1)))"
```

Exit. Don't try to resolve directly.

## Phase 3 — Categorise

Read the feedback block. Classify into one of these categories:

### A. "Spec conflicts with existing code"

The implementer cites file:line evidence that the spec assumes something untrue. Examples:

- "The spec says use `useStripeAction`, but that hook was removed last sprint"
- "The spec assumes the `Cancellation` model has a `pending_at` field, but it doesn't"
- "The spec says reuse `BillingForm`, but `BillingForm` is closed for Capabilities and refuses unknown props"

**Default action: accept.** The implementer is closer to the code. Update the spec.

### B. "Spec is missing acceptance criteria"

The implementer says they don't know how to know they're done.

- "The spec says 'handle errors gracefully' but doesn't say which errors or how"
- "The spec lists 5 features but no AC for them"

**Default action: accept.** Specifying AC is your job, not theirs. Add them.

### C. "Spec is too prescriptive"

The implementer says the spec dictates implementation choices.

- "Spec says use React Query but our codebase uses SWR; can I use SWR?"
- "Spec specifies a 300ms debounce; our standard is 150ms — should I deviate?"

**Default action: accept.** Soften the spec to outcome-only language. See `arch-shape/rules/spec-discipline.md`.

### D. "Spec asks for the wrong outcome"

The implementer challenges what success looks like.

- "Spec says cancellation takes effect immediately, but billing logic requires it to align with cycle end"
- "Spec says all admin actions log to Datadog, but we use New Relic"

**Default action: escalate to arch-shape.** The outcome itself is contested; that's parent-level concern, not child-level.

```bash
bash route.sh $CHILD_N arch-judgment \
  --reason "outcome challenged; needs re-shape at parent #$PARENT_N"
```

### E. "Spec is fine, implementer is overcomplicating"

The implementer's feedback reveals they want to do something more elaborate than the spec asks for.

- "I want to refactor the auth module while I'm in there"
- "Should I add metrics to all the new code paths?"

**Default action: counter.** Politely but firmly. Stick to the spec; if extra work is warranted, file a separate issue.

## Phase 4 — Act

### If accepting:

1. Compose the spec update — minimum diff to address the feedback
2. Edit the issue body to incorporate the change
3. Update or add the `<!-- feedback-rounds: -->` marker
4. Post a comment explaining what changed and why
5. Route back to the original implementer

```bash
bash actions/accept-feedback.sh \
  --issue $CHILD_N \
  --new-body-file /tmp/updated-spec.md \
  --back-to fe \
  --change-summary "Removed prescription of React Query; spec now requires only that the request is non-blocking"
```

### If countering:

1. Compose the counter explanation — what you considered, why the original spec stands
2. Post the comment on the issue
3. Update `<!-- feedback-rounds: -->`
4. Route back to the original implementer

```bash
bash actions/counter-feedback.sh \
  --issue $CHILD_N \
  --back-to fe \
  --rationale-file /tmp/counter.md
```

## Phase 5 — Self-test

Before exiting, verify:

- [ ] `<!-- feedback-rounds: N -->` is now > previous value (or 1 if first round)
- [ ] Issue is back at the original implementer (`agent:fe` etc., not `agent:arch`)
- [ ] If you accepted: a comment exists explaining what changed
- [ ] If you countered: a comment exists explaining why
- [ ] Domain artefacts updated if the accept changed any glossary-bearing concepts

If any check fails: don't leave the issue in inconsistent state. Either fix or route to arch-judgment.

## Anti-patterns

- **Defending decomposition reflexively** — pushback is signal, not insult. Default accept is default for a reason.
- **Rewriting the entire spec** — minimum diff. Address the specific concern; don't take the opportunity to re-shape.
- **Accepting silently** — the implementer needs to know what changed. Always comment.
- **Ignoring round counter** — the limit exists to prevent doom loops. Respect it.
