---
name: agent-arch-feedback
description: Handles Mode C — when an implementer (FE / BE / OPS / Design) pushes back on a spec saying it conflicts with the codebase or is technically infeasible. Reads the specialist's feedback, decides whether to accept (update spec) or counter (reject the pushback with rationale). Default is accept; counter only when the specialist's view conflicts with global concerns the implementer can't see. Activated by dispatcher when an issue has `agent:arch + status:ready` and the body contains `Technical Feedback from {role}`.
version: 0.1.0
---

# arch-feedback

The most asymmetric of the ARCH specialists: it's small in workflow but high-leverage. A handful of feedback decisions per week shape how much friction the team experiences.

## Rule priority

1. **Default to accept** (`rules/default-accept.md`) — implementer has more local context than arch-shape did at decomposition time.
2. **Pushback ping-pong limit** (`rules/escalation-limit.md`) — same issue can only round-trip 2 times before it must escalate to arch-judgment.
3. **Provenance preserved** — accepting feedback updates the original child issue rather than creating new ones; counter-decisions add a comment without changing labels.

## When you are invoked

When dispatcher routes an issue here, the body should already contain a `Technical Feedback from {role}` block. Your job is one of two outcomes:

- **Accept**: re-shape the spec based on feedback, send back to the implementer
- **Counter**: explain why the original spec stands, send back to the implementer with that explanation

You are not deciding whether the request is viable overall — that's arch-shape's job at the parent level. You are deciding whether one specific child task's spec should change in light of implementer concerns.

## Workflow

See `workflow/handle-pushback.md` for the detailed decision tree.

Briefly:

1. Read the child issue's full history (original spec, any prior feedback rounds)
2. Read the current "Technical Feedback from {role}" block — what's the concern?
3. Categorise the concern:
   - "Spec conflicts with existing code" → usually accept
   - "Spec is missing acceptance criteria" → accept, fix
   - "Spec implementation is too prescriptive" → accept, soften
   - "Spec asks for the wrong outcome" → escalate to arch-shape
   - "Spec is fine, implementer is overcomplicating" → counter
4. Check escalation count — if this is round 3+ on the same issue, escalate to arch-judgment regardless
5. Either:
   - **Accept**: update issue body with adjusted spec; route back to the original implementer
   - **Counter**: post explanatory comment; route back to the original implementer
6. Increment the round counter via `<!-- feedback-rounds: N -->`

## What this skill produces

- **Spec update + route back** — the implementer picks up the revised spec and tries again
- **Counter comment + route back** — the implementer sees the rationale and proceeds with the original spec (or pushes back again, hitting round-2)
- **Escalation to arch-judgment** — round-3 hit, or the conflict reveals something deeper

## What this skill does NOT do

- Never re-decomposes the parent — that's arch-shape's job
- Never opens new issues — feedback is always in-place edits to the existing child
- Never accepts pushback that conflicts with arch-ddd without ALSO updating arch-ddd
- Never silently rewrites spec — every change to spec body comes with a comment summarising what changed and why

## Rules referenced

| Rule | File |
|------|------|
| Default accept | `rules/default-accept.md` |
| Escalation limit | `rules/escalation-limit.md` |
| Spec discipline (shared) | `../arch-shape/rules/spec-discipline.md` |
| Domain integrity (shared) | `../arch-shape/rules/domain-integrity.md` |
| Label state machine | `../../LABEL_RULES.md` |

## Cases

| When | Read |
|------|------|
| Implementer cites file:line evidence of conflict | `cases/code-conflict.md` |
| Implementer suggests a different approach | `cases/alternative-approach.md` |
| Round 2 (specialist still unhappy after first acceptance) | `cases/round-two.md` |

## Actions

- `actions/accept-feedback.sh` — apply spec changes, route back, increment round counter
- `actions/counter-feedback.sh` — post counter comment, route back, increment round counter

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```
