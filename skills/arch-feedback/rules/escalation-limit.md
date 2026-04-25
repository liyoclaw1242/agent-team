# Rule — Escalation Limit

A single child issue may go through arch-feedback at most twice. The third pushback round automatically escalates to arch-judgment.

## How to count rounds

The `<!-- feedback-rounds: N -->` marker on the child issue body. Defaults to 0 if absent.

- Round 0 → first time at arch-feedback. After handling, increment to 1.
- Round 1 → second time. After handling, increment to 2.
- Round 2 → third time. **Don't handle. Escalate immediately.**

## Why this rule exists

A pushback ping-pong is a signal that the issue is structurally wrong, not that the participants are stubborn. Examples of structural wrongness:

- The spec asks for an outcome that's genuinely impossible given current architecture, but neither side recognised that — keep iterating and you keep producing variants of the same impossible spec
- There's a hidden disagreement about what success means, masked as technical debate
- The bounded context is mid-evolution and the spec doesn't fit either the old or new model

Round-3 escalation forces a fresh pair of eyes (arch-judgment) and breaks the loop.

## What arch-judgment does on round 3

It treats the issue as a "stuck case" — reads the full feedback history, decides one of:

- Re-decompose the parent (route to arch-shape with a comment explaining the structural issue)
- Update arch-ddd to remove the constraint causing the loop
- Cancel the child issue entirely with rationale (the parent will need re-decomposition)
- Pick a side and rule definitively (rare; usually means there was a missing piece of context)

Whatever it decides, the child issue's `<!-- feedback-rounds: -->` resets to 0.

## What if the implementer keeps pushing back at arch-judgment?

That's a different problem (judgment vs implementer disagreement). The judgment skill has its own resolution; see `arch-judgment/SKILL.md`.

## Tuning the limit

Two rounds is a starting point. Adjust based on observation:

- If round-3 escalations are rare and resolve cleanly at round 2, the limit is fine
- If round-3 escalations are frequent and arch-judgment usually agrees with one of the existing rounds (no new info), the limit may be too generous — drop to one round
- If escalations always reveal genuinely new structural issues, the limit may be too tight — raise to three

This is a metric-driven setting; don't tune from intuition.

## Implementation

```bash
# Read current count
rounds=$(REPO=$REPO bash _shared/actions/issue-meta.sh get $N feedback-rounds 2>/dev/null || echo 0)

# Check limit
if [[ "$rounds" -ge 2 ]]; then
  bash route.sh $N arch-judgment \
    --reason "feedback round limit ($rounds rounds completed)"
  exit 0
fi

# Otherwise handle and increment
new_rounds=$((rounds + 1))
REPO=$REPO bash _shared/actions/issue-meta.sh set $N feedback-rounds $new_rounds
```

The accept-feedback.sh and counter-feedback.sh actions handle this increment automatically.
