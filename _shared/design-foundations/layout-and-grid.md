# Layout and Grid

The structural skeleton beneath everything else. A consistent grid + container system makes layouts feel intentional even when nothing about them is novel.

## The container

The outermost rule of layout: content has a max width.

```css
.container {
  width: 100%;
  max-width: 1280px;  /* common for product UI */
  margin-inline: auto;
  padding-inline: var(--space-6);  /* 24px breathing room from edges */
}
```

Without `max-width`, content stretches to whatever the viewport is — including 4K monitors where lines of text become absurdly wide.

Common container widths:

- **640-720px** for prose-heavy / single-column reading
- **960-1024px** for content-focused product UI
- **1200-1280px** for dashboards / data-heavy
- **1440-1536px** for very dense or multi-column dashboards
- **No max-width** for full-bleed elements (hero images, marquee)

A page may use multiple containers stacked: the body is `1024px`, the hero spans full width, the data table is `1280px`. Each section knows its own appropriate width.

## The grid

A grid is a system of repeating columns and gutters. Two flavours:

### Fixed-column grid (12-column most common)

Bootstrap and many design systems use 12 columns because 12 divides evenly into 1, 2, 3, 4, 6 — supporting most natural layouts.

```css
.grid {
  display: grid;
  grid-template-columns: repeat(12, 1fr);
  gap: var(--space-6);
}
```

A "two-column" layout is one element spanning 8 columns + sidebar spanning 4. A "three-column" is each spanning 4. Etc.

### Auto-fit / track-based grid

For card grids that should reflow:

```css
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: var(--space-6);
}
```

This places cards at min-280px each, fitting as many as the viewport allows. No explicit breakpoints needed.

Use auto-fit for collections of similar things. Use 12-column for structural page layouts.

## Breakpoints

Discrete viewport widths where the layout shifts. Common set:

```css
/* Mobile-first */
--bp-sm: 640px;   /* small tablet, large phone landscape */
--bp-md: 768px;   /* tablet portrait */
--bp-lg: 1024px;  /* tablet landscape, small laptop */
--bp-xl: 1280px;  /* desktop */
--bp-2xl: 1536px; /* large desktop */
```

The layout reasoning:

- **<640px**: phone — single column, larger touch targets, simplified nav
- **640-1024px**: tablet — sometimes 2-col, sometimes still single
- **1024-1280px**: laptop — multi-col layouts work; sidebar nav typical
- **>1280px**: desktop — full sidebars, dense tables, side-by-side panels

Mobile-first CSS is conventional:

```css
.layout {
  display: block;  /* default: stacked */
}

@media (min-width: 768px) {
  .layout {
    display: grid;
    grid-template-columns: 240px 1fr;  /* sidebar + main */
  }
}
```

The CSS reads as "stack by default, switch to two-column at tablet+".

## Alignment

Three principles:

### 1. Align to a grid line

Every column, gap, and significant spacing should align to the grid. Numbers picked at random ("this is 13px from the edge") fight the system.

### 2. Prefer one alignment direction

Within a section, prefer mostly-left-aligned or mostly-centered, not mixed:

- A form: labels left-aligned, fields left-aligned, button left-aligned (or all right)
- A hero: title centered, subtitle centered, CTA centered
- A dashboard: cards left-aligned, headings left-aligned

Mixed alignment within one section makes it feel chaotic. Alignment can change between sections.

### 3. Align to content edges, not to invisible structure

When text + image sit side by side, the text top should align to the image top — even if your grid says otherwise. Visual alignment matters more than grid alignment when they conflict.

## Common page shapes

A few layouts cover most product UI:

### Sidebar + main

```
┌─────────┬──────────────────┐
│         │                  │
│ sidebar │      main        │
│ (240px) │   (flexible)     │
│         │                  │
└─────────┴──────────────────┘
```

Used for: dashboards, settings pages, anything with persistent navigation. Sidebar typically 240-320px.

### Top nav + content

```
┌─────────────────────────────┐
│        top navigation       │
├─────────────────────────────┤
│                             │
│         content             │
│         (centered)          │
│                             │
└─────────────────────────────┘
```

Used for: marketing pages, content-focused apps. Top nav 56-80px tall.

### Three-pane (rare for web)

```
┌────────┬─────────┬──────────┐
│  list  │ detail  │ inspector│
└────────┴─────────┴──────────┘
```

Used for: email clients, complex editors. Hard to do well below 1280px.

### Centered narrow

```
┌─────────────────────────────┐
│                             │
│      ┌────────────┐         │
│      │  content   │         │
│      │   (640px)  │         │
│      └────────────┘         │
│                             │
└─────────────────────────────┘
```

Used for: forms, single-task screens, sign-in flows. Constrains attention.

Most products use 2-3 of these consistently. Inventing new layouts per page is the wrong move.

## Z-index discipline

Z-index conflicts are a symptom of unstructured layout. Define a small scale:

```css
--z-base: 0;
--z-dropdown: 100;
--z-sticky: 200;       /* sticky headers */
--z-modal-backdrop: 300;
--z-modal: 400;
--z-popover: 500;       /* tooltips, popovers above modals */
--z-toast: 600;
```

Components reference these tokens, never magic numbers like `z-index: 9999`. When everything is 9999, nothing is.

## Edge cases

### Very wide screens (>1920px)

The container `max-width` handles this. Don't let content stretch.

### Very narrow screens (<360px)

Set a sensible minimum. Test at 320px (older phones, narrow browser windows). Below 320px, accept some compromise.

### Landscape phone

Touch targets need to remain hittable; avoid hiding them under the soft keyboard. Test landscape forms specifically.

## Common mistakes

- **No container max-width**: text 200 chars wide on 4K monitors
- **Container padding inconsistent across pages**: layouts drift
- **Too many breakpoints**: 6+ breakpoints = no layout actually works at any of them
- **Magic numbers in z-index**: `9999`, `99999`, `9999999` — define a scale
- **Different grid systems on different pages**: 12-col here, 16-col there, ad-hoc elsewhere
- **Centered alignment by default**: looks balanced; reads as un-anchored. Left-align unless deliberately centering for emphasis (heroes, modals)
- **Layouts that only work at one viewport**: design at 1440px, breaks at 1280px, breaks worse on phone

## Quick checklist

For any layout:

- [ ] Container has a max-width
- [ ] Page uses a known grid (12-col or auto-fit)
- [ ] Breakpoints follow the established set; no one-off media queries
- [ ] Consistent alignment within each section
- [ ] Z-index scale defined; no magic numbers
- [ ] Layout tested at 320px, 768px, 1024px, 1440px minimum
