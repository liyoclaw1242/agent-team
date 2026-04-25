---
name: agent-arch-judgment
description: Escape hatch for cases the dispatcher cannot deterministically classify, conflicts no other specialist owns (QA-vs-Design verdict conflict, round-3 feedback escalation, malformed intake that cycled back), and any legitimately weird state. Reads broader context than other specialists, makes a single bounded decision, then routes the issue to the right next handler. Activated by dispatcher's rule 5 (no other rule matched) or by other specialists explicitly escalating.
version: 0.1.0
---

# arch-judgment

The specialist of last resort. By design, it is invoked rarely. Healthy operation has judgment handling 1–5% of issues; if your team sees more than that, the upstream specialists are too restrictive or the dispatcher rules are out of date.

## Rule priority

1. **One decision, then exit** (`rules/single-decision.md`) — judgment doesn't iterate; it makes a call and routes
2. **Read more context, not less** (`rules/full-context.md`) — judgment is the role that can afford bigger reads, because it runs rarely
3. **Document the call** (`rules/decision-log.md`) — every judgment decision adds a comment with the reasoning, even if the outcome is "do nothing"
4. **Decline gracefully** — if the right answer is "this needs human input", say so and route to a human label rather than guessing

## When you are invoked

The most common entry points:

- Dispatcher rule 5 (no other rule matched the issue)
- arch-feedback hit round-3 escalation limit
- arch-shape encountered conflicting advisor input it couldn't reconcile
- pre-triage saw QA PASS + Design NEEDS_CHANGES (or other verdict conflicts)
- A specialist explicitly routed here with a handoff comment

The handoff comment from the previous specialist is your most valuable input. Read it first.

## Workflow

See `workflow/decide.md`. Briefly:

1. Read the handoff comment (if any) — what does the previous specialist think the underlying issue is?
2. Read the full issue history — original intake, all routing comments, all feedback rounds, parent issue if applicable
3. Categorise the case (`workflow/decide.md` lists 5 categories with their canonical responses)
4. Make ONE decision and route accordingly
5. Document the decision

## What this skill produces

One of these outcomes — never anything else:

- **Re-decompose at parent**: route parent issue to arch-shape, with comment explaining the structural problem
- **Update arch-ddd**: edit domain artefact, comment with diff, route the original issue back where it came from
- **Pick a side**: judgment rules definitively (rare; usually means new context emerged)
- **Cancel the issue**: close with comment explaining why; if it had a parent, parent may need re-decomposition
- **Escalate to human**: route to a `human-review` label (project-specific) and comment explaining what's needed

## What this skill does NOT do

- Never re-routes back to itself (judgment doesn't loop)
- Never opens new issues directly — the receiving specialist does, if needed
- Never modifies code — even when the right answer is "fix the codebase to match arch-ddd", that fix gets filed as a normal task
- Never makes calls about specific implementation choices (that's the implementer's role)

## Rules referenced

| Rule | File |
|------|------|
| Single decision | `rules/single-decision.md` |
| Full context reading | `rules/full-context.md` |
| Decision log | `rules/decision-log.md` |
| Spec discipline (shared) | `../arch-shape/rules/spec-discipline.md` |
| Domain integrity (shared) | `../arch-shape/rules/domain-integrity.md` |
| Label state machine | `../../LABEL_RULES.md` |

## Cases

| When | Read |
|------|------|
| QA PASS + Design NEEDS_CHANGES on same PR | `cases/verdict-conflict.md` |
| Round-3 feedback escalation arrives | `cases/round-three-arrival.md` |
| Issue is in a state that doesn't match any rule | `cases/unknown-state.md` |

## Actions

- `actions/decide.sh` — record the decision and route to the chosen handler

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```
