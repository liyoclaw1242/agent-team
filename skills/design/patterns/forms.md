# Pattern — Forms

The most common UI element with the highest accessibility stakes. Forms also have the most state — every field has default / focus / filled / error / disabled / loading. A pattern checklist to apply when authoring or reviewing form specs.

## Anatomy of a field

A typical form field has:

```
┌────────────────────────────┐
│  Label                     │  ← above the input
│  ┌─────────────────────┐  │
│  │ Input               │  │  ← the field itself
│  └─────────────────────┘  │
│  Helper text (optional)    │  ← supports / explains
│  Error text (when error)   │  ← red, replaces helper when error
└────────────────────────────┘
```

Each piece needs spec coverage:

- **Label**: text, weight, color, position relative to input
- **Input**: height, padding, border, background per state
- **Helper / error**: when shown, text style, color
- **Required indicator** (if used): symbol, color, position

## States to spec

Every field has these states; the spec should include all that apply:

- **Default** — empty, not focused
- **Focus** — input has focus (shows focus ring)
- **Filled** — has value, not focused (sometimes same as default; sometimes distinct)
- **Error** — validation failed; error text shown; border changes color
- **Disabled** — not interactive; usually grayed out
- **Loading** — async validation in progress (rare; specify if used)

Special cases:

- **Read-only** — value present but not editable; visually distinct from disabled
- **Auto-filled** (browser fill) — yellow background by default; can be styled

## Layout

### Vertical stacking (default)

Fields stacked vertically, labels above inputs. Most accessible (eye scans naturally; touch-friendly).

```
Label A
[Input A]
helper

Label B
[Input B]

Label C
[Input C]
```

Vertical gap between fields: typically `space-4` to `space-6` (16-24px).

### Horizontal grouping (compact use)

Two related fields side-by-side (city + zip, first + last name). Use sparingly.

```
First name        Last name
[─────────]       [─────────]
```

Don't use horizontal grouping for unrelated fields just to save vertical space.

### Side labels (rare)

Label to the left of input. Compact; good for settings pages with many simple fields. Less accessible than top labels for screen readers.

## Sizes

Common heights:

- Small: 32px (compact UIs, dense forms)
- Medium: 40px (default for most products)
- Large: 48-56px (prominent forms, marketing signups, mobile)

The size matters for touch targets. 48px ensures comfortable mobile interaction; 32px is desktop-only.

## Validation

### When to validate

- **On blur** — most common; validates when user leaves the field
- **On change** (debounced) — for fields where instant feedback helps (password strength, available username)
- **On submit only** — for forms where intermediate validation is annoying (e.g., short address forms)

Don't validate on every keystroke without debouncing — flickering errors feel hostile.

### Error message tone

- Specific: "Email must include @" not "Invalid email"
- Action-oriented: "Try again with a different email" not "Email is wrong"
- Not blaming: "Please enter your email" not "You forgot to enter your email"

### Error placement

Below the field, above the next field. Not in a tooltip (screen readers may miss it). Not in an alert at the top of the form (user can't connect error to field).

If multiple errors: each below its field; optional summary at top with anchor links to each.

## Submit button

Should be:

- **Visually prominent** (primary CTA styling)
- **Below the form** (after all fields)
- **Aligned** to the form's content edge (left, center, or full-width)
- **Disabled when** the form has known errors / required fields are empty (controversial: some prefer always-enabled button that shows errors on click; either works if consistent)
- **Show loading state** when submission is in flight

Common variations:

- Primary submit + secondary "Cancel" or "Back" (for multi-step)
- Primary submit + tertiary "Save as draft"

Don't have multiple primary buttons. If there are two important actions, one is primary and one is secondary.

## Accessibility (form-specific)

### Required fields

Visually mark required (asterisk after label, with `aria-label="required"` on the asterisk). Mark in the input: `required` attribute.

### Field labels

Every input has an associated label:

```html
<label for="email">Email</label>
<input id="email" type="email" required>
```

Or wrapping:

```html
<label>
  Email
  <input type="email" required>
</label>
```

Don't rely on placeholder as label (placeholder disappears on input).

### Error association

```html
<label for="email">Email</label>
<input id="email" type="email" aria-describedby="email-error" aria-invalid="true">
<p id="email-error" role="alert">Email must include @</p>
```

`aria-describedby` connects input to error text. `aria-invalid="true"` flags the error state. `role="alert"` ensures screen readers announce the error when it appears.

### Field grouping

Related fields (e.g., billing address) wrapped in `<fieldset>` with `<legend>`:

```html
<fieldset>
  <legend>Billing address</legend>
  <label>...</label>
  ...
</fieldset>
```

This gives screen readers structural context.

### Keyboard support

- Tab moves through fields in order
- Enter in a field submits the form (assumes single-action submit; for multi-button forms, either Enter does nothing or Enter triggers the primary submit explicitly)
- Escape clears focus / dismisses if in a modal

## Common form types

### Login

Email + password + submit + "forgot password" link. Often very compact.

### Signup

Email + password + confirm password + (terms acceptance checkbox) + submit. Often longer; password requirements shown.

### Settings

Many fields, potentially in groups. Save button at the bottom OR auto-save (with toast confirmation per change).

### Multi-step / wizard

Steps with progress indicator (e.g., "Step 2 of 4"). Each step is a mini-form with Next button. Back navigation preserves entered data. Final step has Submit.

For multi-step: focus on simplicity per step. 3-7 fields per step is comfortable.

### Search

Single field + (often) search button. Results appear below or replace the page.

### Comment / feedback

Larger text area + submit. Often allows formatting (markdown, rich text). Character counter if there's a limit.

## Common mistakes

- **Placeholder as label** — disappears on input; accessibility violation
- **No focus styles** — keyboard users can't see where they are
- **Error text in red only** — color-only encoding; pair with icon and text
- **Validation that's too aggressive** — error appearing while user is still typing
- **Disabled submit button without explanation** — user clicks, nothing happens, confused
- **No loading state on submit** — user clicks again, accidentally submits twice
- **Auto-focus on the wrong field** — auto-focus is fine when there's clearly one starting field; harmful for forms with multiple entry points
- **Touch targets too small** — fields under 44px tall on mobile
- **No keyboard support** — clickable elements that aren't real form elements

## Quick checklist for form spec

- [ ] Each field has all relevant states specified (default / focus / filled / error / disabled / loading where applicable)
- [ ] Required fields marked visually + with `required` attribute
- [ ] Error association via `aria-describedby`
- [ ] Submit button styled as primary CTA; disabled state behaviour specified
- [ ] Validation timing decided (on blur, on submit, etc.)
- [ ] Focus management on submit (success: where does focus go? Error: focus first error?)
- [ ] Keyboard support specified (Tab order, Enter behavior)
- [ ] Touch target ≥ 44px on mobile
- [ ] Loading state for submit specified
