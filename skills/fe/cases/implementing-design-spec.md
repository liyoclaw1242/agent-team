# Case — Implementing a Design Spec

The other common dependency. Design has specced the visual + interaction patterns; you implement them faithfully, then deliver to QA + Design for verification.

## Example

Sibling Design task #142 delivered:

```markdown
## Cancellation Confirmation Modal — spec

### Layout
- Modal: 480px wide, vertically centred
- Padding: 32px
- Spacing between elements: 16px (use --spacing-4 token)

### Header
- Heading: "Cancel subscription?" (h2, --font-heading-2)
- Subheading: "This action cannot be undone." (body, --color-text-secondary)

### Content
- Effective date display:
  - Label: "Will end on:" (body-small, --color-text-secondary)
  - Date: large date format (e.g., "March 15, 2026"), --font-body, --color-text-primary

### Actions
- Two buttons, right-aligned, gap 12px
- "Keep subscription" — secondary button style
- "Yes, cancel" — destructive button style (--color-danger background)

### States
- Default: as above
- Loading (during API call): "Yes, cancel" shows spinner, both buttons disabled
- Error: error message below content area, --color-danger text, ARIA role=alert
- Success: modal closes, parent toast notifies

### Accessibility
- Modal has role=dialog, aria-modal=true, aria-labelledby pointing to heading
- Focus moves to first interactive element (heading focusable for screen readers)
- ESC dismisses (without action)
- Click outside dismisses (without action)
- Tab order: heading → "Keep subscription" → "Yes, cancel"
```

## Phase 1: read the spec exhaustively

Walk through every line. The spec is your contract; nothing in it is optional.

For each spec entry, ensure you can identify:

- The corresponding token (`--spacing-4`, `--color-text-primary`, `--font-heading-2`)
- The component primitive in the codebase (Button variants, Modal primitive)
- The behaviour (focus management, ESC handling)

If anything in the spec is ambiguous (e.g., "large date format" — is that a numeric token? does it have a name?), Mode C immediately. Don't guess large-date-format on your own.

## Phase 2: identify reusable primitives

Before writing new components, search:

```bash
grep -r "role=\"dialog\"" src/components/ --include="*.tsx"
# Find existing Modal primitive
```

If `<Modal>` exists with built-in focus management, use it. Don't reimplement.

If the spec asks for behaviour that the existing primitive doesn't provide (e.g., your Modal doesn't support click-outside dismissal), that's Mode C territory: "spec requires X behaviour, our Modal primitive doesn't support it; should I extend the primitive or use a one-off?"

## Phase 3: implement spec-faithfully

The implementation honours every spec line:

```tsx
function CancelConfirmationModal({ subscription, onClose, onSuccess }) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  return (
    <Modal
      isOpen
      onClose={onClose}
      width="480px"           // spec: 480px wide
      ariaLabelledBy="cancel-heading"
    >
      <div className={styles.container} /* padding: 32px, gap: 16px */>
        <h2 id="cancel-heading" className={styles.heading}>
          Cancel subscription?
        </h2>
        <p className={styles.subheading}>This action cannot be undone.</p>

        <div className={styles.dateRow}>
          <span className={styles.dateLabel}>Will end on:</span>
          <span className={styles.dateValue}>{formatLargeDate(subscription.effectiveDate)}</span>
        </div>

        {error && (
          <p role="alert" className={styles.error}>
            {error}
          </p>
        )}

        <div className={styles.actions}>
          <Button variant="secondary" onClick={onClose} disabled={pending}>
            Keep subscription
          </Button>
          <Button
            variant="destructive"
            onClick={handleConfirm}
            loading={pending}
            disabled={pending}
          >
            Yes, cancel
          </Button>
        </div>
      </div>
    </Modal>
  );
}
```

The CSS module references the tokens by spec:

```css
.container {
  padding: 32px;          /* spec */
  display: flex;
  flex-direction: column;
  gap: var(--spacing-4);  /* spec: 16px */
}

.heading {
  font: var(--font-heading-2);
  margin: 0;
}

.subheading {
  color: var(--color-text-secondary);
  margin: 0;
}

.dateLabel {
  font: var(--font-body-small);
  color: var(--color-text-secondary);
}

.dateValue {
  font: var(--font-body);
  color: var(--color-text-primary);
}

.error {
  color: var(--color-danger);
}

.actions {
  display: flex;
  justify-content: flex-end;
  gap: 12px;              /* spec */
}
```

## Phase 4: a11y verification (always)

Per `_shared/rules/accessibility.md`, verify:

- Tab order matches spec
- ESC dismisses
- Focus returns to the trigger when modal closes
- axe-core scan passes
- Screen reader (briefly) announces dialog opening with heading text

The self-test record's a11y line should reference this verification specifically.

## Phase 5: self-test calls out spec conformance

```markdown
- [x] AC: layout matches spec (480px, 32px padding)
  - Verified: visual diff against Figma; pixel-aligned within 1px tolerance
- [x] AC: tokens used per spec
  - Verified: searched the file for hard-coded values; only token references remain
- [x] AC: tab order: heading → keep → cancel
  - Verified: keyboard test in Chrome devtools; order matches
- [x] AC: ESC dismisses without action
  - Verified: pressed ESC, modal closed, no API call made
- [x] AC: success path closes modal + toast
  - Verified: mocked successful response; modal animates out, toast appears
```

## Anti-patterns

- **"Approximating" spacing** — `padding: 30px` instead of `32px` because "looks the same". Don't. The spec value is the value.
- **Hardcoding colour hex instead of tokens** — `#dc2626` instead of `var(--color-danger)`. Even if the values match today, tokens decouple from values; hardcoding fragments the design system.
- **Skipping states the spec listed** — error state, loading state, etc. The spec listed them because they exist in the design system; not implementing them means the modal doesn't gracefully handle the cases.
- **Inventing micro-interactions** — Design didn't spec a slide-in animation? Don't add one without filing follow-up. Even if "everyone knows modals slide in", it's a deviation from delivered spec.

## When Design and code conflict

Sometimes the spec uses a token name that doesn't exist in the design system (yet). Or the spec mentions a primitive that's been deprecated. This is Mode C territory:

```markdown
## Technical Feedback from fe

### Concern category
contract-conflict (between Design spec and design system)

### What the spec says
Use --color-danger background for destructive button

### What the codebase shows
Our Button primitive's "destructive" variant uses --color-error
(renamed last sprint per PR #501); --color-danger no longer exists
in tokens.

### Options I see
1. Use --color-error (current token); flag spec for update
2. Re-introduce --color-danger as alias

### My preference
Option 1; --color-error is the current standard.
```

Route back. Design + arch decide.
