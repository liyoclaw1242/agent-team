# Rule — Brainstorm Gates

The decision to consult advisors is governed by three gates (`workflow/classify.md`). This rule records the **rationale** so future maintainers don't loosen the gates and gradually erode their usefulness.

## Why three gates exist

Brainstorming is expensive:
- Advisor agents take real time to read context and respond
- Each consultation is a separate issue, separate API calls, separate journal entry
- The parent stays `blocked` during the round, increasing time-to-decompose

Brainstorming is also valuable:
- Cross-context decisions made unilaterally tend to surface as Mode C pushback (FE realises BE's spec is unimplementable, etc.)
- arch-shape's view of "what the codebase can support" is shallower than the actual implementer's view
- Domain artefacts get richer when advisors explicitly call out drift

The gates strike a balance: cheap requests skip the cost; risky requests pay it.

## What "loosening" looks like (don't do)

- Skipping Gate 1 because "the glossary is mostly up to date" — this defeats the gate. Either the glossary covers it, or it doesn't.
- Calling one advisor "to be safe" instead of all relevant ones — half-brainstorm produces lopsided decompositions
- Treating Gate 3 as optional because "we know they probably won't object" — the test is whether contexts are touched, not whether advisors will agree

## What "tightening" looks like (consider)

If the team observes:
- Many advisor consultations come back as "no concerns, this is fine"
- Mode C pushback rate is low

…then the gates may be too tight. Loosen carefully:
- Document the change in a PR with metrics-based rationale
- Adjust gates one at a time and observe for a release cycle

If the team observes:
- High Mode C rate from FE on shaped tasks
- Mismatches between specs and codebase reality

…then gates are too loose, brainstorm more aggressively.

## Implementation note

The gates are implemented in arch-shape's prompt logic (workflow/classify.md), not as deterministic code. This is because gate evaluation requires reading the issue and the bounded contexts — judgment calls.

A future enhancement: extract gate evaluation into a more structured prompt with explicit pass/fail per gate. This would let metrics observe gate-failure rate and gate-pass rate separately.
