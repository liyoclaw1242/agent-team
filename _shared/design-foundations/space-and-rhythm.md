# Space and Rhythm

Whitespace is what makes interfaces feel premium, scannable, or cluttered. It's also the most under-thought aspect of typical UI work — designers reach for content first, spacing as an afterthought.

## Why space matters

- **Grouping**: things close together feel related; separated things feel distinct (Gestalt proximity)
- **Hierarchy**: more space *around* an element makes it more important
- **Density**: how much information per screen — affects perceived complexity
- **Rhythm**: consistent spacing creates visual cadence; inconsistent spacing feels arbitrary

Most "this looks off" reactions trace to spacing problems before any other cause.

## The spacing scale

Pick a numerical scale and use only those values. Two common choices:

### 4px-based scale (most common)

```css
--space-0:  0;
--space-1:  4px;
--space-2:  8px;
--space-3:  12px;
--space-4:  16px;
--space-5:  20px;   /* sometimes omitted */
--space-6:  24px;
--space-8:  32px;
--space-10: 40px;
--space-12: 48px;
--space-16: 64px;
--space-20: 80px;
--space-24: 96px;
--space-32: 128px;
```

### 8px-based scale (Apple-style)

```css
--space-0:  0;
--space-1:  8px;
--space-2:  16px;
--space-3:  24px;
--space-4:  32px;
--space-5:  48px;
--space-6:  64px;
--space-7:  96px;
--space-8:  128px;
```

The 4px-based scale is more flexible (more granularity for small UI elements). The 8px-based scale enforces stricter discipline. Pick one for the system; don't mix.

**Crucial rule**: every margin/padding in the codebase should map to a value on the scale. Not 7px. Not 13px. Not 22px. If you find yourself wanting a value off-scale, either pick the closest scale value or there's a layout problem masking as a spacing problem.

## Inside vs outside (padding vs margin / gap)

A common confusion. Two different concepts:

- **Padding**: space *inside* an element, between its content and its edge (background extends to the padding edge)
- **Margin / gap**: space *between* elements (no background between)

A button has padding (interior breathing room around the label). A vertical stack of buttons has gap (separation between buttons).

Modern CSS prefers `gap` (in flex/grid containers) over `margin` for managing the space between siblings:

```css
.stack {
  display: flex;
  flex-direction: column;
  gap: var(--space-4);  /* clean, no last-child margin issues */
}
```

`margin` is for cases gap doesn't handle (collapsing margins for typography, asymmetric gaps).

## The spacing pairs

For each "thing" in an interface, two spacings often work together:

| Element | Inside (padding) | Around (gap to siblings) |
|---------|------------------|--------------------------|
| Small button | `space-2` (8px vertical) `space-3` (12px horizontal) | `space-2` between buttons |
| Card | `space-6` (24px) | `space-4` to `space-6` between cards |
| Section | `space-8` to `space-12` (32-48px) | `space-12` to `space-20` between sections |
| Page container | `space-6` to `space-12` | (no siblings; sets max-width) |

Bigger elements get bigger inside *and* bigger around. A card with 24px padding shouldn't sit 8px from another card — they'd visually merge.

## Vertical rhythm

Body text, headings, and inline elements form a vertical cadence. Three approaches:

### 1. Baseline grid (strict)

Every line of text sits on a fixed baseline (e.g., 8px). Headings and spacing always land on multiples of 8.

Strict but creates strong visual coherence. Hard to maintain in dynamic content (varying image heights break the grid).

### 2. Vertical rhythm via line-height (loose)

Set body line-height to 1.5 or 1.6. Heading margins use multiples of body line-height. Doesn't enforce a strict grid but keeps spacing proportional to type.

```css
body { line-height: 1.6; }     /* on 16px = 25.6px line */
h2 { margin-block: 1.5em 0.5em; }  /* relative to its own size */
```

### 3. Spacing scale (most common)

Use the spacing scale for all gaps. Don't worry about strict baseline alignment. Most product UIs use this.

## Density modes

Some interfaces have a "comfortable" mode for casual users and a "compact" mode for power users (think Gmail's display density settings). Density mode is a single multiplier on the spacing scale:

- Comfortable: 1.0x (default)
- Compact: 0.75x
- Spacious: 1.25x

Implement via a CSS variable on the root:

```css
:root { --density: 1; }
[data-density="compact"] { --density: 0.75; }

.card { padding: calc(var(--space-6) * var(--density)); }
```

Don't offer density unless your users actually need it. For most consumer products, one density is right.

## Section structure

A typical content page has rhythm at three scales:

1. **Within paragraphs / cards**: `space-2` to `space-4` (8-16px)
2. **Between elements within a section**: `space-4` to `space-8` (16-32px)
3. **Between sections**: `space-12` to `space-24` (48-96px)

The 3-tier rhythm creates breathing room without feeling sparse. Skipping the middle tier (jumping from 8px to 96px) makes interfaces feel disjointed.

## Negative space as a feature

Generous spacing — "lots of whitespace" — communicates:

- **Premium feel** (luxury brands; Apple)
- **Confidence** (the design doesn't need to fill every pixel)
- **Focus** (the eye knows where to land)

Tight spacing — dense interfaces — communicates:

- **Information-rich** (Bloomberg terminal; airline booking)
- **Power-user efficient** (everything visible; less scrolling)
- **Utilitarian** (the design serves function, not aesthetic)

Both work. Pick deliberately based on user task. Don't compromise to "balance".

## Common mistakes

- **Off-scale values**: 7px here, 14px there, 22px elsewhere. Stick to the scale.
- **Inconsistent gaps between similar elements**: cards 16px apart on one screen, 24px on another. Pick one.
- **Padding inside ≠ padding around**: a card with 24px internal padding next to another card with 8px between them looks crowded. Match the rhythm.
- **No vertical scale**: page sections all have the same gap; nothing reads as "bigger boundary".
- **Compact-by-default**: cramming things to fit "above the fold". Modern users scroll; let things breathe.
- **Margins instead of gap**: `margin-bottom: 16px` on every child + `:last-child { margin-bottom: 0; }`. Use gap instead.

## Quick checklist

For any layout:

- [ ] Spacing scale defined; only scale values used
- [ ] Padding inside elements matches scale
- [ ] Gap between siblings uses gap (not margin) where possible
- [ ] Three rhythm tiers: within, between, sections
- [ ] Density mode only if genuinely needed
- [ ] Sections breathe; user can identify boundaries without explicit dividers
