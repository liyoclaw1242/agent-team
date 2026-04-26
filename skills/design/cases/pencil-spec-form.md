# Case — Pencil Spec for a Form

Mode A worked example. Scenario: arch-shape filed an issue for a "Cancel subscription" form. The user enters cancellation reason + date and confirms. design needs to author the spec.

## The issue (paraphrased)

```markdown
## Goal
User can cancel their subscription with a reason and effective date.

## Acceptance criteria
- [ ] AC #1: form has a reason field (select from preset options + free text)
- [ ] AC #2: form has effective date selector (immediately or end-of-period)
- [ ] AC #3: form has a confirmation step before cancellation finalizes
- [ ] AC #4: form is accessible (WCAG AA)

<!-- intake-kind: business -->
<!-- parent: #310 -->
```

## Phase 1 — Read

Foundations consulted before drafting:

- `aesthetic-direction.md` — project direction is "refined utilitarian"; restrained color, generous spacing
- `typography.md` — type scale Major Third; weights 400 / 500 / 700
- `color.md` — neutrals + brand-blue + danger-red palettes defined
- `space-and-rhythm.md` — 4px-based scale
- `patterns/forms.md` — form anatomy, validation, accessibility

Existing patterns:

- `/apps/billing/forms/UpdatePayment` — closest existing form pattern; uses 16px field gap, 40px field height, top-aligned labels
- No existing "destructive multi-step confirmation" pattern in this product

Decision: extend existing form pattern (consistency with billing area); design new confirmation pattern (no existing one to reuse) but make it minimal so it doesn't introduce a major new pattern.

## Phase 2 — Reality check

- All AC achievable
- Existing tokens cover what's needed
- a11y requirements clear (WCAG AA explicitly stated)
- One ambiguity: "confirmation step" — is it inline within the form or a modal? Spec needs to decide.

Decision: inline confirmation step (becomes step 2 of the form). Why: modal-on-modal feels heavy; the confirmation is part of the cancellation flow, not a side action.

## Phase 3 — Draft the spec

The spec covers a 2-step form: Step 1 (reason + date) → Step 2 (confirm).

```markdown
<!-- design-spec-begin -->

## Visual spec

### Container

- Wrap: `bg-secondary` background, `radius-lg` corners, `space-8` padding
- Max width: 480px (centered in viewport)
- Step indicator at top: "Step N of 2"

### Step indicator

- Type: text-sm (14px), weight 500
- Color: text-secondary
- Position: above form heading; space-2 gap below

### Heading

- Type: text-2xl (29px), weight 500
- Color: text-primary
- Position: top of form content; space-6 gap below

### Step 1: Reason and date

#### Reason field
- Label: "Why are you cancelling?" — text-sm (14px), weight 500, text-primary
- Field type: radio group + optional text area
- Options: 
  - "Too expensive"
  - "Not using it enough"
  - "Found an alternative"
  - "Other (please specify)" — selecting reveals text area
- Radio styling: 16px diameter; brand-500 fill when selected
- Text area (when "Other" selected): 80px tall, full width, space-4 padding inside
- Required indicator: asterisk after label, danger-500 color
- Vertical gap between options: space-3 (12px)

#### Effective date field
- Label: "When should this take effect?" — same as reason label
- Field type: radio group
- Options:
  - "Immediately" — plus subtitle "(refund prorated)"
  - "End of current billing period" — plus subtitle "(your access continues until {date})"
- The subtitle is text-xs (12px), weight 400, text-secondary

#### Layout
- Vertical stack of fields
- Gap between fields: space-6 (24px)

### Step 2: Confirmation

#### Summary block
- Background: bg-tertiary
- Padding: space-4
- Radius: radius-md
- Content: 
  - "You're about to cancel" (text-base, weight 500, text-primary)
  - Bullet list:
    - Reason: {selected reason}
    - Effective: {selected date description}
- Bullet list: text-sm, weight 400, text-secondary

#### Warning text
- Type: text-sm, weight 400, text-warning-700
- Content: "This action can't be undone after the effective date."
- Margin-top: space-4 from summary

### Action area

- Position: bottom of form; space-8 gap above
- Layout: horizontal, justified end (right)
- Gap between buttons: space-3

#### Step 1 buttons
- "Cancel" button: secondary style; text-base; height 40px; padding-x space-4
- "Continue" button: primary style; same dimensions
- "Continue" disabled until reason and date are selected

#### Step 2 buttons
- "Back" button: secondary style
- "Cancel subscription" button: danger style (bg-danger-500, text-on-danger)
- Default focus: "Back" (the safe option)

### States

#### Default
As specified above.

#### Focus (any field)
- Ring: 2px, brand-500, offset 2px from element edge
- No layout shift (ring is outline, not border)

#### Error (validation, e.g., "Other" selected without text)
- Field border: 1px danger-500
- Error message below field: text-sm, weight 400, danger-700
- Icon: alert-circle (16px) before message; danger-500

#### Loading (after Cancel subscription clicked)
- "Cancel subscription" button: text replaced with spinner (16px, currentColor)
- Both buttons disabled
- Form fields disabled

#### Success (after cancellation processes)
- Replaces form with success state:
  - Checkmark icon (48px, success-500)
  - Heading: "Subscription cancelled"
  - Body text: "Effective {date}. We've sent confirmation to {email}."
  - Single button: "Done" — primary style; closes the flow

#### Error (cancellation API fails)
- Replaces form action area with:
  - Error message: text-sm, danger-700, with alert-triangle icon
  - "We couldn't process your cancellation. Please try again or contact support."
  - Buttons: "Try again" (primary) + "Contact support" (secondary)

## Interaction spec

### Step navigation

- Trigger: "Continue" button click (or Enter key in step 1)
- Validation: reason required; if "Other", text area required (≥3 chars); date required
- On valid: transition to step 2
- Transition: 200ms ease-out cross-fade
- Focus on step 2: heading element (`tabindex="-1"`, focused programmatically)

### Going back

- Trigger: "Back" button click (or Escape key)
- Form state preserved (returning to step 1 shows the user's earlier input intact)
- Focus on step 1: heading element

### Cancellation submit

- Trigger: "Cancel subscription" button click (or Enter while button is focused)
- Confirmation NOT shown again (step 2 is the confirmation; clicking the button confirms)
- API call fires; loading state shown
- On success: success state replaces form; focus moves to success heading (`tabindex="-1"`)
- On API failure: error state replaces action area; focus moves to error message

### Reason field

- Radio click: selects radio, deselects others
- "Other" selection: reveals text area with 200ms fade-in
- "Other" deselection: hides text area; clears its content
- Text area accepts up to 500 chars; counter visible at 400+

### Effective date field

- Radio click: selects radio, deselects other
- Subtitle below selected radio updates if {date} would change

### Keyboard

- Tab order: reason fieldset (radios + textarea if shown) → date fieldset → action buttons
- Arrow keys within radio group: cycle through options
- Enter in form: triggers primary button (Continue or Cancel subscription)
- Escape: triggers secondary button (Cancel or Back)

### Focus management summary

| Trigger | Focus moves to |
|---------|----------------|
| Form opens (step 1) | First radio in reason fieldset |
| Step 1 → Step 2 | Step 2 heading |
| Step 2 → Step 1 | Step 1 heading |
| Submit success | Success heading |
| Submit error | Error message |

## Accessibility spec

### Semantic HTML
- Form wrapped in `<form>` element
- Each radio group wrapped in `<fieldset>` with `<legend>` (the question)
- Required fields marked with `required` attribute and visible asterisk (with `aria-label="required"` on the asterisk)
- "Other" text area has its own `<label>`

### ARIA
- Step indicator uses `aria-label="Step 1 of 2"` on the indicator element
- Error messages associated via `aria-describedby` and `role="alert"`
- Loading state: button gets `aria-busy="true"` while submitting
- Success / error states: container has `aria-live="polite"` so changes are announced

### Contrast
- text-primary on bg-secondary: required ≥4.5:1; passes (verified: 12.1:1)
- text-secondary on bg-secondary: required ≥4.5:1; passes (verified: 7.8:1)
- text-warning-700 on bg-secondary: required ≥4.5:1; passes (verified: 4.9:1)
- bg-brand-500 (radio fill) on bg-secondary: UI component contrast ≥3:1; passes (verified: 4.2:1)
- bg-danger-500 (button) text on button: text contrast ≥4.5:1; passes (verified: 4.8:1)

### Touch targets
- Radio button labels (full row clickable): minimum 44px tall via padding
- Buttons: 40px tall + 16px horizontal padding ensures 44x44 effective target
- Mobile: same; touch ratio confirmed

### Reduced motion
- Cross-fade between steps: instant when `prefers-reduced-motion: reduce`
- "Other" text area reveal: instant when reduced motion
- Loading spinner: continues to animate (necessary feedback) but reduced rotation speed

### Screen reader announcements
- On step transition: heading change is announced by screen reader following focus
- On submit success: aria-live region announces "Subscription cancelled"
- On submit error: aria-live region announces error text

<!-- design-spec-end -->
```

## Phase 4 — Publish + self-test

```bash
bash actions/publish-spec.sh \
  --issue 311 \
  --spec-file /tmp/spec-311.md
```

Self-test record at `/tmp/self-test-issue-311.md`:

```markdown
# Self-test record — issue #311 (design pencil-spec)

## Acceptance criteria
- [x] AC #1: reason field with preset + free text — Step 1, reason fieldset
- [x] AC #2: effective date selector — Step 1, date fieldset
- [x] AC #3: confirmation step — Step 2, summary + warning
- [x] AC #4: WCAG AA accessibility — verified contrast ratios; ARIA / focus / keyboard documented

## Spec sections present
- [x] Visual spec
- [x] Interaction spec
- [x] Accessibility spec

## Foundations consulted
- aesthetic-direction.md (refined utilitarian — restrained tone matches cancellation context)
- typography.md (Major Third scale, weights 400/500/700)
- color.md (contrast verification)
- space-and-rhythm.md (4px scale)
- patterns/forms.md (form anatomy, validation patterns)
- patterns/feedback-states.md (success / error states)

## Existing patterns referenced
- /apps/billing/forms/UpdatePayment (field gap, label position, button styling)

## Validators
- spec-completeness: pass

## Ready for review: yes
```

## Phase 5 — Deliver

```bash
bash actions/deliver.sh \
  --issue 311 \
  --self-test /tmp/self-test-issue-311.md \
  --route-to arch
```

Routes to arch; arch dispatcher tags `agent:fe + status:ready` for fe to implement.

## What this case demonstrates

- **Foundations come first**: every spacing / type / color decision references the foundation
- **Existing patterns extended**: form pattern from billing area; new confirmation step is minimal
- **Three sections complete**: visual / interaction / accessibility all substantively populated
- **States enumerated**: default / focus / error / loading / success / error — not skipped
- **Tone respects user context**: cancellation isn't celebratory; the warning text and danger color signal weight
- **Accessibility computed, not asserted**: contrast ratios cited; ARIA mapped to behaviour
