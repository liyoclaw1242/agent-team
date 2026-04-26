# Rule — Spec Completeness

A design spec must include all three sections (Visual / Interaction / Accessibility) before delivery. The deliver gate refuses incomplete specs.

## Why three sections

Each covers a different dimension of "what should be built":

- **Visual**: how it looks at a moment in time (any state)
- **Interaction**: how it changes over time and in response to user actions
- **Accessibility**: how it serves users with different abilities

Implementations that get only the visual right are common — they look like the mock until you try to use them. Specs that skip Interaction or Accessibility produce these implementations.

## Visual spec — what it must include

At minimum:

- **Type per text role** — title size+weight, label size+weight, body size+weight, etc.
- **Color** — fill, border, text — at minimum for default state
- **Spacing** — padding, margin/gap, in token references
- **Layout** — structure (grid, flex, stacked); breakpoints if responsive
- **States** — at minimum: default; plus hover/focus/active for interactive; loading/error/empty/disabled where applicable
- **Iconography** (if used) — icon name from the library, size, color
- **Imagery** (if used) — aspect ratio, fit (cover / contain), fallback

Not all of these apply to every spec. A spec for a static informational card has fewer states than a spec for a form input. The judgement call: "what does an implementer need to know to build this correctly?"

States to include depend on element type:

- **Buttons / links / clickable cards**: default, hover, focus, active, disabled, loading
- **Form inputs**: default, focus, filled, error, disabled
- **Data containers**: default, loading, empty, error
- **Navigation items**: default, hover, active (current), focus

## Interaction spec — what it must include

At minimum:

- **Triggers** — what user actions cause behavior (click, hover, keyboard, scroll, time)
- **Outcomes** — what state changes happen as a result
- **Transitions** — duration and easing for animations (token references)
- **Focus management** — where focus goes after the interaction (especially for modals, navigation, forms)
- **Keyboard support** — Tab order, Enter/Escape/arrow handling, shortcuts

For elements without significant interaction (a static label), this section can be brief: "no interaction; not focusable". Don't omit it — the brevity is the spec.

For complex interactions (drag, multi-step, animated transitions), this section may be the longest. Include enough that the implementation would be unambiguous.

## Accessibility spec — what it must include

At minimum:

- **Semantic HTML** — the right element type (button vs a, h1-h6 hierarchy, form vs div)
- **ARIA** (only when semantic HTML isn't enough) — role, label, state attributes
- **Contrast** — explicit ratios for color pairs, with WCAG level cited
- **Touch target** — minimum dimensions for any interactive element
- **Screen reader announcements** (for dynamic content) — what's announced via aria-live
- **Reduced motion handling** (if motion is used) — what changes when prefers-reduced-motion

For static text, accessibility may be a couple of lines: "use semantic heading level matching document structure; contrast ratio for body color is X:Y on Z background". Don't omit.

## Format

The spec is delimited by markers and structured with the three section headers:

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

The marker pair (`<!-- design-spec-begin --> ... <!-- design-spec-end -->`) lets `actions/publish-spec.sh` and any consumer (fe, qa) extract the spec deterministically.

The three section headers are required. Their exact text matters — `validate/spec-completeness.sh` checks for them.

## What the validator checks

`validate/spec-completeness.sh` verifies:

- The spec file contains lines starting with `## Visual spec`
- The spec file contains lines starting with `## Interaction spec`
- The spec file contains lines starting with `## Accessibility spec`
- All three sections have at least 3 non-empty content lines (i.e., actually populated, not just headers)

It does not verify the *quality* of the content — that's review's job.

## When sections are genuinely thin

Some specs are simple. A spec for "add a footer link" might have:

```markdown
## Visual spec

- Link text: "Privacy Policy"
- Style: matches existing footer links (text-secondary, no underline default,
  underline on hover)
- Position: end of footer link list, after "Terms"

## Interaction spec

- Click navigates to /legal/privacy
- Standard link interaction; no custom transitions
- Keyboard: focusable in tab order; Enter activates

## Accessibility spec

- Semantic HTML: anchor element with href
- Contrast: text-secondary on bg-primary = X:Y (PASS AA)
- Touch target: link has natural inline target; aim for 24x24 minimum via padding
  if the link sits among others closely
```

That's a complete spec. Brevity isn't incompleteness — missing dimensions is.

## Compound vs simple specs

Some issues deliver multiple discrete UI elements (e.g., "design the entire signup flow"). Three approaches:

### A: One spec per element

Issue body has multiple `<!-- design-spec-begin -->` blocks (one per element). publish-spec.sh would need to handle this — it currently doesn't (single block). For now: one issue per element if they're distinct.

### B: One spec covering the flow

Single block, with the three sections each containing per-element subsections:

```markdown
## Visual spec

### Email step
[content]

### Password step
[content]

### Confirmation step
[content]

## Interaction spec

### Email step
[content]
...

## Accessibility spec
...
```

This works when the elements share enough that combining is natural.

### C: Split into separate issues

If each step is independently implementable and reviewable, separate issues are cleaner.

Decide based on how the issues are likely to be implemented and reviewed. If fe will do all three steps in one PR, one issue + one spec makes sense.

## Common mistakes

- **Visual spec only** — interaction and accessibility omitted; deliver gate fails
- **"Same as X"** — spec says "same as the login button" but the login button has its own spec; reference is fine but include the actual values for resilience
- **Vague behaviour** — "smooth transition on hover" — duration? easing? property? specify
- **Missing states** — only default state described; user has no idea what hover or focus looks like
- **Skipping accessibility because "it's simple"** — every interactive element has accessibility considerations
- **Mixing spec with rationale** — long paragraphs about why instead of what. Rationale belongs in PR description or issue body's other sections; the spec block is the *what*.

## Quick checklist

For any spec:

- [ ] All three section headers present (`## Visual spec`, `## Interaction spec`, `## Accessibility spec`)
- [ ] Each section has substantive content (not just the header)
- [ ] States enumerated (which apply for this element)
- [ ] Tokens used (per `design-token-discipline.md`)
- [ ] Contrast ratios cited
- [ ] Spec block delimited by markers
