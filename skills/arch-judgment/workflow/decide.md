# Workflow — Decide

Single-pass decision. No iteration, no consultation. Read enough context to make a confident call, make the call, route, exit.

## Phase 1 — Read handoff (if present)

If the previous specialist routed here with a handoff comment, that comment is the most condensed signal of "what's wrong". Read it first. It typically contains:

- What round / state preceded this (e.g., "round 2 of feedback")
- The previous specialist's hypothesis about the structural problem
- Specific evidence (file:line, glossary entry, PR number)

If no handoff comment exists (e.g., dispatcher rule 5 with no specialist context), proceed to Phase 2 with no priors.

## Phase 2 — Read full context

Required:

1. The current issue's full body
2. All comments on the issue, in order
3. The parent issue (if `<!-- parent: -->` marker exists) — its body and comments
4. `arch-ddd/` files relevant to the bounded context in play

Optional (read if Phase 1 hints at them):

5. Sibling child issues if the conflict involves them
6. PR linked to the issue if there's a verdict conflict
7. Specific ADRs if the issue references one
8. Other recent feedback rounds across the project (for pattern detection)

This is the role where reading-more is encouraged. You're invoked rarely; spend the tokens.

## Phase 3 — Categorise

The case is one of these five. Identify which:

### Category A — Verdict conflict

Symptoms:
- PR has both QA PASS and Design NEEDS_CHANGES (or other contradictory verdicts)
- pre-triage routed here per its decision tree

Canonical action: Design wins for visual/UX issues, QA wins for functional issues. Re-route to the implementer of the surface in question (FE for design issues, BE for functional issues, etc.).

If it's genuinely ambiguous (the QA failure is a UX issue framed as functional, or vice versa), pick one based on which has the more concrete evidence. Don't pretend the conflict can be resolved by accommodating both.

See `cases/verdict-conflict.md` for examples.

### Category B — Round 3 feedback

Symptoms:
- Issue has `<!-- feedback-rounds: 2 -->` (or higher)
- Specialist explicitly escalated from arch-feedback

Canonical action: identify the structural smell from `arch-feedback/cases/round-two.md`:

- **Bounded context drift** → re-decompose at parent (route parent issue to arch-shape)
- **Missing information** → accept the latest pushback definitively, edit spec, route back, reset round counter
- **Outcome conflict** → re-decompose at parent

Reset `<!-- feedback-rounds: 0 -->` after action so future cycles count fresh.

See `cases/round-three-arrival.md`.

### Category C — Malformed input that cycled

Symptoms:
- Issue keeps coming back to dispatcher rule 5 because intake is missing required markers
- Or: issue has been passed between specialists multiple times because each thinks it's the wrong fit

Canonical action: route to the original source (`source:hermes` → escalate to human review; `source:human` → comment asking for revision and route to a `human-review` label).

Don't try to interpret malformed intake yourself. The originator needs to fix it.

See `cases/unknown-state.md`.

### Category D — arch-ddd inconsistency

Symptoms:
- The conflict reveals that arch-ddd doesn't accurately describe the codebase
- Multiple advisors / specialists have flagged "drift noticed" without anyone updating

Canonical action: update arch-ddd in this PR (you're allowed to write to arch-ddd; you're an arch-family specialist). Then route the original issue back to whoever was working on it, noting the artefact has been updated.

This is the only category where judgment makes a content change.

### Category E — Genuinely weird state

Symptoms:
- The issue's labels / markers / state don't fit any known pattern
- The issue's been routed in a way none of the specialist rules permit
- A previous run of automation went wrong

Canonical action: this is a system bug. File a follow-up issue describing the problem and route the offending issue to `human-review`. Don't try to repair automation logic by patching individual issues.

## Phase 4 — Decide and route

Use `actions/decide.sh`:

```bash
bash actions/decide.sh \
  --issue $N \
  --category {A|B|C|D|E} \
  --route-to {target} \
  --reason "..." \
  [--reset-rounds]
```

The action:
- Posts a structured decision-log comment
- Routes the issue (via route.sh) to the target
- Optionally resets `feedback-rounds` for category B

## Phase 5 — Exit

Don't iterate. Don't re-poll the same issue. If your decision was wrong, the issue will surface again later via a different path — and at that point, fresh context will help. Trying to "fix it now" tends to produce worse decisions.

## Anti-patterns

- **Convening a discussion** — judgment doesn't open consultation issues. If you need advisor input, you're in the wrong specialist; route to arch-shape instead.
- **Splitting the difference** — verdict conflicts deserve a winner. Pretending both can be satisfied with a compromise spec usually means neither will be.
- **Indefinitely deferring to human** — escalating *everything* to human is also a failure mode. Categories A–D should resolve without human; only E does.
- **Re-shaping yourself** — that's arch-shape's job. You route to arch-shape; you don't decompose.
