# Case — Visual Review (APPROVED)

Mode B worked example. Scenario: fe submitted a PR for the Cancel Subscription form spec from `cases/pencil-spec-form.md`. design reviews the PR.

## The PR

```
PR #420 — feat(billing): cancel subscription form
Refs: #311

Implements the cancellation form per the design spec.
Includes step 1 (reason + date), step 2 (confirm), and the success state.
Tested at 320px, 768px, 1280px.
```

Linked issue: #311 (the one with the design spec).

## Phase 1 — Read

Required reads:
- `#311` issue body — extract design-spec block between markers
- PR #420 body
- PR #420 diff (focus on `src/billing/CancelForm.tsx` and `src/billing/CancelForm.module.css`)
- PR's deployed preview (Vercel preview URL in PR description)

QA test plan: not yet present (this is design's review; QA will follow).

## Phase 2 — Reality check

- The PR implements the spec'd 2-step form
- All AC referenced in the spec appear addressed in the diff
- No scope creep noticed

## Phase 3 — Inspect against foundations + spec

### Layer 1: Foundation compliance

`validate/token-usage.sh` ran; output:

```
src/billing/CancelForm.module.css: clean
src/billing/CancelForm.tsx: clean (uses Tailwind tokens throughout)
```

No hardcoded values found. All spacing on scale (`gap-3`, `gap-6`, `p-8`, etc.). All colors via tokens (`bg-secondary`, `text-primary`, `bg-brand-500`, etc.).

### Layer 2: Spec adherence

Walking through the spec sections:

#### Visual spec verification

- Container: 480px max-width ✓
- Heading: text-2xl, weight 500 ✓
- Step indicator: above heading, "Step N of 2" format ✓
- Reason field (radio + optional textarea): ✓ correct
  - Radio diameter 16px ✓
  - "Other" reveals textarea ✓
  - Vertical gap between options space-3 ✓
- Effective date field: ✓ correct
- Confirmation summary block: bg-tertiary, padding space-4, radius-md ✓
- Warning text: text-warning-700 ✓
- Action area: justified end, space-3 between buttons ✓
- Step 2: Cancel subscription button uses bg-danger-500 ✓
- Default focus on step 2 is "Back" button ✓ (verified in code: `tabIndex={0}` and rendered first in tab order)

#### Interaction spec verification

- Step navigation: 200ms ease-out cross-fade ✓
- Validation runs before step transition ✓
- Back navigation preserves form state ✓ (controlled component with useState)
- Cancellation submit: loading state on button ✓
- Reason field "Other" reveals textarea with fade ✓ — duration looks right (200ms)
- Keyboard arrow keys cycle radios ✓ (using @headlessui/react RadioGroup)

#### Accessibility verification

- `<fieldset>` + `<legend>` for radio groups ✓
- Required asterisks with aria-label="required" ✓
- Error messages with role="alert" and aria-describedby ✓
- aria-busy on submit button when loading ✓
- aria-live="polite" on outcome container ✓

### Layer 3: Accessibility verification

`validate/contrast.sh` ran:

```
text-primary on bg-secondary: 12.1:1 (PASS AA, PASS AAA)
text-secondary on bg-secondary: 7.8:1 (PASS AA, PASS AAA)
text-warning-700 on bg-secondary: 4.9:1 (PASS AA)
bg-danger-500 button text contrast: 4.8:1 (PASS AA)
brand-500 radio fill on bg-secondary: 4.2:1 (PASS AA UI)
```

All pass. No critical issues.

Touch target check (manual verification of preview):
- Radio rows: 44px tall ✓ (full row clickable)
- Buttons: 40px tall + space-4 padding-x = 56px effective width ✓
- Mobile (320px): same ✓

## Phase 4 — Compile findings

Findings discovered:

1. **[Minor]** Loading spinner color
   - Spec said: spinner color matches button text color (`currentColor`)
   - Actual: spinner uses explicit `text-white` class
   - Minor because: visually identical for the button's text-on-bg-danger-500 styling; just less robust if button styling changes

2. **[Minor]** Strength indicator on password field
   - Wait — this PR is for Cancel form, not signup. No password strength indicator applies. Skip.

That's it. One Minor.

## Phase 5 — Decide verdict

- 0 Critical findings
- 0 Major findings
- 1 Minor finding (cosmetic; could be a follow-up)

→ **APPROVED**

## Phase 6 — Compose verdict

```markdown
## Design Verdict: APPROVED

Spec adherence is consistent across visual, interaction, and accessibility dimensions.
All foundations applied correctly. One minor refinement worth addressing as follow-up.

### Findings

- **[Minor]** Loading spinner uses `text-white` class instead of `currentColor`
  - Location: src/billing/CancelForm.tsx:124
  - Impact: works visually for current bg-danger-500 button; would need updating if button styling changes
  - Reference: spec says "spinner color matches button text"
  - Suggested fix: `<Spinner className="text-current" />` or remove the explicit class

### What's needed

Nothing blocking. The minor finding can be a follow-up PR or addressed in the next iteration.

triage: none
Reviewed-on: 7c3a91b
```

## Phase 7 — Post

```bash
bash actions/post-verdict.sh \
  --issue 311 \
  --pr 420 \
  --verdict-file /tmp/verdict-311.md
```

post-verdict.sh validates the format:
- First line is `## Design Verdict: APPROVED` ✓
- `triage: none` (consistent with APPROVED) ✓
- `Reviewed-on:` SHA present ✓

Posts to PR #420 as a top-level comment. Routes #311 to `agent:arch`.

## Phase 8 — pre-triage handles next

`scripts/pre-triage.sh` on its next pass:
- Reads PR #420 comments
- Finds `## Design Verdict: APPROVED`
- Looks for QA verdict — not present yet
- Decision: design approved but waits for QA before merge
- Issue #311 stays at agent:arch awaiting QA

When QA later posts `## QA Verdict: PASS` triage:none, pre-triage merges PR #420 and closes #311.

## Phase 9 — Self-test

```markdown
# Self-test record — issue #311 (design visual-review)

## Acceptance criteria
- [x] AC #1: review against spec — all sections checked
- [x] AC #2: verdict posted with strict format — post-verdict.sh accepted
- [x] AC #3: triage field set correctly — triage: none (APPROVED)

## Foundations consulted
- color.md (contrast verification)
- space-and-rhythm.md (gap and padding checks)
- patterns/forms.md (form pattern adherence)

## Verdict reference
PR comment: https://github.com/owner/repo/pull/420#issuecomment-{ID}
Verdict: APPROVED (1 Minor finding)
SHA reviewed: 7c3a91b

## Validators
- token-usage: clean
- contrast: clean (all pairs PASS AA)

## Ready for review: yes
```

## Phase 10 — Deliver

```bash
bash actions/deliver.sh \
  --issue 311 \
  --self-test /tmp/self-test-issue-311.md \
  --route-to arch
```

Routes back to arch; pre-triage handles further routing based on combined verdicts.

## What this case demonstrates

- **Clean PR doesn't mean superficial review**: walked through visual / interaction / a11y systematically; verified specific contrast ratios; ran validators
- **Minor findings are still findings**: a small spinner color issue is logged even when APPROVING. It becomes a follow-up.
- **APPROVED with `triage: none`**: pre-triage doesn't route anywhere because nothing needs follow-up
- **Verdict format is mechanical**: post-verdict.sh validates the format; agent doesn't have to remember the format perfectly because the validator catches deviations
- **No conflict with QA**: design is one of two verdict-emitters; pre-triage waits for both before merging
