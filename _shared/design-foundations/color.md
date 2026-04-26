# Color

Color is the most over-used and under-systematised foundation. Most products have too many colors used inconsistently.

## The structure of a color system

A color system has four layers:

1. **Neutrals** — text, backgrounds, borders, surfaces. 80% of pixels.
2. **Brand color(s)** — primary identity. Used sparingly: CTAs, accents, key indicators.
3. **Semantic colors** — success/warning/danger/info. Communicate state, not identity.
4. **Data viz colors** (if applicable) — categorical palette for charts, maps.

Each layer needs its own palette. Mixing layers (using brand color for warnings, using semantic green for branding) confuses the system.

## Neutrals

The most important color decisions. A good neutral ramp can carry an interface that has no other color.

A neutral ramp is a sequence of grays from lightest to darkest, typically 9-12 stops:

```css
--neutral-0:   #FFFFFF;
--neutral-50:  #FAFAFA;
--neutral-100: #F5F5F5;
--neutral-200: #E5E5E5;
--neutral-300: #D4D4D4;
--neutral-400: #A3A3A3;
--neutral-500: #737373;
--neutral-600: #525252;
--neutral-700: #404040;
--neutral-800: #262626;
--neutral-900: #171717;
--neutral-950: #0A0A0A;
```

Pick a ramp with a slight hue tint (warm gray, cool gray) rather than pure mathematical gray. Pure gray feels lifeless.

### Mapping neutrals to roles

```css
--bg-primary:   var(--neutral-0);    /* page background */
--bg-secondary: var(--neutral-50);   /* card / surface */
--bg-tertiary:  var(--neutral-100);  /* nested surfaces */

--border-subtle: var(--neutral-200);
--border-default: var(--neutral-300);
--border-strong: var(--neutral-400);

--text-primary:   var(--neutral-900);
--text-secondary: var(--neutral-600);
--text-tertiary:  var(--neutral-500);
--text-disabled:  var(--neutral-400);
```

This gives every gray a name based on what it does, not what shade it is. Designers and developers reach for `--text-secondary`, not `--neutral-600`.

## Brand color

Most products need exactly one brand color. Two if you must. The brand color appears:

- Primary call-to-action buttons
- Active states (current nav item, selected row)
- Brand identity (logo, brand-specific moments)

It does **not** appear:
- All over the page as decoration
- On every interactive element (only primary CTAs)
- In chart palettes (use data viz colors)

A 9-stop ramp like neutrals:

```css
--brand-50:  #...;
--brand-100: #...;
...
--brand-500: #...;  /* most-used; the "the brand color" */
...
--brand-900: #...;
```

Use stops 50-100 for fills (`bg-brand-50` for a tinted card), 500-600 for emphasis (`text-brand-600` for a link), 700-900 for high-contrast applications.

## Semantic colors

Communicate state. Conventions are stable across most cultures:

```css
--success-500: green;
--warning-500: amber;
--danger-500:  red;
--info-500:    blue;
```

Each gets a 9-stop ramp, same structure as brand. Used for:

- Success: confirmations, positive metrics
- Warning: cautions, attention-needed
- Danger: errors, destructive actions, negative metrics
- Info: neutral notices

### When semantic colors leak

Mistake: using `--brand-500` (often blue) as the CTA color, then using `--info-500` (also blue) for info banners — they look the same. Either pick a non-blue brand color, or shift info to a clearly different shade.

Mistake: using `--success-500` for a hero call-to-action because "the brand is green". Then a real success state (form saved!) reads as just another button. Pick a brand color distinct from semantic ones.

## Contrast and accessibility

WCAG 2.2 contrast minimums for text:

- **Normal text** (under 18px regular or 14px bold): **4.5:1**
- **Large text** (18px+ regular, or 14px+ bold): **3:1**
- **UI components and graphics** (icons, focus rings, form borders): **3:1**

Verify with a contrast checker (Chrome DevTools, axe, color.review). Don't eyeball it.

For text:
- `--text-primary` on `--bg-primary` should easily exceed 7:1 (AAA territory)
- `--text-secondary` on `--bg-primary` should be ≥4.5:1
- `--text-tertiary` on `--bg-primary` is the danger zone — verify ≥4.5:1 for body, ≥3:1 if used only for >18px text

Disabled text deliberately fails 4.5:1 (3:1 is the floor) — that's how it reads as disabled.

## Dark mode

Building dark mode well means a parallel set of token mappings, not inverted colors:

```css
:root {
  --bg-primary: var(--neutral-0);
  --text-primary: var(--neutral-900);
  /* ... */
}

@media (prefers-color-scheme: dark) {
  :root {
    --bg-primary: var(--neutral-950);
    --text-primary: var(--neutral-100);
    /* ... */
  }
}
```

Things that change in dark mode:

- Backgrounds get *darker* but rarely pure black (pure black + white text strains eyes; use neutral-950)
- Text gets lighter but rarely pure white
- Brand colors often need lightening — `--brand-500` may be too saturated against dark; use `--brand-400` instead
- Semantic colors usually shift one stop lighter
- Shadows are often replaced by lighter borders (since shadows don't show on dark)
- Image / video brightness sometimes reduced via filter

Things that stay similar:

- Hierarchy (the primary text is still the most prominent)
- Spacing (no need to change)
- Typography (no need to change)

Test dark mode with real content. Pure inversions look like negatives; proper dark mode looks like a deliberate alternative.

## Color in data viz

Categorical (different categories): pick a 6-8 color palette where:
- Adjacent colors are clearly distinguishable
- All colors have similar perceived brightness (so no one category visually dominates)
- The palette is colorblind-safe (test with simulators)

Sequential (more vs less of one thing): single-hue ramp from light to dark, OR a multi-hue ramp like viridis / magma. Sequential should always be ordered.

Diverging (positive vs negative around a midpoint): two single-hue ramps meeting at a neutral middle. Common: red → white → blue.

Don't use the brand color as one of the categorical viz colors — it implies that category is "the brand category" which is rarely true.

## Color tokens (the implementation surface)

The system above lives as CSS custom properties (or Tailwind config, or design-token JSON). The rule:

**Components reference tokens, never hex values.**

```css
/* Wrong */
.button-primary {
  background: #1a73e8;
  color: white;
}

/* Right */
.button-primary {
  background: var(--bg-brand-strong);
  color: var(--text-on-brand);
}
```

The wrong version breaks dark mode (white text on light brand background = invisible). The right version uses semantic tokens that adapt.

`validate/token-usage.sh` (in design's validate dir) catches hardcoded hex in PRs.

## Common mistakes

- **Too many colors** — five brand-ish colors used randomly. Pick one.
- **Inconsistent neutrals** — three different "grays" used interchangeably. Pick a ramp.
- **Insufficient contrast on light text** — gray-on-white that fails 4.5:1
- **Same color for brand and info / success** — semantic confusion
- **Hardcoded colors in components** — breaks dark mode and theming
- **Pure black on pure white** — too high contrast, eye-tiring; use neutral-900 / neutral-50
- **No documented palette** — colors picked ad-hoc per screen; consistency lost

## Quick checklist

For any color decision:

- [ ] Token name expresses role, not shade (`text-secondary`, not `gray-500`)
- [ ] Neutrals have a ramp; brand has a ramp; semantics have ramps
- [ ] Text contrast ratios verified (4.5:1 minimum)
- [ ] Dark mode tokens defined (not just inverted)
- [ ] Brand color appears sparingly; not on every interactive thing
- [ ] No hardcoded hex in components
