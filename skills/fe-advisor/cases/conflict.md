# Case — Conflict with Shipped Pattern

A request that, taken at face value, would contradict an existing established pattern. fe-advisor's job is to surface the contradiction clearly and propose alternatives — not to silently override the request, and not to silently violate the pattern.

## The consultation

Parent issue #501: "Add a sidebar to the customer detail page showing recent activity. The sidebar should be persistent (always visible while the page is open)."

arch-shape opened consultation #502 with:

```
- Does this fit the customer detail page's current layout?
- What in our patterns supports / conflicts with persistent sidebars?
- Roughly how many files would change?
```

## Phase 1 — Investigate

```bash
# Customer detail page
find apps -path "*customers*" -name "*Detail*"
# → apps/customers/CustomerDetail.tsx

# Current layout
head -50 apps/customers/CustomerDetail.tsx
# → uses standard <PageContainer> + <PageHeader> + <PageContent>
# → no sidebar

# Other pages with sidebars?
git grep -l "Sidebar\|<aside" apps/
# → apps/admin/AdminLayout.tsx — global navigation sidebar
# → apps/docs/DocLayout.tsx — TOC sidebar
# → no per-page sidebars within main app

# How are detail pages structured generally?
ls apps/*/components/*Detail*
# → 7 detail pages: customers, orders, invoices, products, users, refunds, disputes
# → all use PageContainer + PageHeader + tabs pattern
# → none have sidebars

# What's the "tabs pattern" for detail pages?
cat apps/orders/OrderDetail.tsx
# → <PageContainer> + <PageHeader title actions> + <Tabs items=[...]>
# → activity, edit, history are tab content
```

## Phase 2 — The conflict

The proposed sidebar contradicts the shipped detail-page pattern:

- All 7 detail pages use the same shape (header + tabs)
- Activity is conventionally a tab, not a sidebar
- No detail page in the product has a sidebar
- Adding one to customer-detail makes it visually distinct from the other 6

The agent sees three paths:

1. Build the sidebar as requested (accept inconsistency)
2. Build activity as a tab (existing pattern, less prominent)
3. Build a "split view" — main + side panel — as a new pattern, expecting other detail pages to adopt later

## Phase 3 — Compose response

```markdown
## Advice from fe-advisor

### Existing constraints

- Customer detail page (apps/customers/CustomerDetail.tsx) uses the same
  layout pattern as all 6 other detail pages: PageContainer + PageHeader +
  Tabs. The Tabs component is consumed by 7 pages with consistent styling.
- No detail page in the application has a per-page sidebar. The only
  sidebars in the app are:
  - apps/admin/AdminLayout.tsx — global admin nav (top-level layout)
  - apps/docs/DocLayout.tsx — table of contents in docs pages
- Activity feed already exists as a Tab on every detail page that has
  one (verified: orders, invoices, customers all have an "Activity" tab
  with the same component).
- The Activity tab uses components/activity/ActivityFeed.tsx, which is
  the canonical activity display.

### Suggested approach

The request as written conflicts with the shipped detail-page pattern.
Three options:

- **A) Promote Activity to a sidebar on customer-detail only** (as
  literally requested). One-off. Visually breaks consistency with the
  other 6 detail pages.
- **B) Keep Activity as a tab; investigate why the request was made**.
  Often "make it persistent" reflects an underlying need: maybe the user
  wants to reference activity *while editing* on another tab. If that's
  the real need, the solution is "make tabs not lose state" or "add
  inline activity preview to the edit tab", not a sidebar.
- **C) Introduce a "detail with side panel" layout as a new pattern**.
  Build the side panel for customer-detail; document it as a pattern
  other detail pages can adopt selectively. Larger but consistent.

Recommend **B as the first move**: clarify with the requester what task
prompts the request. If it's truly "I want activity persistent while
working in other tabs", option C may be right. If it's "I want activity
to feel more present", option B (Activity as default tab on load) may
be enough.

### Conflicts with request

- The pattern conflict above is the main one. The request as literally
  read implies pattern fragmentation; fe-advisor recommends not
  fragmenting on this single page.
- If option C is chosen (new pattern), it's a multi-page decision worth
  arch-shape level alignment, not just one PR.

### Estimated scope

- For Option A (sidebar on customer-detail only): M — 4 files:
  CustomerDetail.tsx restructure, sidebar layout component, sidebar
  Activity wrapper, test updates
- For Option B (default Activity tab + investigate underlying need): S
  — 1 file change (CustomerDetail.tsx default tab); investigation has
  no FE cost
- For Option C (new "side panel" pattern adopted across detail pages):
  L — ~15 files: pattern component, customer-detail consumer, possibly
  retrofit on 1-2 other pages, documentation, tests; would also need
  design input (recommend design pencil-spec consultation)

### Risks

- Option A: pattern fragmentation is the kind of inconsistency users
  notice subliminally — "this page feels different" without articulating
  why. Low explicit cost; cumulative cost as more such one-offs land.
- Option C: introducing a new layout pattern is a big surface; if
  abandoned (other pages don't adopt it), customer-detail becomes the
  weird one.
- Option B (the recommended): risk is the requester pushes back saying
  "I really do want a sidebar". That conversation is worth having
  before commitment, not after.

### Drift noticed

- arch-ddd/bounded-contexts/customers.md doesn't describe the detail-page
  layout pattern; the consistency is in code but undocumented. Worth
  documenting at the layouts level (probably in arch-ddd/layouts.md or
  a frontend-patterns doc) regardless of which option is chosen.
```

## Phase 4 — Validate + post

```bash
bash actions/respond.sh \
  --issue 502 \
  --advice-file /tmp/advice-issue-502.md
```

## What this case demonstrates

- **Conflict surfaced clearly**: not "we shouldn't do this" but "this conflicts with X pattern, and here's what that costs"
- **Multiple options with trade-offs**: not just "do it the existing way"; presented all three honestly
- **Recommended option B (investigate first)**: the most common right move when there's a conflict — figure out the underlying need
- **Refused to silently accept**: the request might land as written if arch-shape decides; advisor's job was to make sure that decision is informed
- **Refused to silently override**: didn't unilaterally change the request to "make Activity the default tab"; that's still arch-shape's call
- **Cross-role flagging**: option C would warrant a design consultation; mentioned

## Key lessons for conflict consultations

1. Every claim of "this is shipped pattern" should be backed by greps showing how widely the pattern is used
2. The most valuable advice is sometimes "investigate before committing"; surfacing the underlying user need can change the question
3. Multiple options + trade-offs is more useful than "here's what I'd do"; arch-shape can pick based on broader context
4. Don't pretend pattern conflicts don't exist. Accumulated one-offs become technical debt nobody planned for.
5. When suggesting a new pattern (option C), make clear it's a multi-page commitment, not a single PR
