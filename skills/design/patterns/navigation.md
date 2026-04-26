# Pattern — Navigation

How users move through the product. Navigation is the most visible structural decision; getting it wrong is felt on every screen.

## The three navigation scopes

Most products have navigation at three scopes:

1. **Global** — across the whole product (sidebar, top bar)
2. **Sectional** — within a major area (tabs, sub-nav)
3. **Local** — within a single page (within-page tabs, breadcrumbs)

Pick which scopes apply for your product. Most need 1+2; some need all three.

## Top navigation

A bar across the top of the page.

### Anatomy

```
┌──────────────────────────────────────────────────┐
│ Logo    Home  Products  About    🔍   👤 Profile │
└──────────────────────────────────────────────────┘
```

- Logo / brand on the left
- Primary nav items (links to top-level sections) — center or left
- Utility items (search, profile, notifications) — right

### Heights

- 56px — compact, marketing
- 64-72px — comfortable
- 80-96px — generous, often with prominent logo

### When to use

- **Marketing sites / public pages** — almost always top nav
- **Content products** (blogs, news) — top nav, sometimes with secondary
- **Apps with shallow hierarchy** — top nav fine
- **Apps with many sections / deep hierarchy** — sidebar usually better (top doesn't fit)

### Mobile

Top nav on mobile usually shrinks to:
- Logo on the left
- Hamburger icon on the right (opens drawer with full nav)

OR
- Bottom tab bar (mobile-first apps; persistent across screens)

## Sidebar navigation

A vertical strip on the side.

### Anatomy

```
┌─────────┬──────────────────────┐
│ Logo    │                      │
│         │                      │
│ Home    │      content         │
│ Items   │                      │
│ Settings│                      │
│         │                      │
│         │                      │
│ 👤 user │                      │
└─────────┴──────────────────────┘
```

- Logo top-left
- Nav items vertical list
- User / settings at bottom (separates from primary nav)

### Widths

- 240-280px — common
- 200-240px — compact
- 320px — generous, often with descriptions

### When to use

- **Apps with multiple top-level sections** (5+ that don't fit in top nav)
- **Workflow apps** where users persistently work in one section but need to switch
- **Settings / admin areas** with hierarchical structure

### Variants

- **Always-visible** — sidebar always present; common for desktop apps
- **Collapsible** — sidebar can collapse to icon-only (saves horizontal space); useful for content-dense apps
- **Drawer** — sidebar appears on demand (hamburger); usual for mobile

### Active state

The current section is highlighted:

- Background tint
- Bold weight
- Accent color border on the left
- Or combination

Don't make active state subtle. It's how users orient themselves.

## Tabs

For switching between views within a single conceptual area.

### Anatomy

```
┌─────────────────────────────────┐
│ [Overview] Activity  Settings   │  ← active tab visually distinct
├─────────────────────────────────┤
│                                 │
│         tab content             │
│                                 │
└─────────────────────────────────┘
```

### When to use

- **3-7 alternative views of the same thing** (Profile: Overview / Posts / Likes)
- **Settings sections within a settings page**

### When NOT to use

- **2 alternatives** — usually a toggle is cleaner
- **8+ alternatives** — needs a different shape (sidebar, dropdown)
- **Hierarchical content** — tabs don't show parent-child

### Tab styles

- **Underline tabs** — active tab has underline; default for most products
- **Box tabs** — active tab in a box shape; older style; still works
- **Pill tabs** — rounded pills; often used for filters / segments

Underline is the safe default.

### Mobile

Tabs need to fit horizontally. Options:

- **Scrollable** — tabs in a horizontal scroll if they overflow
- **Wrap to two rows** — usually awkward
- **Convert to dropdown** — works but loses the "switch quickly" affordance

Scrollable is most common.

## Breadcrumbs

Path through a hierarchy: where am I, where did I come from.

### Anatomy

```
Home  /  Products  /  Cancel Service  /  Edit
```

Each segment is a link except the current page (last item, plain text).

### When to use

- **Hierarchical content** with depth ≥ 2 levels
- **Search results / filtered views** (less obvious; provides context)

### When NOT to use

- **Flat structures** (one-level deep)
- **Apps where users don't navigate hierarchically** (most modern web apps don't need them)

### Styling

- Subtle (text-tertiary by default; text-secondary on hover)
- Separator: `/`, `>`, or `→`
- Current page: not a link, distinguished from links above

Don't make breadcrumbs visually heavy. They're orientation, not the focus.

## Mobile bottom tabs

A horizontal bar at the bottom of mobile screens.

### Anatomy

```
┌─────────────────────────────┐
│                             │
│         content             │
│                             │
├─────────────────────────────┤
│  🏠   📋    ➕    🔔   👤  │
│ Home  List  New  Alerts You │
└─────────────────────────────┘
```

### When to use

- **Mobile-first apps** with 3-5 top-level sections
- **Native-feeling experiences** where bottom tabs are the platform convention

### Number of tabs

3-5. Below 3, tabs aren't doing much. Above 5, tabs are too cramped on phones.

If you need more than 5, use 4 + "More" tab that opens a drawer.

## Keyboard / accessibility

### Skip links

For screen readers and keyboard users:

```html
<a href="#main" class="sr-only">Skip to main content</a>
```

The link is hidden visually but appears on focus. Always present at the top of the page.

### Landmark roles

```html
<nav aria-label="Main navigation">...</nav>
<main id="main">...</main>
<aside aria-label="Sidebar">...</aside>
```

Screen readers use these to jump between sections.

### Active state for screen readers

```html
<a href="/home" aria-current="page">Home</a>
```

`aria-current="page"` announces "current page" to screen readers.

### Tab navigation

- Tab moves through nav items
- Arrow keys move within a tab list
- Enter activates the current item
- Escape closes drawers / submenus

## Common mistakes

- **Sidebar that's too wide** (320+) eating screen real estate
- **Sidebar that doesn't collapse** on smaller screens
- **Tab bar with 8+ tabs** that scrolls awkwardly
- **Hamburger menu on desktop** when there's plenty of space for visible nav
- **Active state too subtle** — user doesn't know where they are
- **Breadcrumbs on flat sites** — visual clutter for no benefit
- **Mobile bottom tabs that change between screens** — should be persistent
- **No focus styles on nav items** — keyboard users lost
- **Multiple navigation patterns competing** — top nav + sidebar + tabs + breadcrumbs all on one screen

## Spec must include

For any nav element:
- Structure (what items, in what order)
- Active state (visual treatment)
- Hover / focus / pressed states
- Mobile / responsive behavior
- Keyboard support
- Screen reader landmarks / labels

## Quick checklist

- [ ] Single primary navigation pattern (don't combine top + sidebar arbitrarily)
- [ ] Active state clearly visible
- [ ] Mobile behavior specified (responsive collapse, drawer, bottom tabs)
- [ ] Keyboard navigation works (Tab order, arrow keys for tabs)
- [ ] `aria-current="page"` for active item
- [ ] Skip link to main content
- [ ] Touch targets ≥44px on mobile
