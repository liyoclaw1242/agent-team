# Iconography

Icons are dense communication. A good icon system is invisible — users read icons as labels without thinking. A bad one is constant friction.

## Pick a system, not individual icons

The biggest mistake: assembling icons from multiple sources (one from Material, one from Heroicons, one from a stock library). The result is visual chaos — different stroke weights, different proportions, different metaphors.

**Pick one icon library and stick to it.** Common production-quality choices:

- **Heroicons** — clean, modern, two weights (outline / solid)
- **Phosphor Icons** — extensive, multiple weights
- **Lucide** — fork of Feather; slightly thicker strokes; good for product UI
- **Material Symbols** — Google's huge set; opinionated weight options
- **Tabler Icons** — large set, consistent style
- **Carbon Icons** — IBM's set; sharp, technical

For brand-specific products, sometimes a custom icon set is justified — but only if the budget supports designing 50+ icons consistently. Mixing custom + library icons is worse than either alone.

## Sizing

Icons should match the visual weight of the text they accompany.

A useful rule: **icon size ≈ text x-height × 1.5 to 2**.

Practically:

| Text size | Icon size |
|-----------|-----------|
| 12-14px (UI labels) | 14-16px |
| 14-16px (body) | 16-18px |
| 16-18px (buttons) | 18-20px |
| 20-24px (subheadings) | 24px |
| 24px+ (display) | 32px+ |

Common stock sizes: 16, 20, 24, 32, 40, 48, 64. Pick a 4-5 size scale and use only those.

```css
--icon-xs: 12px;   /* inline indicators */
--icon-sm: 16px;   /* default UI */
--icon-md: 20px;   /* buttons, navigation */
--icon-lg: 24px;   /* prominent UI */
--icon-xl: 32px;   /* feature highlights */
--icon-2xl: 48px;  /* empty states, illustrations */
```

## Vertical alignment

Icons sit on a baseline that doesn't match text baseline. By default they look high or low next to text. Fix:

```css
.button {
  display: inline-flex;
  align-items: center;
  gap: var(--space-2);
}

.button svg {
  width: 16px;
  height: 16px;
  /* If icon still looks misaligned, nudge: */
  /* transform: translateY(-1px); */
}
```

`align-items: center` on a flex container fixes 90% of cases. Manual nudging via `translateY(-1px)` or `translateY(1px)` handles the rest.

For inline icons mid-sentence, `vertical-align: text-bottom` or similar:

```css
.inline-icon {
  display: inline-block;
  width: 1em;
  height: 1em;
  vertical-align: -0.125em;  /* nudges icon to baseline */
}
```

## Stroke weight

Most modern icon libraries use stroke-based icons (outline) at 1.5-2px stroke weight, or filled (solid) variants. Pick one default:

- **Outline icons** for navigation, body UI (lighter visual weight)
- **Solid icons** for active / selected states, emphasis (heavier visual weight)

A common pattern: outline for unselected state, solid for selected:

```jsx
<Icon name={isActive ? "home-solid" : "home-outline"} />
```

Don't mix outline and solid in the same context (e.g., a navigation menu where some items are outline and others solid). Pick a system.

## Color

Icons inherit text color by default if you use SVG with `currentColor`:

```svg
<svg fill="currentColor" stroke="currentColor">
```

This is correct. Icons should match the text color of their context. Don't hardcode icon color unless the icon has its own meaning (warning red, success green) — in which case use semantic color tokens, not raw hex.

```css
.icon-default { color: var(--text-secondary); }
.icon-active { color: var(--brand-500); }
.icon-warning { color: var(--warning-500); }
.icon-danger { color: var(--danger-500); }
```

## Icon-only buttons need accessibility

A button with just an icon is unlabeled to screen readers. Always add `aria-label`:

```html
<button aria-label="Close dialog">
  <svg>...</svg>
</button>
```

Without the label, the button announces as "button" with no context. Common omission; common bug.

For icons that are decorative (sit next to a text label):

```html
<button>
  <svg aria-hidden="true">...</svg>
  <span>Save</span>
</button>
```

`aria-hidden="true"` tells screen readers to ignore the icon — the text label is the announcement.

## Icon meaning conventions

Some icons have stable meanings; deviation confuses users:

| Icon | Conventional meaning |
|------|----------------------|
| Magnifying glass | Search |
| House | Home / dashboard |
| Gear | Settings |
| Bell | Notifications |
| User silhouette | Profile / account |
| Three dots (⋮ or ⋯) | More actions / overflow menu |
| Hamburger (☰) | Menu (mobile primarily) |
| X | Close |
| ← / → | Navigation back/forward |
| ↑ | Upload (sometimes "send") |
| ↓ | Download |
| Trash can | Delete |
| Pencil | Edit |
| Check (✓) | Success / confirm |
| Exclamation (!) | Warning or error |
| Plus (+) | Add / create |

Don't invent novel icons for these meanings. Don't use these icons for unrelated actions (a gear that opens a help dialog is wrong; gears mean settings).

## When NOT to use icons

Sometimes a label is better than an icon:

- **Ambiguous actions**: "Process" — what icon represents that? Just write "Process".
- **Dense forms**: every form field with an icon is noise. Labels alone are clearer.
- **First-time use of an unusual concept**: "Pin" with a pushpin icon is fine; "Defer" with a clock icon is unclear. Use both, or just text.
- **Industry-specific terms**: legal / medical / financial actions often have no good icon. Text-only is fine.

The safest pattern: **icon + label** for primary actions, **icon only** for repeated UI elements (toolbar, navigation) where users will memorise. Icon-only without a tooltip on first encounter is a usability hazard.

## Icon-only UI: tooltips

If you do use icon-only buttons (toolbars, navigation), provide tooltips:

```html
<button aria-label="Bold" data-tooltip="Bold (Cmd+B)">
  <svg>...</svg>
</button>
```

The tooltip on hover/focus tells users what the icon does without polluting the visual surface.

## Common mistakes

- **Mixed icon libraries** — different stroke weights, different metaphors, looks unprofessional
- **Off-scale icon sizes** — a 17px icon next to 16px text because someone copy-pasted from somewhere
- **Misaligned icon-text** — flex+align-items:center fixes this; don't ignore it
- **Hardcoded icon colors** — breaks dark mode and theming
- **Icon-only buttons without aria-label** — accessibility violation
- **Decorative icons not marked aria-hidden** — screen readers announce "image, image, image" before reaching the actual content
- **Inventing icons for actions that have conventions** — the gear means settings; don't repurpose
- **Too many icons in one view** — visual noise; the eye can't read them all

## Quick checklist

For any icon use:

- [ ] One icon library across the product
- [ ] Sizes are on the icon scale
- [ ] Color uses tokens (currentColor or semantic)
- [ ] Aligned with adjacent text (flex+align-center)
- [ ] Icon-only buttons have aria-label
- [ ] Decorative icons marked aria-hidden
- [ ] Conventional icons used for conventional meanings
