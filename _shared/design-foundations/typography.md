# Typography

Typography carries more design weight than most other choices. A bad type system shows up in every screen; a good one can carry an interface that's otherwise unremarkable.

## The three layers

A type system has three layers, in order of frequency of use:

1. **Body text** — the bulk of an interface. 14-16px sans, sometimes serif. Optimised for reading at length.
2. **UI labels** — buttons, form fields, navigation. 12-14px, often slightly heavier than body.
3. **Display / headlines** — section titles, page titles. 18-72px depending on hierarchy. Most expressive layer.

Most products get body and UI labels right by accident (use the system default and it's fine). Display type is where character lives. A distinctive display font + a refined body font is a strong default pairing for products that want personality without sacrificing readability.

## Type scale

Pick a scale and stick to it. Common choices:

```
Major Third (1.250):   12, 15, 18, 23, 29, 36, 45, 56
Major Second (1.125):  12, 14, 15, 17, 19, 22, 25, 28
Perfect Fourth (1.333): 12, 16, 21, 28, 37, 50, 67, 89
```

Major Third is a balanced default for product UI. Major Second is tighter — useful for dense interfaces. Perfect Fourth has dramatic jumps — better for editorial / marketing.

Map sizes to roles:

```css
--text-xs: 12px;   /* metadata, captions */
--text-sm: 14px;   /* secondary body, labels */
--text-base: 16px; /* primary body */
--text-lg: 18px;   /* emphasized body, small headings */
--text-xl: 23px;   /* section headings */
--text-2xl: 29px;  /* page subtitles */
--text-3xl: 36px;  /* page titles */
--text-4xl: 45px;  /* hero / display */
```

Don't add intermediate sizes ("but I want it slightly bigger than xl"). The system breaks if you do.

## Weight

Modern variable fonts give you a continuum from 100 to 900. Resist using all of them — three weights covers most interfaces:

- **400 regular** — body, default UI text
- **500 medium** — emphasis, headings (a softer alternative to bold)
- **700 bold** — strong emphasis, primary CTAs, top-of-hierarchy headings

Some systems prefer 400/600 instead of 400/500/700. Either works. The mistake is using 4+ weights — it dilutes hierarchy.

**Avoid 300 (light) for body text** — looks elegant in mockups, becomes unreadable on lower-DPI screens or smaller sizes. Reserve light weights for very large display sizes (>40px) where the contrast survives.

## Line height (leading)

The single biggest readability lever after font size.

Defaults that work:

- **Body text 14-18px**: line-height 1.5-1.7
- **Headings 20-40px**: line-height 1.2-1.3
- **Display 40px+**: line-height 1.0-1.1
- **UI labels (single line)**: line-height 1.0

The pattern: **bigger text gets tighter leading**. Body text needs room to breathe between lines because the eye returns from line-end to line-start; display text doesn't have that problem because it's usually one line.

```css
--leading-tight: 1.2;   /* headings, display */
--leading-normal: 1.5;  /* body */
--leading-relaxed: 1.7; /* long-form prose */
```

## Measure (line length)

The width of a column of text. Optimal for readability:

- **Body prose**: 50-75 characters per line (≈ 30-45em)
- **UI text in tables / cards**: 30-50 characters
- **Display headlines**: 20-40 characters

```css
.prose { max-width: 65ch; }
```

Short lines (<30 chars) feel choppy. Long lines (>80 chars) make the eye tire on return sweeps. Wider isn't more — even a 2000px viewport should constrain its prose to 65ch.

## Letter spacing (tracking)

Use sparingly. The font's default tracking is usually right. When to override:

- **All-caps text**: increase tracking (`letter-spacing: 0.05em`) — tight letters in caps look claustrophobic
- **Display text >40px**: decrease slightly (`letter-spacing: -0.02em`) — large type often looks loose at default
- **Tracked-out style** (deliberate): `letter-spacing: 0.2em` for stylised labels

Don't track body text. The font's optical adjustments at body size are correct.

## Font pairing

Pairings that work:

- **Sans display + sans body** (same family different weights): safe, coherent. Inter Display + Inter, etc.
- **Serif display + sans body**: classic editorial. Playfair + Inter, Söhne + Source Serif, etc.
- **Sans display + serif body**: less common, distinctive. Works for content-heavy products.
- **Display + monospace**: technical aesthetic. JetBrains Mono + a sans display.

Avoid pairing two fonts of the same vibe (two humanist sans, two slab serifs) — the contrast disappears, you lose the point of pairing.

For products: pick the body font first (it carries more text). Then pick a display font that contrasts but doesn't fight.

## Avoid these defaults

- **Inter for everything**: not bad, but ubiquitous. Pair it with something distinctive or pick a different sans.
- **Roboto / Open Sans / Lato**: the "I didn't think about this" fonts. Use them only if you mean to.
- **Comic Sans, Papyrus, etc.**: these are jokes; they don't read as jokes anymore.
- **Three+ font families in one product**: diminishes the system. Two families is plenty.

## Fluid type (responsive sizing)

For type that scales with viewport:

```css
font-size: clamp(1rem, 0.5rem + 1vw, 1.25rem);
```

This sizes between 16px (small viewport) and 20px (large viewport) with linear scaling. Use for hero headlines and large display text. Don't use for body — body should be a fixed comfortable size at every viewport.

## OpenType features

Modern fonts support typographic refinements:

```css
font-feature-settings:
  "ss01" on,    /* alternate stylistic set */
  "kern" on,    /* kerning */
  "liga" on,    /* ligatures */
  "tnum" on;    /* tabular numbers — for tables */
```

`tnum` (tabular numbers) is the most useful — fixed-width digits make tables of numbers align cleanly. Apply to columns of numbers. Don't apply globally; tabular zeros can look odd in prose.

## Quick checklist

For any interface:

- [ ] Distinct display font (or deliberately none)
- [ ] Body font readable at 14-16px
- [ ] Type scale defined; sizes used are on the scale
- [ ] 2-3 weights max
- [ ] Body line-height 1.5-1.7
- [ ] Body measure ≤65ch
- [ ] Tabular numerals on tables of numbers
- [ ] Headings tighter leading than body

If any of these are off, the typography is the first thing to fix.
