# Pattern — Responsive and Density

How designs adapt across viewports and information densities. Two related but distinct concerns.

## Responsive: viewport-based

The same UI shown on different viewport sizes. Mobile-first is the modern default.

### Breakpoints

Standard set (referenced in `_shared/design-foundations/layout-and-grid.md`):

```
sm:  640px   small tablet, large phone landscape
md:  768px   tablet portrait
lg:  1024px  tablet landscape, small laptop
xl:  1280px  desktop
2xl: 1536px  large desktop
```

Spec specifies behaviour at each relevant breakpoint. Not every breakpoint matters for every component — a button might look identical at all sizes; a dashboard might be radically different.

### Mobile-first writing style

Default styles target mobile; media queries layer on for larger:

```markdown
## Visual spec

### Default (mobile, <640px)
- Stack: vertical
- Padding: space-4
- Title: text-2xl (24px)

### md+ (≥768px)
- Stack: horizontal (flex-row)
- Padding: space-6
- Title: text-3xl (32px)
```

This matches CSS structure (`min-width` queries layered on a mobile default).

### Common adaptations

| Element | Mobile | Desktop |
|---------|--------|---------|
| Layout | Single column, stacked | Multi-column, sidebar |
| Navigation | Hamburger / bottom tabs | Top bar / sidebar |
| Modals | Often full-screen | Centered floating |
| Tables | Stack into cards or scroll horizontal | Full table |
| Forms | Wider fields, larger touch | Tighter, multi-column |
| Type | Slightly larger body (16px+) | Comfortable (14-16px) |
| Spacing | Generally tighter (less screen) | Generally looser |

### What stays the same

- Aesthetic direction
- Color palette
- Type scale (the same scale; sizes within may shift)
- Hierarchy structure

## Density: data-amount-based

Some products offer the same view at different visual densities — comfortable / compact / spacious. Density adjusts spacing without changing structure.

### When to offer density

- Power users handle dense interfaces; new users prefer breathing room
- Browsing vs working modes differ
- Accessibility: some users benefit from increased spacing

Skip density toggle if your product has a clear single mode. Most consumer products don't need it.

### Implementation

Single multiplier on the spacing scale:

```css
:root { --density: 1; }
[data-density="compact"] { --density: 0.75; }
[data-density="spacious"] { --density: 1.25; }

.card {
  padding: calc(var(--space-6) * var(--density));
}
```

The multiplier touches paddings, gaps, and row heights — but not type sizes (those should stay legible in any density).

### Spec notes for density

If density is supported:

```markdown
## Visual spec

### Comfortable (default)
- Row height: 48px
- Card padding: space-6 (24px)

### Compact
- Row height: 32px
- Card padding: space-4 (16px)

### Spacious
- Row height: 64px
- Card padding: space-8 (32px)
```

The spec shows all three; impl handles the variable.

## Combined: responsive + density

Some products do both. Mobile is its own density (more spacious by default for touch); desktop offers density toggle.

```markdown
### Mobile (<768px)
- Single density (comfortable)
- Stack: vertical
- Touch targets: ≥44px

### Desktop (≥1024px)
- Density toggle: comfortable / compact / spacious
- Stack: horizontal
- Touch targets: 32-44px (varies by density)
```

Don't offer density toggle on mobile — there's not enough horizontal space, and touch targets need to stay accessible.

## Touch vs pointer

Mobile is touch; desktop is pointer. Differences:

### Touch (mobile / tablets)

- Larger targets (44px minimum, 48px+ comfortable)
- Hover states unavailable (no pointer to hover)
- Long-press as a possible secondary action
- Sliding / swiping gestures
- No right-click

### Pointer (desktop)

- Smaller targets acceptable (24px minimum, 32-40px typical)
- Hover states usable (preview, tooltip, etc.)
- Right-click for context menus
- Keyboard shortcuts more relevant

### Spec implications

- Hover states: specify, but note "hover not available on touch"
- Touch alternatives for hover-only interactions: explicit close buttons instead of hover-to-dismiss, etc.
- Right-click context menu equivalents: triple-dot button or long-press on touch

## Common mistakes

### Responsive

- **Designing only for one viewport** — desktop only, mobile broken
- **Too many custom breakpoints** — instead of using the standard set
- **Mobile as a degraded desktop** — instead of a different optimised view
- **Hidden content on mobile** — important info crammed into "expand for more"
- **Touch targets too small at any breakpoint**
- **Hover behaviors with no touch alternative** — feature unavailable on mobile

### Density

- **Density that changes type sizes** — loses readability; only spacing should change
- **Density only on some elements** — inconsistent feel; toggle should affect all spacing
- **Three densities feels arbitrary** — usually 2 (comfortable + compact) is enough

## Performance and viewport

Mobile users often have slower connections. Spec implications:

- **Image sizes**: don't ship 4K images to phones; use srcset / responsive images
- **Above-the-fold prioritization**: critical content loads first
- **Lazy load**: images and components below fold
- **Reduced data mode**: respect `Save-Data` header where relevant

These are mostly fe / impl concerns but the spec should specify "high-resolution version" vs "mobile version" for any image-heavy areas.

## Print

Often forgotten. If users will print:

```css
@media print {
  /* Hide nav, footers, sidebars */
  /* Use serif for body */
  /* Single column */
  /* Black on white */
}
```

Spec specifies if print is a real use case. For most product UI, it's not — but for receipts, invoices, reports, agreements: yes.

## Spec must include

For responsive UI:
- Behavior at sm / md / lg / xl breakpoints (which apply)
- Layout shift between mobile and desktop
- Touch target sizes per viewport
- Hover handling on touch (alternatives or removal)

For density (if supported):
- The density modes offered
- What changes per mode (typically: spacing, row heights)
- What doesn't (type sizes stay constant)
- Default mode

## Quick checklist

For any responsive spec:

- [ ] Mobile and desktop layouts both specified
- [ ] Breakpoint where layout shifts noted
- [ ] Touch targets ≥44px on mobile
- [ ] Hover states have touch alternatives or are removed
- [ ] No critical content hidden at any viewport
- [ ] Standard breakpoint set used (no custom ones)

For density:

- [ ] Default density picked
- [ ] Density modes (if any) defined
- [ ] What changes per density (spacing only, or others)
