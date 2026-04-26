# Rule — Accessibility Floor

WCAG 2.2 Level AA is the **floor**, not the goal. A design spec that doesn't meet AA is incomplete. A visual review that finds AA violations marks them Critical.

## Why this rule

Accessibility isn't a feature you add at the end. It's a property of the design — built in from the spec, verified at review. A spec that says "we'll add aria-labels later" is broken; "later" is never.

Some accessibility issues stem from technical implementation (screen reader bugs, focus management). Many stem from the design itself (color contrast, color-only encoding, touch target size). The latter are design's responsibility.

## The floor — what every spec must include

### Color contrast

**WCAG 2.2 SC 1.4.3 (AA)**:

- Normal text (under 18px regular or 14px bold): **4.5:1** contrast
- Large text (18px+ regular or 14px+ bold): **3:1** contrast

**WCAG 2.2 SC 1.4.11 (AA)**:

- UI components and graphics (buttons, icons, focus indicators, form borders): **3:1** against adjacent colors

A spec must explicitly state the contrast for any color pair it specifies. Vague "make sure it's readable" doesn't cut it. The agent should compute the ratio.

### Color is never the only signal

**WCAG 2.2 SC 1.4.1 (A)**: don't use color alone to convey information.

If the spec says "show errors in red", it must also include text, an icon, or another signal. Same for status indicators, required field markers, etc.

### Touch target size

**WCAG 2.2 SC 2.5.8 (AA)**: interactive targets are at least 24x24 CSS pixels (with some exceptions for inline targets).

**Apple HIG / Material**: 44x44 (iOS) / 48x48 (Android) is more comfortable. Use 44 as the practical default.

A spec for any interactive element must include the target size. "Tap area is the icon size, 16x16" is wrong. Pad invisibly to 44x44.

### Keyboard accessibility

**WCAG 2.2 SC 2.1.1 (A)**: all functionality is operable via keyboard.

Interaction specs must include keyboard support. Click-only interactions are violations.

For drag-and-drop, swipe gestures, hover-only behaviors: include a keyboard alternative.

### Focus visibility

**WCAG 2.2 SC 2.4.7 (AA)** + **SC 2.4.11 (AA)**: focus indicator is visible and meets minimum visual properties.

Specs must specify the focus state for every interactive element. "Same as hover" is acceptable only if hover is also focus-visible. Default: 2px outline at brand color OR equivalent.

### Form errors

**WCAG 2.2 SC 3.3.1 (A) + SC 3.3.3 (AA)**: errors are identified, described, and (where possible) suggestions are provided.

Spec for error states must include:
- Visual indicator (color + icon + text — not color alone)
- Error message describing what went wrong
- Where appropriate, suggestion for fixing

### Required content for screen readers

For non-trivial UI (modals, complex forms, dynamic content), the spec includes screen reader behaviour:

- Announcements via `aria-live` regions (form submitted, item added, error appeared)
- Labels for all interactive elements (icon-only buttons need `aria-label`)
- Headings establish document structure
- Landmarks (`main`, `nav`, `aside`) for navigation

## What's beyond floor (push for it but not Critical if missing)

These are good practices that aren't strictly required but elevate quality:

- **AAA contrast** (7:1 normal, 4.5:1 large)
- **Reduced motion** beyond the basic `prefers-reduced-motion` handling
- **High contrast mode** support
- **Forced colors** mode (Windows accessibility) compatibility
- **Screen reader optimization** beyond minimum (skip links, deeply considered announcement copy)

Specs can mention these as "stretch" but missing them is Major or Minor finding, not Critical.

## When color contrast can't meet floor

Sometimes the brand color, when used for what brand demands, doesn't meet 4.5:1 against white. Options:

1. **Use a different shade for text use**: `text-brand-700` even if `bg-brand-500` is the brand color
2. **Don't use brand color for body text**: use it for accents, borders, fills
3. **Add a darker accessible variant**: `--brand-accessible: var(--brand-700)` for text needs
4. **Accept the limitation in non-critical contexts**: a decorative element that's also a known brand asset; floor still applies for functional UI

The "I want brand color for body links" case is exactly when option 3 applies.

## Verifying contrast

The spec must cite ratios with confidence. Use a tool:

```bash
# Command-line tool
npm install -g wcag-contrast
wcag-contrast "#ffffff" "#1a73e8"
# 8.6:1 (PASS AA, PASS AAA)
```

In design:
- Stark / Contrast plugin (Figma)
- WebAIM contrast checker
- Chrome DevTools (auto-detects)
- WhoCanUse.com (also models color blindness)

Cite the ratio in the spec:

```markdown
- text-on-brand: contrast ratio 7.4:1 (AAA, exceeds 4.5:1 floor)
- text-on-brand-disabled: contrast ratio 3.6:1 (PASS large only; this token
  is used only for disabled labels which are 18px bold so 3:1 floor applies)
```

The reviewer can verify by re-running the calculation.

## Review-time enforcement

`validate/contrast.sh` runs against the PR diff, calculating contrast for color pairs detected in CSS / Tailwind classes. Any pair below 4.5:1 (text) or 3:1 (UI) flags as Critical.

The check is best-effort — it can't detect all issues (computed colors, dynamic states) — but it catches the obvious failures.

## Anti-patterns

- **"Add aria-labels later"** — accessibility isn't deferrable
- **"Designers don't need to think about a11y"** — a11y is a design constraint as much as brand color is
- **Citing AAA when only AA is required** — over-claim; "AA" is the actual floor
- **Skipping focus state in spec** — fe will invent one; usually wrong
- **Color-only error states** — fails 1.4.1; always pair color + icon + text
- **Treating WCAG as a checklist** — "we did the items"; the items don't replace thinking about real users
- **Decorative-only treatment** — "decorative so a11y doesn't apply" — many "decorative" elements actually convey info (status badges, illustrations communicating empty state)

## When in doubt

- Default to the stricter requirement
- Test with a screen reader (VoiceOver on Mac is built in; learn the basics)
- Test keyboard-only navigation through the design (Tab through a Figma prototype isn't quite right but conceptually do this)
- Read WebAIM articles on the specific guideline you're uncertain about

## Relationship to `_shared/rules/accessibility.md`

That file is for implementers (fe agents) — practical patterns for building accessible UI. This file is for designers — what the spec must include and what review must verify. Both files agree on the floor; they speak to different audiences.
