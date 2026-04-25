# Workflow — Classify (brainstorm gates)

The first step on any issue. Three gates decide whether to take the **quick path** (decompose now) or the **brainstorm path** (consult advisors first).

The gates exist because brainstorming is expensive — it ties up FE/BE advisor agents for minutes per consultation. Cheap requests should not pay this cost.

## Gate 1 — Domain clarity

> Is the bounded context this request touches already documented in `arch-ddd/`?

**Pass** if:
- The request mentions entities or flows that appear in `arch-ddd/glossary.md`
- The bounded context they belong to has a doc under `arch-ddd/bounded-contexts/`

**Fail** if:
- The request introduces new entities not in the glossary
- The request crosses a context boundary that's not documented
- The bounded contexts in question have outdated docs (stale by >3 months and codebase has evolved meaningfully)

## Gate 2 — Scope specificity

> Can you state the desired outcome in one sentence with measurable acceptance criteria?

**Pass** if:
- A single sentence captures what success looks like
- You can list 3-7 acceptance criteria from the request alone
- The request avoids ambiguous quantifiers ("better", "faster", "more flexible") without numeric targets

**Fail** if:
- The request is exploratory ("we should think about X")
- Multiple plausible interpretations exist
- The success criterion is vague ("user is happy")

## Gate 3 — Cross-context impact

> Does this request stay within one bounded context?

**Pass** if:
- All affected code paths live in one bounded context
- No cross-context invariants need negotiation

**Fail** if:
- Two or more bounded contexts must change together
- A new external integration is introduced
- An existing context's public API changes

## Decision matrix

| Gate 1 | Gate 2 | Gate 3 | Path |
|--------|--------|--------|------|
| Pass | Pass | Pass | **Quick path** — decompose now |
| Any fail | * | * | **Brainstorm path** — consult advisors |
| Pass | Pass | Fail | **Brainstorm path** — cross-context warrants advisor input |

Only the all-pass case skips brainstorm. This is intentional: cross-context decisions made without advisor input tend to surface as Mode C pushback later.

## What "Brainstorm path" means

1. Open a `fe-advisor` consultation issue with the questions you have
2. Open a `be-advisor` consultation issue with the questions you have
3. Optionally open `ops-advisor` if infrastructure is in scope
4. Mark all consultations as deps on the parent
5. Route parent to `status:blocked`
6. Exit. `scan-unblock.sh` will return the parent to ready when consultations close.
7. On the next pickup, you read the advisors' responses and proceed to decompose

The advisor consultation has its own structured response schema — see `cases/brainstorm-flow.md`.

## What "Quick path" means

1. Read the relevant `arch-ddd/bounded-contexts/{ctx}.md` and any referenced domain stories
2. Decompose into atomic tasks (`workflow/business.md` or `workflow/architecture.md`)
3. Open child issues via `actions/open-child.sh`
4. Update `arch-ddd/` if the request introduced any new term that's not yet documented
5. Deliver via `actions/deliver.sh`

## Anti-patterns (do not do)

- **"It's probably fine, let me skip Gate 1."** No. Gate failure is cheap (minutes); shipping the wrong decomposition is expensive (rework cycles).
- **"I'll consult one advisor to be safe."** Brainstorm is all-or-nothing. Either you have enough info to decompose, or you open the full set of relevant consultations.
- **"Hermes was vague but I'll fill in the blanks myself."** That's the failure mode this gate prevents. Push back with a comment, route to `agent:human` for clarification.
