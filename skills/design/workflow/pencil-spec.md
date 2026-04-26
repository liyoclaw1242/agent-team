# Workflow — Pencil Spec (Mode A)

Authoring a design spec upstream of fe implementation. The output is a structured spec embedded in the issue body that fe will consume.

## Phase 1 — Read

Required:

1. The issue body in full
2. Parent issue body (`<!-- parent: #N -->`) — context for where this fits
3. `_shared/design-foundations/aesthetic-direction.md` — the project's overall direction
4. Existing specs in similar issues (search recent design-spec blocks) — extends consistency
5. Existing fe components / patterns being extended — visual continuity

Conditional:

6. `_shared/domain/` glossary if domain terms appear in the spec — naming consistency
7. The relevant `patterns/` file for the UI shape being designed
8. The relevant foundation files (typography, color, etc.) for the aspects being decided

If reading the issue body and you don't understand what UI shape this is or what user task it serves, that's a sign for Mode C feedback (`workflow/feedback.md`) — don't guess.

## Phase 2 — Reality check

Before drafting:

- Is there an existing pattern for this shape elsewhere in the product? Use it.
- Are the spec's stated AC actually achievable in the current design system? (E.g., AC says "must support 12 columns of data" but no existing pattern goes beyond 6 — that's a discussion.)
- Does the parent issue's broader story align with this spec's task? (Sometimes a child task drifts from parent intent.)
- Is the user task clear? Who is using this and what are they trying to do? If unclear, Mode C.

## Phase 3 — Draft the spec

The spec has three sections, in this order:

### Section 1: Visual spec

What the UI looks like in static form. Covers:

- **Type** — sizes, weights, colors per text role
- **Color** — fills, borders, backgrounds (referencing tokens, never hex)
- **Spacing** — paddings, gaps (referencing scale)
- **Layout** — structure, breakpoints
- **States** — at minimum: default, hover, focus, active, disabled, loading, error
  - Not all states apply to all elements; specify which states matter
- **Iconography** — if used: icon name, size, color
- **Imagery** — if used: aspect ratio, fit, fallback

### Section 2: Interaction spec

How the UI responds to user actions. Covers:

- **Triggers** — what user actions cause behavior (click, hover, scroll, keyboard)
- **Transitions** — what visual changes happen, durations, easings (referencing motion tokens)
- **Focus management** — where focus goes after interactions (e.g., after modal closes, focus returns to trigger)
- **Keyboard support** — Tab order, Enter / Escape / Arrow handling, shortcuts
- **Touch / pointer** — for components with mobile considerations: target sizes, gestures

### Section 3: Accessibility spec

What's required for the implementation to be accessible. Covers:

- **Semantic HTML** — what elements should be used (button vs a, h1-h6 hierarchy)
- **ARIA** — only when semantic HTML isn't enough; specify roles / labels / states
- **Contrast** — explicit contrast ratios for the color pairs in this spec; cite WCAG level (AA = 4.5:1 normal, 3:1 large)
- **Touch target** — minimum 24x24px (WCAG 2.2 minimum) for any interactive element
- **Screen reader announcements** — what announcements should fire on state changes (e.g., "form submitted" via aria-live)
- **Reduced motion** — for any animation: what's reduced when `prefers-reduced-motion`

## Phase 4 — Format with markers

Place the spec between markers in the issue body:

```markdown
<!-- design-spec-begin -->

## Visual spec

[content]

## Interaction spec

[content]

## Accessibility spec

[content]

<!-- design-spec-end -->
```

The markers let fe and qa extract the spec deterministically. Don't omit them.

## Phase 5 — Publish

```bash
bash actions/publish-spec.sh \
  --issue $ISSUE_N \
  --spec-file /tmp/spec-$ISSUE_N.md
```

The action:
1. Reads the spec file
2. Verifies it has the three required section headers
3. Strips any existing design-spec block from the issue body
4. Embeds the new spec between markers
5. Updates the issue body

`publish-spec.sh` is idempotent — re-running replaces the existing block. Useful when iterating on the spec.

## Phase 6 — Self-test

```markdown
# Self-test record — issue #220 (design pencil-spec)

## Acceptance criteria
- [x] AC #1: design spec authored covering form input, validation, submit button
  - Verified: spec embedded in issue body via publish-spec.sh
- [x] AC #2: spec includes mobile + desktop variants
  - Verified: Visual spec section enumerates breakpoints
- [x] AC #3: spec aligns with existing form pattern (login screen)
  - Verified: cross-checked with existing /apps/auth/login styling

## Spec sections present
- [x] Visual spec
- [x] Interaction spec
- [x] Accessibility spec

## Foundations consulted
- typography.md (for label / input / helper text sizes)
- color.md (for default / focus / error states)
- space-and-rhythm.md (for field spacing)
- forms.md pattern

## Validators
- spec-completeness: pass

## Ready for review: yes
```

## Phase 7 — Deliver

```bash
bash actions/deliver.sh \
  --issue $ISSUE_N \
  --self-test /tmp/self-test-issue-$ISSUE_N.md \
  --route-to arch
```

Mode A delivery doesn't open a PR (no code change). It:
1. Verifies self-test gate
2. Verifies the issue body has a design-spec block
3. Routes the issue to `agent:arch`

Arch dispatcher then:
- If the spec is for a future fe task: re-tags `agent:fe + status:ready`
- If the spec needs further architectural review: routes to arch-shape

## Anti-patterns

- **Spec without all three sections** — incomplete; deliver gate refuses
- **Hex codes in the spec** — hardcoded values; use tokens. If a token doesn't exist, propose one (don't just hardcode).
- **Over-specifying implementation** — spec says "use display: flex with justify-content: space-between" — that's fe's call. Spec says "label and value sit on the same row, label left, value right".
- **Under-specifying behavior** — spec covers visual but not focus management or keyboard. Incomplete.
- **Specifying only the happy path** — covers default state, ignores error / loading / empty. The non-default states are usually where bugs hide.
- **Specs that ignore foundation constraints** — uses 17px font ("looks better") on a 16/18 scale. Stick to the scale or propose a scale change.
- **Inventing a new pattern when an existing one fits** — the project has a card pattern; new spec describes a new card pattern that's almost the same. Use the existing one.

## When to use Mode C feedback instead

Don't draft a spec when:

- The parent intent is unclear and you're guessing
- The spec would require violating foundation rules with no justification
- The codebase has no existing pattern for this and you'd be designing one from scratch (this is bigger than a single spec; needs arch-shape involvement)
- The AC are contradictory or impossible

In these cases, post Mode C feedback per `workflow/feedback.md`.
