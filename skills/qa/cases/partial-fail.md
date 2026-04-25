# Case — Partial Fail

A PR addresses some AC but leaves others incomplete. Common when an implementer ran out of time or made a triage decision that conflicts with QA's view of "done".

The verdict is FAIL — the spec wasn't met. The art is making the FAIL useful so the next iteration is efficient.

## Worked example

PR #501 by FE addresses sibling task #144 (cancellation modal). On verification, you find:

- AC #1, #2, #3, #4 ✓ (button visible, hidden for free plans, modal opens, effective date displays)
- AC #5 ✗ (loading state during request — the button never enters disabled state; double-click results in two API calls)
- AC #6 ✓ (ESC dismisses)

5 of 6 ACs pass. AC #5 has a clear gap.

## Why this is FAIL, not "PASS with minor concern"

There's no "PASS with concerns" — see `rules/verdict-format.md`. PASS means all AC are met. One missed AC = FAIL.

This isn't pedantic. The AC list is the team's commitment of what shipping means. Letting one slide because "the rest works" creates a slippery slope.

## Phase 1 — Walk every AC, even after first FAIL

Once you know the verdict will be FAIL (after AC #5), you might be tempted to stop. Don't.

Walking the rest gives the implementer the full picture:
- "5 of 6 work; here's the one that doesn't" is much more efficient than "I'll keep finding issues each round"
- You may discover other issues that change the triage or scope
- The implementer can fix all gaps in the next push, not iterate one-at-a-time

## Phase 2 — Compose verdict with detail on the failing AC

```markdown
## QA Verdict: FAIL

- AC #1: Cancel button visible on paid subscription card — ✓
  Evidence: TestCancelButton_Renders_OnPaidSubscription passes; observed in preview deploy
- AC #2: Cancel button hidden for free plans — ✓
  Evidence: TestCancelButton_Hidden_OnFreePlan passes; verified manually
- AC #3: Click opens confirmation modal — ✓
  Evidence: TestCancelModal_Opens_OnButtonClick passes
- AC #4: Modal displays effective date — ✓
  Evidence: TestCancelModal_DisplaysEffectiveDate passes
- AC #5: Loading state during request — ✗
  FAIL: The "Yes, cancel" button does not enter disabled state during the API call.
  Reproduction:
  - On staging preview, opened cancellation modal
  - Network tab shows: clicked button rapidly twice (within ~50ms)
  - Two POST requests fired to /billing/subscriptions/.../cancel
  - First returned 200, second returned 409
  - Visually: button remained enabled the entire time; no spinner observed
  Expected per AC + spec: button disabled, spinner visible during request, click ignored
  if pressed again.
  Test: TestCancelModal_LoadingState — does not exist in this PR. Implementer's
  self-test claims to have verified AC #5 manually but the actual implementation
  doesn't have the loading state.
- AC #6: ESC dismisses without action — ✓
  Evidence: TestCancelModal_ESC_DismissesWithoutAction passes; verified manually

triage: fe

Verified-on: abc1234

Notes:
- The other 5 AC are solid. AC #5 looks like an oversight; the click handler
  doesn't have local pending state at all. Suggested approach (FE's call): add
  `pending` state to the modal, set true on click, conditionally disable button
  + show spinner.
- Worth adding TestCancelModal_LoadingState (named in shift-left plan #145).
```

## Phase 3 — Post and route

```bash
bash actions/post-verdict.sh \
  --issue $ISSUE_N \
  --pr 501 \
  --verdict-file /tmp/verdict-{N}.md
```

Posts on PR, routes the QA issue. `pre-triage.sh` reads the verdict, sees FAIL + `triage: fe`, routes the issue (or a follow-up triage task) to FE for the gap.

## What happens next

FE picks up the issue, reads the verdict's specific finding for AC #5. They:
- Add the pending state
- Add the missing test
- Push to the same PR (or open a new commit; either is fine)
- The PR automatically transitions back to a state needing re-verification

When QA picks it up again (round 2), they walk all AC again on the new HEAD. If all pass, PASS. If new findings, FAIL again with new findings.

## Variant: most AC fail

If the PR is genuinely unfinished (e.g., 4 of 6 AC fail), the verdict still walks all and lists each. But also consider whether this PR should have been opened at all:

```markdown
## QA Verdict: FAIL

- AC #1: ... — ✗ (not implemented)
- AC #2: ... — ✗ (not implemented)
- AC #3: ... — ✓
- AC #4: ... — ✗ (not implemented)
- AC #5: ... — ✗ (not implemented)
- AC #6: ... — ✓

triage: fe

Notes:
- Only 2 of 6 AC are addressed. The PR description says "first pass; will iterate"
  but that's not how the deliver gate works — PRs should pass the implementer's
  self-test gate before opening, and the gate refuses if AC are unchecked.
- Suggesting the implementer close this PR and reopen when more AC are addressed.
```

The "the PR shouldn't have been opened" observation is appropriate in Notes when self-test was clearly bypassed. It's a process-level concern that's worth surfacing.

## Variant: AC walking reveals AC #5 was actually wrong

You're walking AC and notice AC #5 ("loading state during request") doesn't actually make sense for this surface — maybe the action is genuinely instantaneous and a spinner would be misleading.

If you genuinely think the AC itself is wrong, that's not a FAIL territory — that's Mode C feedback to arch-shape:

```markdown
## Technical Feedback from qa

### Concern category
ac-incorrect

### What the AC says
"Loading state during request"

### What I observe
The cancellation API call returns in ~50ms on staging. A loading state would
flash and disappear so quickly it's worse UX than no loading state. The
implementer chose not to add it; in retrospect this is the right call.

### Options
1. Drop AC #5; document the rationale
2. Replace with: "If the request takes >300ms, show a loading state"
3. Keep AC #5; require the implementer to add the loading state

### My preference
Option 2. Conditional loading is the right pattern.
```

This routes via Mode C; the AC may get amended; QA picks up again later.

But — be careful with this exit. It's only correct if AC really is flawed. If AC is sound and you're rationalising on behalf of the implementer, that's enabling a FAIL to slide as PASS. When in doubt, FAIL with detail; let the implementer respond.

## Anti-patterns

- **PASS with concerns** — there's no such state. Either the AC is met or it isn't.
- **Stopping AC walk after first FAIL** — wastes round-trips
- **Vague FAIL evidence** ("AC #5 is broken") — useless to the implementer; they'll bounce it back asking for specifics
- **Suggesting fixes inline** ("you should add a useState here") — stay outcome-level. Notes can mention approach but shouldn't prescribe code.
- **Letting a missing AC slide because "it'll be fixed in a follow-up"** — follow-ups never happen consistently. FAIL it; if a follow-up is genuinely the right scope, that's an arch-shape decision, not a QA decision.
