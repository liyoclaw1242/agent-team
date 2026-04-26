# Case — Pencil Spec for a Mobile Flow

Mode A worked example. Scenario: a 3-step mobile signup flow (email → verify → profile). Mobile-first; touch-optimised; multi-step state.

## The issue

```markdown
## Goal
New users sign up with email + password, verify their email, and complete a basic profile.

## Acceptance criteria
- [ ] AC #1: 3-step flow with email step, verify step, profile step
- [ ] AC #2: progress indication shows current step
- [ ] AC #3: back navigation preserves entered data
- [ ] AC #4: mobile-first (320px-768px primary; 768px+ adapts)
- [ ] AC #5: WCAG AA accessible

<!-- intake-kind: business -->
<!-- parent: #501 -->
```

## Phase 1 — Read

Foundations consulted:
- All eight (this is a comprehensive spec)
- `patterns/forms.md` — multi-step / wizard pattern
- `patterns/responsive-and-density.md` — mobile-first behavior

No existing signup pattern in this product (new feature). Decision: design from foundations + standard patterns.

## Phase 2 — Reality check

- Email verification: requires user to leave the app to check email; flow needs to handle return-to-app gracefully
- Back navigation: data preservation across steps means client-side state (or server-side draft); spec specifies behavior, fe decides implementation
- Mobile-first: 320px (smallest target), 768px+ adapts to centered narrower form

## Phase 3 — Draft

```markdown
<!-- design-spec-begin -->

## Visual spec

### Container

- Full screen on mobile (<768px)
- At 768px+: centered card, max-width 480px, vertical centered with viewport
- Background: bg-primary (full screen on mobile)
- At 768px+: container has bg-secondary, radius-lg, padding space-8

### Top bar (mobile)

- Height: 56px
- Layout: flex between
- Left: back button (chevron-left icon, 24px) — visible on steps 2, 3; not on step 1
- Center: nothing (or app logo if branded; 24px max)
- Right: nothing (or close X if dismiss is allowed)
- Border-bottom: 1px border-subtle

### Top bar (desktop, 768px+)

- Not present (the centered card has its own header below)

### Step indicator

- Position: top of content area
- Format: dots — 3 dots, horizontal, gap space-2
- Each dot: 8px diameter
  - Inactive: border-default outline only
  - Active: bg-brand-500, slightly larger (10px)
  - Completed: bg-brand-500, with checkmark glyph (4px white)
- Gap below: space-6

### Step heading

- Type: text-2xl (29px), weight 500, text-primary
- Below indicator; space-2 gap to subtitle

### Step subtitle

- Type: text-base (16px), weight 400, text-secondary
- Gap below: space-6 (before form fields)

### Step 1: Email + password

#### Email field
- Label: "Email" — text-sm (14px), weight 500
- Input: 
  - Height 48px (mobile-friendly)
  - Padding-x space-4
  - Border 1px border-default
  - Radius radius-md
  - Type: email (triggers email keyboard on mobile)
  - Autocomplete: email
  - text-base (16px) to prevent iOS zoom on focus

#### Password field
- Label: "Password" — same style as email label
- Input: same dimensions; type "password"
- Toggle visibility: eye icon (16px) at right, inside field; tappable area 32x32 minimum
- Below input: helper text — "8+ characters with one number" — text-xs (12px), text-tertiary
- Strength indicator (optional, shown after typing starts):
  - Horizontal bar, height 4px, full width
  - Segments: weak (1/3 filled, danger-500), medium (2/3 filled, warning-500), strong (3/3 filled, success-500)

#### Submit
- Button: full width, primary style
- Height 48px (touch-friendly)
- Text: "Continue"
- Disabled state when form invalid

### Step 2: Verify email

- No form fields — informational
- Centered illustration or icon (mail-check, 64px, text-secondary)
- Heading: "Check your email"
- Subtitle: "We sent a link to {email}. Click it to verify."
- Below: "Didn't receive it?" + button "Resend" (text-button style; brand-600)
  - After resend click: button becomes disabled with text "Sent! Try again in {N}s" with countdown 60s
- "Wrong email?" link: brand-600; navigates back to step 1 with email field pre-filled

#### Auto-detection

- When user clicks the verification link in email and returns to app, this step auto-advances to step 3 (no manual action needed)
- Until verified, this step persists; doesn't auto-advance after a timeout

### Step 3: Profile

#### Display name
- Label: "What should we call you?" 
- Input: same dimensions as step 1 fields
- Type: text; autocomplete: name

#### Avatar (optional)
- Section heading: "Profile photo (optional)"
- Default avatar circle: 64px, bg-tertiary, with user-icon (32px, text-tertiary) inside
- "Upload photo" button: secondary, full width below avatar circle
- Selected state: actual photo replaces default; with "Change" link below

#### Submit
- Button: full width, primary
- Text: "Get started"

### Color, type, spacing tokens used

All values reference tokens. No hex literals.

### States

#### Default per step
As above.

#### Focus (any field)
- Ring 2px, brand-500, offset 2px

#### Error (validation)
- Border 1px danger-500
- Helper text replaced with error text — text-xs, danger-700, with alert-circle 12px

#### Loading (after Continue clicked)
- Button text replaced with spinner (16px)
- Form fields disabled
- "Verifying..." text replaces helper text on relevant field

#### Success (between steps)
- Brief checkmark animation (200ms scale-in) before step transition
- Step indicator dot transitions to "completed" state

#### Error (server-side)
- Banner appears above the form: bg-danger-50, padding space-3, danger-700 text
- Specific error: "This email is already registered" / "Couldn't send verification" / etc.
- Actionable: "Sign in instead?" link if email exists

## Interaction spec

### Forward navigation (Continue / Get started)
- Trigger: button click OR Enter key in form field
- Validation runs first; on invalid, shows errors and doesn't advance
- On valid: API call fires; loading state shown
- On API success: cross-fade to next step (250ms ease-out)
- Step indicator dot advances

### Backward navigation
- Trigger: back button (top bar) OR browser back button OR Escape key
- Form state for current step is preserved when leaving (in case user comes back)
- Form state for previous step is shown when arriving (data persisted)
- No confirmation needed (user just navigates back; nothing destructive)
- Cross-fade transition 250ms

### Step 2 specific (verification)
- "Resend" link click: API call to resend; button becomes disabled with countdown
- Countdown: 60s; button re-enables after; can resend up to 5 times then locked with "Contact support" message
- Auto-advance: when verification completes server-side, step advances automatically

### Field interactions
- Email: lowercase auto on blur (UX); validation runs on blur
- Password: visibility toggle persists choice for the session
- Display name: trim whitespace on blur

### Keyboard
- Tab order: form fields top to bottom → submit button → secondary links
- Enter in last form field: triggers primary action (Continue/Submit)
- Escape: navigates back (with confirmation if data unsaved? — no, since data preserved)
- Tab cycle: standard; nothing trapped

### Focus management
- Step open: first form field auto-focused
- Step transition: focus moves to step heading (programmatic; tabindex="-1")
- After verification auto-advance: focus moves to step 3 heading
- After error: focus moves to first errored field

## Accessibility spec

### Semantic HTML
- `<form>` per step
- Each input wrapped with `<label>` (label/input pair)
- Step indicator: visually hidden text "Step 1 of 3" announced to screen readers
- Headings: `<h1>` per step (each step is a logical page in the flow)

### ARIA
- Step indicator has `aria-label="Step {current} of 3, {step name}"`
- Verification step has `aria-live="polite"` so the "verifying..." status is announced
- Resend countdown has `aria-live="polite"` (announces remaining time)
- Errors associated via `aria-describedby` and `role="alert"`

### Contrast
- text-primary on bg-primary (mobile): 12.1:1 (AAA)
- text-primary on bg-secondary (desktop card): 12.1:1 (AAA) 
- text-secondary on either bg: 7.8:1 (AAA)
- text-tertiary (helper text) on bg-primary: 4.6:1 (AA — body)
- danger-700 on bg-primary (errors): 5.5:1 (AA)
- Brand-500 (focus ring, button bg): UI contrast ≥3:1; 4.2:1 verified
- text-on-brand (button text) on bg-brand-500: 4.7:1 (AA)

### Touch targets
- All form inputs: 48px tall (exceeds 44px floor)
- All buttons: 48px tall + full width on mobile
- Password toggle: 32x32 minimum (within field)
- Back button (top bar): 44x44 (icon + padding)

### Reduced motion
- Cross-fade between steps: instant
- Checkmark animation between steps: instant (or removed entirely)
- Strength indicator bar: instant transitions instead of animated fill

### Mobile-specific
- Email field: type="email" + autocomplete="email" (triggers email keyboard)
- Password field: autocomplete="new-password" on signup; "current-password" on login
- Display name: autocomplete="name"
- Don't auto-zoom on input focus (text-base = 16px which prevents iOS zoom)

### Screen reader flow
- Each step starts with heading announcement: "Step 2 of 3. Check your email."
- Verification status announced: "Verifying your email..."
- Verification success announced: "Email verified. Step 3 of 3. Tell us about yourself."
- Errors announced when they appear via role="alert"

<!-- design-spec-end -->
```

## Phase 4 — Self-test

```markdown
# Self-test record — issue #502 (design pencil-spec)

## Acceptance criteria
- [x] AC #1: 3-step flow specified — email/verify/profile
- [x] AC #2: step indicator at top of each step
- [x] AC #3: back navigation preserves form state (specified)
- [x] AC #4: mobile-first (full-screen mobile; centered card desktop)
- [x] AC #5: WCAG AA (contrast computed; touch targets ≥44px; ARIA documented)

## Spec sections present
- [x] Visual spec
- [x] Interaction spec  
- [x] Accessibility spec

## Foundations consulted
- aesthetic-direction.md
- typography.md (text-base 16px to prevent iOS zoom)
- color.md (contrast ratios)
- space-and-rhythm.md
- hierarchy.md (one anchor per step: the step heading)
- layout-and-grid.md (mobile full-screen vs desktop card)
- motion.md (250ms cross-fade between steps)
- iconography.md (chevron-left, eye, mail-check, check icons)
- patterns/forms.md (multi-step form pattern)
- patterns/responsive-and-density.md (mobile vs desktop layout)
- patterns/feedback-states.md (loading / error / success between steps)

## Ready for review: yes
```

## What this case demonstrates

- **Mobile-first means specifying mobile first**: the mobile layout is described as the default; desktop adaptations are noted as "at 768px+"
- **Touch targets explicit**: 48px buttons + 44px minimum for utility (back, password toggle)
- **iOS zoom prevention**: `text-base` (16px) on inputs is documented as a deliberate accessibility choice
- **Auto-advance considered**: verification step has a "happens automatically" flow specified, including focus management
- **Form data persistence across steps**: spec calls this out; fe decides implementation (client-state vs server-side draft)
- **Resend countdown specified**: a small but real interaction detail; without spec, fe would invent timing
- **Step indicator covers screen reader**: visually hidden text announces "Step N of 3"
