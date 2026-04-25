# Case — Verify a Feature PR

The most common QA verify-mode invocation. An implementer (FE / BE / OPS) opened a PR; QA verifies AC are met.

## Worked example

You're picked up on issue #146 (post-impl verify), parent #142, PR #501 by FE. The shift-left plan from #145 is in #145's body.

## Phase 1 — Read

```bash
# Verify task body
gh issue view 146

# Parent for AC
gh issue view 142

# Sibling shift-left QA — the test plan
gh issue view 145

# The PR
gh pr view 501

# The PR's checks
gh pr checks 501

# The PR's diff (focus on what changed)
gh pr diff 501 | head -200

# Implementer's self-test record (often in PR body)
gh pr view 501 --json body --jq '.body' | grep -A 100 "Self-test"
```

What you observe:
- PR is in CI: 4 checks pass, 1 a11y check warning (minor)
- PR diff: ~150 lines added, focused on cancellation flow
- Self-test record claims all 6 FE AC verified; cites specific test names matching the shift-left plan
- Branch is up to date with main

## Phase 2 — Run validators

```bash
gh pr checkout 501
bash skills/fe/validate/check-all.sh skills/fe/
```

All 4 validators pass on PR HEAD. Good.

## Phase 3 — Walk the AC

Each AC from parent #142 (or sibling #144 specifically since #501 is the FE PR):

### AC #1: Cancel button visible on subscription card

Check:
- Visit /billing on the PR's preview deployment
- Look for the cancel button on a paid subscription card
- Observed: visible, correctly styled per Design spec

Test:
```bash
# Check the named test from the plan exists and passes
grep -r "TestCancelButton_Renders_OnPaidSubscription" tests/
# Found in tests/CancelButton.test.tsx; CI shows it passing
```

✓

### AC #2: Cancel button hidden for free plans

Check:
- Switch test user to a free plan in staging
- Visit /billing
- Observed: cancel button not rendered

Test: `TestCancelButton_Hidden_OnFreePlan` — exists, passes.

✓

### AC #3: Click opens confirmation modal

Check:
- Clicked the button on staging
- Modal opened, focused, displayed effective date

Test: `TestCancelModal_Opens_OnButtonClick` — exists, passes.

✓

### AC #4: Modal shows effective date from API

Check:
- Modal displayed "Will end on: March 15, 2026"
- Verified the API call (network tab): GET request returned `effectiveDate: 2026-03-15T23:59:59Z`
- Display format matches Design spec

Test: `TestCancelModal_DisplaysEffectiveDate` — exists, passes.

✓

### AC #5: Loading state during request

Check:
- Throttled network in devtools (Slow 3G)
- Clicked confirm
- Observed: button disabled, spinner visible, ~3s of loading state, then transitioned

Test: `TestCancelModal_LoadingState` — exists, passes.

✓

### AC #6: ESC dismisses without action

Check:
- Opened modal
- Pressed ESC
- Observed: modal closes, no API call made (verified network tab)
- Subscription state unchanged in DB

Test: `TestCancelModal_ESC_DismissesWithoutAction` — exists, passes.

✓

## Phase 4 — Compose verdict

All 6 AC verified. Compose `/tmp/verdict-146.md`:

```markdown
## QA Verdict: PASS

- AC #1: Cancel button visible on paid subscription card — ✓
  Evidence: TestCancelButton_Renders_OnPaidSubscription passes; observed on PR preview deploy
- AC #2: Cancel button hidden for free plans — ✓
  Evidence: TestCancelButton_Hidden_OnFreePlan passes; switched test user to free plan, button absent
- AC #3: Click opens confirmation modal — ✓
  Evidence: TestCancelModal_Opens_OnButtonClick passes; modal observed with focus management
- AC #4: Modal displays effective date from API — ✓
  Evidence: TestCancelModal_DisplaysEffectiveDate passes; API returned effectiveDate, modal showed "Will end on: March 15, 2026"
- AC #5: Loading state during request — ✓
  Evidence: TestCancelModal_LoadingState passes; observed on Slow 3G throttle, button + spinner during request
- AC #6: ESC dismisses without action — ✓
  Evidence: TestCancelModal_ESC_DismissesWithoutAction passes; ESC closed modal, no network call

triage: none

Verified-on: abc1234

Notes:
- a11y check has one warning about heading hierarchy (h2 at top of modal); acceptable but worth a follow-up if more complex modals come.
- Performance: ~180ms for the API call on staging; well within target.
```

## Phase 5 — Post

```bash
bash actions/post-verdict.sh \
  --issue 146 \
  --pr 501 \
  --verdict-file /tmp/verdict-146.md
```

The action:
- Validates verdict format (passes)
- Posts comment on PR #501
- Posts summary on issue #146
- Routes #146 → status:done (PASS)

The PR is now ready for merge per pre-triage.sh's logic.

## Phase 6 — Self-test

```markdown
# Self-test record — issue #146

## Acceptance criteria for this QA task
- [x] Validators ran on PR HEAD (commit abc1234)
  - Verified: bash skills/fe/validate/check-all.sh — all pass
- [x] Walked all 6 AC from parent #142 / sibling #144
  - Verified: 6 AC, all marked ✓ in verdict
- [x] Manual verification on staging
  - Verified: full happy path including AC #1-#6
- [x] Verdict format check
  - Verified: post-verdict.sh accepted; comment posted on PR #501

## Verdict
PASS — comment URL: ...

## Ready for review: yes
```

## Anti-patterns

- **Skipping manual verification because tests pass** — automated tests catch most things; manual catches the rest. Both layers needed.
- **Skipping AC items in verdict** — every AC must appear, even if obvious
- **Glossing over the a11y warning** — minor warnings still appear in `Notes:`. Don't bury issues that future readers may care about.
- **Verifying against the wrong commit** — if the PR has new pushes mid-verification, your verdict is stale. Re-checkout and re-verify on the latest, OR document `Verified-on:` clearly so reviewers know.

## Variant: PR doesn't pass on first verification

If during walk you found one AC failing:

- The verdict becomes FAIL
- The failing AC's evidence section explains specifically what's wrong
- `triage:` field names the role responsible for the fix

You don't need to verify remaining AC after finding a fail (the PR will need re-work and re-verify anyway). But it's polite to walk all AC if it's quick — finding multiple issues in one verdict round is more efficient than discovering them serially.

## Variant: PR claims to fix multiple issues

If the PR's body has `Refs: #142, #200`, it's addressing multiple issues. Each issue's QA verdict comment is separate (don't bundle).

If you're only assigned to verify #146 (related to #142), don't let scope creep into #200's AC. The QA for #200 is a different task or invocation.
