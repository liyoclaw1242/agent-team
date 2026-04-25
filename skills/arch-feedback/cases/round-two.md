# Case — Round Two

The implementer pushes back on a spec that already had one round of feedback handling. This is the last round before mandatory escalation.

## Why round two is special

Round one is normal disagreement about details. Round two means:

- The first acceptance didn't fix what the implementer was concerned about (you addressed the wrong thing)
- The first counter didn't convince them (your rationale didn't land)
- New information has surfaced that wasn't visible round one

Whichever it is, the conversation is no longer just "tweak the spec". You should be looking for the structural issue.

## Phase 1 — Diff round one to round two

Read both rounds carefully. Specifically compare:

- What did round-one feedback ask for?
- What did you (or prior arch-feedback invocation) do?
- What is round-two feedback asking for?

If round-two is asking for the same thing as round-one in different words → you didn't actually accept the substance, just the surface
If round-two is asking for something genuinely new → some context emerged that arch needs to absorb
If round-two contradicts round-one → the implementer changed their mind, or two implementers disagree (different agent_id between rounds)

## Phase 2 — Be more cautious about counter

In round one, default-accept tilts heavily toward acceptance. In round two, **default-accept still applies but the burden of staying with the spec is even higher**.

Counter at round two only when you have evidence stronger than round one's. "Same reason as before" is not stronger.

If you accept round two and the implementer is still unhappy at round three, escalation is mandatory anyway — so accepting now is cheap.

## Phase 3 — Watch for the structural smells

Common indicators that the issue is structural, not a spec tweak:

### Smell 1: bounded context drift

Round-one feedback mentioned that the surface "doesn't quite fit" the bounded context. You accepted by tweaking the spec. Round two: the implementer says it still doesn't fit.

This is bounded-context drift. The honest answer is: the parent decomposition put the work in the wrong context. **Escalate to arch-judgment to re-decompose the parent.**

### Smell 2: missing information

Round-one feedback was about behaviour A. You accepted. Round two: now they're flagging behaviour B that conflicts with the same spec.

If A and B are both valid concerns, the spec is missing information that's only knowable by reading more code than arch-shape did. **Accept again, but flag in your comment that further pushback should escalate**.

### Smell 3: outcome conflict

Round-one was about how to do X. Round-two reveals the implementer thinks the spec actually wants Y, not X.

Outcome confusion is parent-level. **Escalate to arch-judgment.**

## Phase 4 — Decide

If you can confidently address round-two with a spec edit, do so. Same accept flow as round one.

If you suspect any of the structural smells: route to arch-judgment with a clear handoff comment that includes:
- Round-one summary (what was asked / what you did)
- Round-two summary (what's still wrong)
- Your hypothesis about which structural smell applies

This handoff comment is what makes arch-judgment effective. Without it, judgment has to reconstruct the history from scratch.

## Example handoff to judgment

```markdown
## arch-feedback: escalating to judgment after round 2

**Round 1 (resolved by arch-feedback)**:
- BE flagged that `BillingCycle.computeEnd` was renamed.
- I accepted, updated spec to "compute effective date using subscription's plan's cycle end".

**Round 2 (current)**:
- BE now reports that "subscription's current plan" is ambiguous when a
  user has both an active and a pending plan during plan-change windows.
- The spec still doesn't disambiguate.

**My hypothesis**: this is *Smell 2 — missing information*. The parent's
business request didn't account for plan-change windows. arch-shape may
need to re-shape with explicit "during a plan change, cancellation aligns
to the new plan's cycle end" or similar.

`<!-- feedback-rounds: 2 -->`

Routing to arch-judgment.
```

This kind of handoff lets judgment make a good decision in one read.

## Anti-pattern: "let me try one more time"

The escalation limit is a hard rule. Round two is the last round. If you find yourself wanting to attempt round three because "I can see the answer this time", that's exactly the failure mode the rule prevents — your overconfidence is what created the loop. Escalate.
