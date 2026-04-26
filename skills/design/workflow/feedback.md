# Workflow — Feedback (Mode C)

Same structure as fe/be/qa/ops. design-specific patterns and triggers.

## Common triggers

- **Foundation conflict**: spec implies a value off the type / color / spacing scale with no justification
- **Pattern conflict**: spec describes a UI shape that doesn't fit any existing pattern AND inventing one is bigger than this task
- **A11y impossibility**: spec's interaction model can't be made accessible (e.g., color-only encoding, drag-only with no keyboard equivalent)
- **Domain model conflict**: spec assumes data shape that doesn't match what BE actually returns
- **Cross-task coupling**: this spec only makes sense alongside another not-yet-existent task
- **Wrong-outcome**: the spec optimises for the wrong thing (e.g., "make it eye-catching" when the actual user task is fast scanning)

## Confirm before posting

For each trigger, verify:

- Foundation conflict: is the value really off-scale, or is there a token I missed? Check `_shared/design-foundations/`.
- Pattern conflict: is there really no existing pattern, or have I not searched enough? Look at related parts of the product.
- A11y impossibility: is it really impossible, or is there a less-obvious accessible alternative?
- Domain conflict: confirm with BE contracts (in issue body's `<!-- be-contract -->` block if exists)
- Cross-task: is the dependency real, or could I make a simplifying assumption?

## Format

```markdown
## Technical Feedback from design

### Concern category
{foundation-conflict | pattern-conflict | a11y-impossibility |
 domain-conflict | cross-task-coupling | wrong-outcome |
 missing-AC | over-prescription}

### What the spec says
{quote the specific text}

### What the foundation / pattern / codebase / domain reality shows
{evidence}

### Options I see
1. {option A}
2. ...

### My preference
{which option, with rationale}
```

## Post and route

```bash
bash actions/feedback.sh \
  --issue $ISSUE_N \
  --feedback-file /tmp/feedback-$ISSUE_N.md
```

Same flow as other roles: post comment, route to `agent:arch`, dispatcher routes to arch-feedback.

## Design-specific examples

### Example 1: foundation conflict

```markdown
## Technical Feedback from design

### Concern category
foundation-conflict

### What the spec says
"Title text: 22px, weight 600"

### What the foundation reality shows
Type scale defined in `_shared/design-foundations/typography.md` is:
12, 14, 16, 18, 23, 29, 36, 45 (Major Third).
22px is off-scale.
Weight scale is 400, 500, 700. Weight 600 is off-scale.

### Options I see
1. Use 23px / weight 500 (closest scale values)
2. Use 18px / weight 700 (different hierarchy reading)
3. Add 22px / 600 to the scale (broader change; needs arch-shape)

### My preference
Option 1. 23px / 500 reads similarly to 22px / 600 visually but stays
on-scale. The hierarchy implied is the same.
```

### Example 2: a11y impossibility

```markdown
## Technical Feedback from design

### Concern category
a11y-impossibility

### What the spec says
"Color-coded status badges: green for active, red for paused, gray for ended"

### What the foundation / accessibility reality shows
Color-only state encoding fails WCAG 1.4.1 Use of Color. Color-blind users
cannot distinguish active from paused (red-green color blindness affects
~8% of men).

### Options I see
1. Color + icon (check / pause / archive icon alongside color)
2. Color + text label ("Active" / "Paused" / "Ended" written next to color)
3. Color + shape (filled circle / outlined circle / solid square)

### My preference
Option 2. Text label is most accessible (also helps screen readers without
needing aria-label). Icons can supplement but text is the primary signal.
```

### Example 3: pattern conflict

```markdown
## Technical Feedback from design

### Concern category
pattern-conflict

### What the spec says
"Display the user's recent transactions as a vertical timeline with
inline edit-in-place for each item"

### What the codebase / pattern reality shows
Existing transaction display pattern is a paginated table at
`/apps/billing/transactions`. No vertical timeline pattern exists.
No inline-edit pattern exists in transaction-related screens (edits go
through a modal everywhere else in billing).

### Options I see
1. Use existing table pattern; modal for edit (matches rest of billing)
2. Build new timeline + inline edit pattern (consistent within this feature
   but inconsistent with billing area)
3. Build timeline pattern, keep modal for edit (mixed)

### My preference
Option 1. Consistency with billing area beats internal consistency of one
feature. If timeline is genuinely better for this task, that's a
broader pattern discussion (arch-shape level), not a one-off spec.
```

### Example 4: wrong-outcome

```markdown
## Technical Feedback from design

### Concern category
wrong-outcome

### What the spec says
"Make the cancellation confirmation eye-catching with celebratory animation"

### What I think the actual user task is
Cancellation is rarely celebratory. Users cancel because something didn't
work for them; a celebratory animation reads as tone-deaf. The user task
is: confirm the action took, see what happens next (refund timing, access
window), get back to their day quickly.

### Options I see
1. Subdued confirmation: "Your subscription is cancelled. Access continues
   until {date}. We've sent an email confirmation."
2. Celebratory animation as specified
3. Empty state messaging that's warm but not celebratory

### My preference
Option 1. The user just made a difficult decision; meet them where they
are. Celebration is for new starts, not endings.
```

This kind of feedback challenges spec intent, not just spec form. Use sparingly — when you're confident the outcome being optimized for is misaligned with user need.

## Anti-patterns

- **Feedback as preference for a different aesthetic** — "I'd rather it look minimal" with no evidence-based rationale
- **Feedback citing personal taste as foundations** — "13px feels small"; check the scale, not the feeling
- **Adversarial feedback** — feedback isn't a fight with arch; it's collaborative reality-checking
- **Feedback during visual review of a PR** — different mode. PR-time concerns about spec → set `triage: design` in verdict; broader concerns via Mode C separately
- **Feedback bundling unrelated concerns** — one Mode C per issue per concern; don't combine "spec is wrong" with "while we're at it, here are other thoughts"

## After feedback returns

Same as other roles: read new state, start fresh from `workflow/pencil-spec.md` Phase 1.
