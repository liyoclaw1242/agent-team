# Case — Pencil Spec for a Dashboard

Mode A worked example. Scenario: a billing dashboard showing key metrics, recent transactions, and pending actions. Data-dense; multiple regions on one screen.

## The issue

```markdown
## Goal
Billing admins can see account health at a glance and act on what needs attention.

## Acceptance criteria
- [ ] AC #1: shows MRR, ARR, active subscriptions, churn rate (4 key metrics)
- [ ] AC #2: shows last 7 days of transactions in a chronological list
- [ ] AC #3: shows pending items requiring action (failed payments, expired cards)
- [ ] AC #4: refreshes automatically every 60s; manual refresh option
- [ ] AC #5: usable at 1024px+ (admin desktop tool; not mobile-first)

<!-- intake-kind: business -->
<!-- parent: #401 -->
```

## Phase 1 — Read

Foundations consulted:
- `aesthetic-direction.md` — refined utilitarian; data-forward
- `typography.md` — Major Third scale; tabular-nums for numbers
- `color.md` — neutrals + semantic palettes (success/warning/danger)
- `hierarchy.md` — multi-region screen needs clear primary anchor
- `layout-and-grid.md` — 12-column grid, sidebar layout
- `patterns/data-display.md` — table for transactions, list for pending
- `patterns/feedback-states.md` — loading / empty / error per region

Existing patterns:
- `/apps/billing/customers` — uses sidebar layout, 1280px container, similar metric tile pattern
- Existing metric tile component (`<MetricTile>`) takes title/value/delta props

Decision: extend existing dashboard pattern; reuse MetricTile; design pending-items list as a new but minimal pattern.

## Phase 2 — Reality check

- All AC achievable with existing tokens
- Auto-refresh: every 60s is feasible; spec needs to define what happens on refresh (full reload? incremental update? indication of staleness?)
- 1024px+ minimum noted; mobile not required

Spec decision: incremental update on refresh (no full reload); subtle "Last updated: {time}" indicator that becomes more prominent if data goes stale (network failure, etc.).

## Phase 3 — Draft

```markdown
<!-- design-spec-begin -->

## Visual spec

### Page layout

- Container: max-width 1280px, padding-x space-6
- Sidebar: 240px wide (existing pattern; not part of this spec)
- Main content area: remaining width; padding-y space-8

### Page header

- Title: "Billing dashboard" — text-3xl (36px), weight 500, text-primary
- Subtitle: "Last updated: {timestamp}" — text-sm, weight 400, text-tertiary
- Right-aligned: "Refresh" button — secondary style; 32px height; refresh-cw icon (16px) + text
- Position: top of content area; space-8 gap below

### Metrics row (4 tiles)

- Layout: CSS Grid, 4 equal columns, gap space-4
- At 1280px+: 4 across; at <1280px: 2x2 (the 1024px target falls in this range)

#### Each tile (MetricTile)
- Background: bg-secondary
- Border: 1px border-subtle
- Radius: radius-lg
- Padding: space-6
- Content:
  - Label: "MRR" / "ARR" / "Active subs" / "Churn rate" — text-xs (12px), weight 500, text-secondary, uppercase, tracked-out (letter-spacing 0.05em)
  - Value: text-3xl (36px), weight 500, text-primary, tabular-nums
  - Delta: arrow icon + text — text-sm (14px), weight 500
    - Positive: success-700 + arrow-up
    - Negative: danger-700 + arrow-down
    - Neutral: text-secondary + minus icon

### Two-column section below metrics

- Layout: CSS Grid, 2 columns at 1280px+ (8/12 + 4/12 split via gap)
- At 1024-1280px: stacked (single column)
- Gap: space-6

#### Left column: Recent transactions

- Section heading: "Recent transactions" — text-xl (23px), weight 500
- "View all" link on right: text-sm, brand-600
- Table follows (specs below)

#### Right column: Pending actions

- Section heading: same style as transactions
- "Mark all read" link on right: text-sm, brand-600 (visible only when items exist)
- List of pending items follows

### Recent transactions table

- Border: 1px border-subtle around the table
- Radius: radius-lg
- Header row: text-xs (12px), weight 500, text-tertiary, uppercase, tracked-out
- Data rows: text-sm (14px), weight 400, text-primary, height 48px
- Vertical dividers: none
- Horizontal divider between header and data: 1px border-subtle
- Horizontal divider between data rows: 1px border-subtle
- Hover state on row: bg-tertiary background

#### Columns
| Column | Alignment | Width |
|--------|-----------|-------|
| Customer | left | flex (takes remaining) |
| Amount | right | 120px (tabular-nums) |
| Status | left | 100px |
| Date | right | 100px |

#### Status cell
- Badge format (small pill)
- Icon (16px) + text
- Variants:
  - Paid: success-50 bg, success-700 text, check icon
  - Pending: warning-50 bg, warning-700 text, clock icon
  - Failed: danger-50 bg, danger-700 text, alert-circle icon

### Pending actions list

- Background: bg-secondary
- Border: 1px border-subtle
- Radius: radius-lg
- Padding: space-4

#### Each item
- Layout: flex, items-start, gap space-3
- Icon: 24px, semantic-colored (warning-500 for warnings, danger-500 for errors)
- Content:
  - Title: text-sm (14px), weight 500, text-primary
  - Description: text-xs (12px), weight 400, text-secondary
  - Timestamp: text-xs, text-tertiary
- Action button: text-xs (12px), weight 500, brand-600 — at end of item

#### Item dividers
- 1px border-subtle between items
- Padding-y space-3 within each item

### Empty state (no pending actions)

- Single centered message: "All caught up." — text-sm, text-secondary
- Subtle check icon (16px, success-500) before text
- Padding: space-8 vertical

### States

#### Default loaded (above)

#### Loading (initial)
- Each region shows skeleton screens:
  - Metric tiles: rectangular placeholder for value; smaller for label and delta
  - Transactions table: 5 skeleton rows
  - Pending list: 3 skeleton items

#### Loading (background refresh)
- "Last updated" subtitle pulses subtly (opacity 0.5 → 1 over 600ms)
- Refresh button shows spinner replacing icon
- Existing data remains visible (don't replace with skeleton)

#### Stale data (refresh failed > 90s ago)
- "Last updated" subtitle becomes warning-700 (more prominent)
- Banner above page header: "Connection issue. Showing data as of {time}." — bg-warning-50, text-warning-700, padding space-3, full width
- Refresh button continues to retry on click

#### Error (initial load failed)
- Replaces page content with:
  - Centered error block: warning-triangle icon (32px, danger-500)
  - Heading: "Couldn't load dashboard" — text-xl, weight 500
  - Body: "This usually resolves itself; please try again."
  - Buttons: "Try again" (primary) + "Contact support" (secondary)

#### Empty (account is brand new, no data)
- Each region's empty state:
  - Metrics: show "—" instead of zero values; subtitle "No data yet"
  - Transactions: "No transactions yet. Once you receive a payment, it'll appear here."
  - Pending: handled by default empty state above

## Interaction spec

### Auto-refresh
- Trigger: 60s timer (resets on tab focus / blur as appropriate)
- Behavior: incremental fetch; updates data in place; no skeleton on background refresh
- Indication: "Last updated: {time}" updates; button shows spinner briefly

### Manual refresh
- Trigger: click "Refresh" button
- Behavior: same as auto-refresh; immediate
- Disabled state during fetch (button is disabled + shows spinner)

### Tab focus
- When user returns to tab after >60s away: auto-refresh fires immediately

### Row click (transactions)
- Click a transaction row navigates to that transaction's detail page
- Hover state shows clickable affordance (bg-tertiary)
- Cursor: pointer

### Pending action click
- Click an action button or item navigates to the action's resolution flow
- Item is removed from pending list once acted on

### "View all" link
- Navigates to full transactions page with no filter applied

### Keyboard
- Tab order: header buttons → metric tiles (each tile's "details" button if present) → transaction rows → "view all" link → pending items → action buttons
- Enter on a transaction row: navigate
- Refresh button: standard button activation (Enter, Space)

## Accessibility spec

### Semantic HTML
- Page heading: `<h1>` for "Billing dashboard"
- Region headings: `<h2>` for "Recent transactions" and "Pending actions"
- Table for transactions: real `<table>` element with `<thead>`, `<tbody>`, `<th>`, `<td>`
- Pending actions: `<ul>` with `<li>` per item

### ARIA
- Each region wrapped in `<section>` with `aria-labelledby` pointing to its heading
- Last-updated timestamp announced via `aria-live="polite"` (so screen readers note refreshes without interrupting)
- Status badges: `aria-label="Paid"` (the visible icon+text combo speaks for itself; aria-label is fallback for icon-only contexts)
- Table column headers properly scoped: `<th scope="col">`

### Contrast
- text-primary on bg-secondary: 12.1:1 (AAA)
- text-secondary on bg-secondary: 7.8:1 (AAA)
- text-tertiary on bg-secondary: 4.6:1 (AA — body)
- success-700 on success-50 (paid badge): verified 7.2:1 (AAA)
- warning-700 on warning-50: verified 6.4:1 (AAA)
- danger-700 on danger-50: verified 8.1:1 (AAA)
- brand-600 on bg-secondary (links): verified 5.9:1 (AA-large, AAA-large)

### Touch targets
- Not a primary mobile target; minimum 32x32 acceptable for desktop UI
- Refresh button: 32x32 minimum (icon button has 16px icon + space-2 padding = 32px)
- Row click: full row is clickable; 48px tall ensures comfortable click target
- "View all" / link buttons: text + space-2 padding for 32px+ height

### Tabular numbers
- All metric values use `font-feature-settings: "tnum"` for aligned digits
- All amount cells in transactions table use `tnum`

### Reduced motion
- "Last updated" pulse: replaced with static appearance
- No animation on data updates (incremental updates already use cross-fade; replaced with instant)
- Loading skeletons: pulse animation removed; static placeholder shapes only

<!-- design-spec-end -->
```

## Phase 4 — Self-test

```markdown
# Self-test record — issue #402 (design pencil-spec)

## Acceptance criteria
- [x] AC #1: 4 metric tiles for MRR / ARR / active subs / churn
- [x] AC #2: 7-day transactions list (table)
- [x] AC #3: pending actions list
- [x] AC #4: auto-refresh every 60s + manual refresh; states for stale data
- [x] AC #5: 1024px+ usable; layout adapts at <1280px

## Spec sections present
- [x] Visual spec
- [x] Interaction spec
- [x] Accessibility spec

## Foundations consulted
- aesthetic-direction.md
- typography.md (tabular-nums for amounts)
- color.md (semantic colors for status)
- hierarchy.md (page title primary; metric values secondary; data tertiary)
- layout-and-grid.md (12-col grid; sidebar layout)
- patterns/data-display.md (table + list)
- patterns/feedback-states.md (loading skeletons, empty, error, stale)
- patterns/responsive-and-density.md (1024 vs 1280 layout)

## Existing patterns referenced
- /apps/billing/customers (overall dashboard layout)
- MetricTile component (metric tile structure)

## Validators
- spec-completeness: pass

## Ready for review: yes
```

## What this case demonstrates

- **Multi-region screen needs hierarchy**: page title is primary; metric values second; transactions third. Hierarchy.md applied.
- **Tabular-nums in spec**: not just "use tabular numbers" but explicitly cite `font-feature-settings: "tnum"`
- **Multiple states per region**: each region (metrics, transactions, pending) has loading / empty / error / stale states. The spec enumerates all.
- **Live updates handled deliberately**: auto-refresh isn't an afterthought; the stale data case is specifically designed
- **Responsive at admin viewport**: 1024px is the minimum; 1280px is the comfortable target. Layout adapts; mobile-out-of-scope is explicit.
