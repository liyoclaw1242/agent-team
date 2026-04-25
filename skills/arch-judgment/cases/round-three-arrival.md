# Case — Round 3 Feedback Escalation Arrives

arch-feedback hit its 2-round limit and escalated. Issue arrives at judgment with `<!-- feedback-rounds: 2 -->` and a handoff comment from arch-feedback.

## Phase 1 — Read everything

Per `rules/full-context.md`, read:

- The handoff comment (most condensed signal)
- The issue body and all comments — original spec, round 1 feedback, round 1 resolution, round 2 feedback, round 2 resolution
- The parent issue
- Sibling child issues if the feedback mentions them
- The arch-ddd files for the bounded context

## Phase 2 — Identify the structural smell

`arch-feedback/cases/round-two.md` lists three smells. Match the case:

### Smell 1: bounded context drift

If both rounds of feedback have been about "this doesn't quite fit here":

```markdown
## arch-judgment: decision

**Category**: B (round-3 escalation, structural smell: bounded context drift)

**Read context**: Issue body, 2 feedback rounds, parent #142, arch-ddd/bounded-contexts/billing.md.

**Hypothesis**: This child task asks FE to reach into the Subscription
bounded context to read fields that Billing context owns. Both feedback
rounds danced around this without anyone naming it. The right fix is to
re-decompose the parent so the cross-context call goes through the
documented event interface, not direct field access.

**Action taken**: routing parent #142 back to arch-shape for re-decomposition. Closing this child as superseded; arch-shape will produce the new task structure.

**Routing**: parent #142 → agent:arch with reason "round-3 feedback revealed bounded-context drift; needs re-decomposition"

**Open questions**: arch-ddd may need an entry showing the legitimate
inter-context interface for this read. Flagging for arch-shape.
```

### Smell 2: missing information

If round 1 fixed one concern but round 2 revealed another that the spec didn't account for:

```markdown
## arch-judgment: decision

**Category**: B (round-3 escalation, structural smell: missing information)

**Hypothesis**: The original spec didn't account for plan-change windows,
which is when both an active and pending plan exist for a subscription.
Round 1 feedback fixed a method-rename issue. Round 2 surfaced the
plan-change ambiguity. The implementer needs an explicit rule for this
case.

**Action taken**: editing the issue spec to add explicit handling
("during a plan-change window, cancellation aligns to the new plan's
cycle end"). Resetting feedback-rounds to 0 since the spec now reflects
the missing info. Routing back to BE.

**Routing**: this issue → agent:be with reason "spec updated for plan-change window; feedback-rounds reset"

**Reset rounds**: yes
```

### Smell 3: outcome conflict

If round 2 reveals the implementer thinks the spec wants the wrong outcome:

```markdown
## arch-judgment: decision

**Category**: B (round-3 escalation, structural smell: outcome conflict)

**Hypothesis**: BE believes the spec asks for "cancel takes effect at
cycle end" but the parent issue (Hermes business request) said "users
can cancel and stop being billed immediately". These are different
outcomes. The decomposition didn't translate Hermes's intent correctly.

**Action taken**: routing parent #142 to arch-shape for re-decomposition,
with explicit note that Hermes's "stop being billed immediately" needs
clarification — does that mean prorated refund, or cancel-and-no-refund,
or cancel-at-cycle-end-with-refund-of-unused-time? arch-shape should
push back to Hermes for clarification before re-decomposing.

**Routing**: parent #142 → agent:arch with reason "round-3 escalation; outcome ambiguity in original Hermes request"
```

## Phase 3 — Don't try to "save" the child issue

A common temptation is to look at round 1 and round 2 and try to find a third spec wording that satisfies both rounds' concerns. Resist this. If two carefully-considered rounds didn't converge, a third tweak from judgment is unlikely to.

The right escalation moves are upstream (re-decompose, fix arch-ddd, push back to Hermes), not lateral (rewrite the same spec one more time).

## Phase 4 — Round counter

After your decision, reset `<!-- feedback-rounds: 0 -->` on the affected issue (whether you kept the issue or closed it). This prevents future cycles from inheriting the previous count.

If you closed the issue (because parent re-decomposes), the counter doesn't matter — the new children won't have it.

## Anti-pattern: judgment-spec-rewrite

Don't write a long, comprehensive spec yourself trying to anticipate every concern. Spec writing is arch-shape's role; doing it here means:
- arch-shape doesn't update its mental model
- The over-specified spec triggers more pushback (see arch-shape's Spec Discipline rule)
- You created a precedent that judgment writes specs

Judgment routes; arch-shape specs.
