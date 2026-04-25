# Case — Brainstorm Flow

The detailed flow when one or more `classify.md` gates fail. Worth treating as its own case because it crosses two arch-shape pickups (one to open consultations, another to synthesise after they return).

## Phase A — Open consultations

For each advisor you've decided to consult:

```bash
bash actions/open-consultation.sh \
  --parent-issue "$PARENT_N" \
  --advisor fe-advisor \
  --questions-file /tmp/questions-fe.md
```

The script:
1. Creates a new issue with `agent:fe-advisor`, `source:arch`, `status:ready`
2. Adds `<!-- parent: #PARENT -->` and `<!-- consultation-of: #PARENT -->`
3. Inserts your questions into the body, plus a reminder of the structured-advice schema (see below)
4. Returns the new issue number

Then, on the parent:

1. Add `<!-- deps: #consult1, #consult2, ... -->` to the parent's body via `issue-meta.sh`
2. Route parent to `status:blocked`
3. Exit

## What questions to ask

Be specific. Don't ask "how should we do X?" — ask:

- **Constraints**: "What in current FE code makes [the proposed approach] easy or hard?"
- **Conflicts**: "Does the request conflict with anything already shipped or in-flight?"
- **Risks**: "What would you flag as risky if you implemented this as currently described?"
- **Scope**: "Roughly how many files / components would change?"
- **Drift**: "Does the current arch-ddd accurately describe what's in the codebase for this surface?"

The structured-advice schema (which the advisor template enforces) ensures responses cover all of these.

## Phase B — Wait for advisors

The parent is now `status:blocked`. arch-shape doesn't poll it. The advisors:

1. Get picked up via their own poll (`agent:fe-advisor`, `agent:be-advisor`)
2. Do their analysis (no code, just structured comment)
3. Close their consultation issue with the structured response

When **all** consultations are closed, `scan-unblock.sh` notices the parent's deps are clear, removes `status:blocked`, restores `status:ready`, and the parent is queued for arch-shape again.

## Phase C — Synthesise

When arch-shape picks the parent up the second time:

1. Read each closed consultation issue's structured comment
2. Extract: existing constraints, suggested approach, conflicts, scope, risks, drift
3. **Reconcile conflicts** — if FE and BE advisors disagree, that's a signal: either you have a real cross-context tension, or one advisor missed context. Re-read both, decide.
4. **Apply drift** — if any advisor flagged drift between code and arch-ddd, update arch-ddd in this same PR before decomposing
5. Decompose using the synthesis (workflow `business.md` Phase 3 onwards)

## Anti-patterns

- **Skipping Phase B** — calling advisors and then immediately decomposing without waiting is just "you wrote some bullets to yourself". The point is independent context.
- **Treating advisor input as decisions** — advisors advise; arch-shape decides. If you adopt every word an advisor wrote, you're not synthesising.
- **Cherry-picking** — using only the FE advice that supports the decomposition you already had in mind. Read both, weigh both.

## Time bound

If a consultation hasn't been answered after 2 hours (arbitrary; adjust per team), arch-judgment can be invoked manually to either chase the advisor or proceed without that input. Don't let one stalled consultation block a parent for days.

## Dialogue, not interview

If after reading advisor responses you have a follow-up question, you can:

- Reopen the consultation issue with a follow-up question
- Or open a fresh consultation referencing the previous one

Don't pretend you understood what you didn't.
