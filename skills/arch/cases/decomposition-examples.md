# Case: Decomposition Examples

Real examples of breaking requirements into atomic bounty tasks.

---

## Example 1: "Add dark mode support"

**Domain analysis**: Theme system, CSS variables, component styling, user preference storage.

**Decomposition**:

| # | Title | Type | Deps | Why this order |
|---|-------|------|------|----------------|
| 1 | Restructure ThemeConfig to support light/dark dual mode | be | — | Data model first |
| 2 | Restore dark: variant styles in shadcn/ui components | fe | — | Can parallel with #1 |
| 3 | Theme Editor: dual light/dark mode editing with toggle | fe | 1 | Needs new ThemeConfig |
| 4 | QA: Verify dark mode — toggle, dual theme, styles | qa | 1,2,3 | Verify after all done |

**Key decisions**:
- BE first for data model (ThemeConfig restructure)
- FE #2 can parallel because it's CSS-only, doesn't depend on new config
- FE #3 needs the new config shape → depends on #1
- QA last, depends on everything

---

## Example 2: "Add preset theme system with 42 themes"

**Domain analysis**: Theme data (presets), UI (selector), filtering (category/search).

**Decomposition**:

| # | Title | Type | Deps |
|---|-------|------|------|
| 1 | Import 42 tweakcn theme presets: convert format, add category tags | be | — |
| 2 | Theme Editor: preset selector with grid, category filter, search | fe | 1 |
| 3 | QA: Verify 42 presets load, category filter, search | qa | 1,2 |

**Key decisions**:
- Data transformation (BE) before UI (FE)
- Only 3 tasks, not 6 — kept it tight because each is well-scoped
- Didn't split FE into "grid" + "filter" + "search" — they're one feature

---

## Anti-patterns in Decomposition

| Pattern | Problem | Fix |
|---------|---------|-----|
| Over-splitting | 10 tasks for one feature → overhead, merge conflicts | Ask: "is this independently releasable?" If not, merge with neighbor |
| Under-splitting | 1 task that changes 20 files | Ask: "can I describe this in one PR title?" If not, split |
| Over-specifying how | "Use useState for X, useEffect for Y" | Specify what + done-when, not how |
| Missing QA | No verification task | Always add QA for testable deliverables |
| Wrong dependency order | FE before BE API exists | Data → API → UI → QA |
