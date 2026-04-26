# Pattern — Data Display

Tables, lists, cards. The shapes that hold "many of the same thing". Different shapes for different scanning patterns.

## When to use which

The decision tree:

1. **Are users comparing values across rows?** → table (precise alignment matters)
2. **Are users scanning a list to find one item?** → list (often sortable / filterable)
3. **Are items rich (image + multiple fields + actions)?** → cards (each item gets visual real estate)
4. **Is there a hierarchy (groupings, parents/children)?** → tree or grouped list

Pick once per screen. Don't mix on the same data ("table at desktop, cards at mobile" is OK; mixing within one viewport is rarely OK).

## Tables

Best for: comparing values across rows; data with consistent column structure; bulk-actionable rows.

### Anatomy

```
┌──────────────────────────────────────────────┐
│ Header row    │ (sticky on scroll)           │
├──────────────────────────────────────────────┤
│ Row 1         │                              │
│ Row 2         │                              │
│ Row 3         │ (zebra stripes optional)     │
│ ...                                          │
│                                              │
│ Footer / pagination                          │
└──────────────────────────────────────────────┘
```

### Column types

- **Text** — left-aligned (default for most strings)
- **Numbers** — right-aligned (so digits line up by place value); use `tabular-nums` for monospaced digits
- **Dates** — right-aligned typically; consistent format
- **Status / badges** — left-aligned, fixed width
- **Actions** — right-aligned, often icon-only

### Row interactions

- **Hover** — subtle background tint (`bg-secondary` or similar)
- **Selected** — distinct background; checkbox in row indicates selection state
- **Click** — usually navigates to detail or expands inline
- **Right-click / actions menu** — context menu of operations

### Density

- **Comfortable** — 48-56px row height (default)
- **Compact** — 32-40px (power users; data-dense screens)
- **Spacious** — 64-80px (browsing-style; rich content)

Allow density toggle if users vary; default to one for the product.

### Responsive

Tables don't shrink well to mobile. Three approaches:

1. **Horizontal scroll** — keep the table; user scrolls right (works for "wide" tables)
2. **Stack into cards** — at mobile width, each row becomes a card with label-value pairs (works for "tall" tables)
3. **Truncate columns** — show only the most important columns at mobile; expandable detail

### Common mistakes

- **No sticky header** — long tables; user scrolls past the headers and forgets which column is which
- **Numbers left-aligned** — digits don't line up; comparing values is harder
- **Borders everywhere** — gridded tables feel cluttered; use horizontal-only borders or zebra stripes
- **Truncating without indication** — text cut off with no hover or expand → user can't see it
- **Too many columns** — 12+ columns on a 1280px screen; users can't see them all

### Spec must include

- Column headers (text, alignment)
- Row height per density mode
- Hover / selected / focus states
- Pagination behavior (if any)
- Mobile / responsive behavior
- Empty state ("No data yet")

## Lists

Best for: scanning to find one item; flat sequence of similar things; mobile-first.

### Anatomy

```
┌─────────────────────────────────┐
│ ◉ Item 1                        │
│   Subtitle / description         │
│                            ↗    │
├─────────────────────────────────┤
│ ◉ Item 2                        │
│   Subtitle                       │
│                            ↗    │
└─────────────────────────────────┘
```

Each row has:
- Optional avatar / icon (left)
- Primary text (title)
- Secondary text (subtitle / description)
- Optional metadata (right) — date, count, etc.
- Optional action (chevron, menu)

### Variations

- **Single-line** — just title, dense
- **Two-line** — title + subtitle, more breathing room
- **Three-line** — title + subtitle + metadata, richest

Pick one and apply consistently.

### Dividers

- Horizontal rule between items (subtle, `border-subtle` color)
- Or alternating background (subtle zebra stripe)
- Or whitespace gap (no divider; works when items are clearly visually separated by their internal structure)

Don't combine — one divider style.

### Selection / multi-select

For selectable lists: checkbox at row start. Selected rows have distinct background. Bulk action bar appears when ≥1 selected.

### Spec must include

- Row anatomy (which fields, their roles)
- Density (height, gap)
- Empty state
- Loading state (skeleton rows)
- Item interaction (navigate? expand? both?)
- Selection behavior (if applicable)

## Cards

Best for: rich items with multiple fields; visual content (images, charts); browsing-style use.

### Anatomy

```
┌──────────────────┐
│ [Image]          │
├──────────────────┤
│ Title            │
│ Description      │
│ Metadata         │
│                  │
│ [Action] [Menu]  │
└──────────────────┘
```

Cards have weight — they're visually heavier than rows in a table. Use when each item deserves attention.

### Layout

Cards in a grid:

```css
.card-grid {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: var(--space-6);
}
```

Min card width: 240-320px (varies by density). Gap: `space-4` to `space-6`.

### Card vs row

A card with a title, two lines of text, and a button is just a row with extra space. The question: does each item have visual content (image, chart, color block) that needs its own area? If yes, cards; if no, list.

### Spec must include

- Card dimensions (min/max width)
- Internal structure (image area, content area, action area)
- States (default, hover, focus, active)
- Grid layout / breakpoints
- Empty state ("No items")
- Loading state (skeleton cards)

## Empty / loading / error states

Every data display has at least four states:

- **Default with data** — the happy path
- **Loading** — initial fetch, refresh
- **Empty** — no data exists
- **Error** — fetch failed

Always spec all four. The non-default states are where users get stuck.

### Loading states

- **Skeleton screens** (preferred) — placeholder shapes matching the eventual content
- **Spinner** (acceptable) — central spinner on the data area
- **Progress bar** (for known-duration loads) — top of the data area

Skeleton is better because it tells users what's coming. Spinner is generic.

### Empty states

Don't just say "No data". Tell the user:

- What this would normally show
- Why it's empty (new account? filter applied? truly no items?)
- What to do next (CTA or hint)

```
[Friendly illustration]
You don't have any invoices yet.
Once you receive your first payment, it'll appear here.
[Create test invoice]
```

### Error states

- Don't expose stack traces or technical details
- Tell the user what happened (briefly)
- Tell them what to do (retry, contact support, go back)

```
[Error icon]
Couldn't load your invoices.
This usually resolves itself in a moment.
[Try again]
```

## Pagination vs infinite scroll vs load-more

- **Pagination** — discrete pages with numbers; best for known-finite collections; supports deep linking ("page 3")
- **Infinite scroll** — auto-load on scroll; best for browsing-style content (social feeds, image galleries); accessibility hazard for screen readers
- **Load more button** — explicit user action; best balance for most data tables and lists; users stay in control

Default to load-more or pagination. Use infinite scroll only when the use case is clearly browsing.

## Common mistakes

- **Wrong shape for the use case** — tables for scanning lists; cards for tabular comparison
- **Inconsistent shapes within one screen** — half table, half cards, no clear reason
- **Empty/loading/error not spec'd** — fe makes them up; usually wrong
- **No pagination strategy** — load all 5000 rows; 30 second initial load
- **Cramped at high density without compact mode** — defaults too tight
- **Every cell is a link** — tables where the row, the title, the date, and the actions are all clickable separately. Pick the canonical click target.

## Quick checklist for data-display spec

- [ ] Shape (table / list / cards) chosen with rationale
- [ ] All four states (data / loading / empty / error) specified
- [ ] Item / row anatomy clear
- [ ] Density approach (single density or toggle)
- [ ] Pagination strategy
- [ ] Responsive behavior (especially for tables)
- [ ] Selection / multi-select behavior (if applicable)
- [ ] Hover / focus / selected styles
- [ ] Sort / filter UI (if applicable)
