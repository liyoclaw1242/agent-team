# Case — Cross-Product Consistency

A request that affects multiple products with different implicit aesthetic / pattern conventions. design-advisor surfaces the tension between unification and divergence.

## The consultation

Parent issue #3010: "Add a notification center accessible from the top bar — same UX for both storefront (consumer) and admin (staff)."

arch-shape opened consultation #3011 to design-advisor:

```
- Do storefront and admin currently share design conventions?
- Should the notification center be unified or product-specific?
- What's the cost of each approach?
```

## Phase 1 — Investigate

```bash
# Are storefront and admin codebases separate?
ls apps/
# → apps/storefront, apps/admin (separate)

# Compare their styling
ls apps/storefront/src/styles/
ls apps/admin/src/styles/
# → both use same tokens.json (verified)
# → but different component variants

# Compare component usage
grep -rl "<Button" apps/storefront/ | wc -l
# → 47 uses
grep -rl "<Button" apps/admin/ | wc -l
# → 89 uses
# → admin is more component-heavy

# Component variants used
grep -oE "<Button [^>]*variant=\"[^\"]*\"" apps/storefront/ | sort -u | head
# → "primary", "secondary", "ghost"
grep -oE "<Button [^>]*variant=\"[^\"]*\"" apps/admin/ | sort -u | head
# → "primary", "secondary", "ghost", "destructive", "icon"
# → admin uses 5 variants, storefront uses 3

# Aesthetic direction differences?
ls _shared/design-foundations/
cat _shared/design-foundations/aesthetic-direction.md | head
# → single file; doesn't differentiate per product

# Density / spacing differences in practice
grep -rh "padding-y\|py-" apps/storefront/components/ | sort | uniq -c | sort -rn | head
# → storefront uses py-6, py-8, py-12 most (generous)
grep -rh "padding-y\|py-" apps/admin/components/ | sort | uniq -c | sort -rn | head
# → admin uses py-2, py-3, py-4 most (compact)
# → confirms density divergence in practice

# Existing top-bar pattern
grep -rl "TopBar\|top-bar\|navbar" apps/storefront/
grep -rl "TopBar\|top-bar\|navbar" apps/admin/
# → both have top bars; different components
# → apps/storefront/components/Header.tsx (consumer-style)
# → apps/admin/components/AppShell.tsx (admin-style with sidebar)

# Existing notification UI?
grep -rl "Notification\|Alert" apps/
# → apps/admin/components/AlertBanner.tsx (page-level alerts)
# → apps/storefront/components/Toast.tsx (toast notifications)
# → no unified notification center anywhere
```

## Phase 2 — Compose response

```markdown
## Advice from design-advisor

### Existing constraints

- Storefront and admin live in separate codebases (apps/storefront, 
  apps/admin) but share the same design tokens (tokens.json verified).
- Despite shared tokens, the two products have diverged in practice:
  - Component variant usage differs: admin uses 5 button variants 
    (primary, secondary, ghost, destructive, icon); storefront uses 
    3 (primary, secondary, ghost). Verified via grep.
  - Density differs: storefront uses py-6/py-8/py-12 most commonly 
    (generous); admin uses py-2/py-3/py-4 most commonly (compact).
  - Top-bar shapes differ: storefront has a marketing-style header 
    (apps/storefront/components/Header.tsx); admin has an app shell 
    with sidebar and slim top bar (apps/admin/components/AppShell.tsx).
- aesthetic-direction.md is a single file; doesn't differentiate 
  storefront from admin. The de-facto practice has differentiated, 
  but the documentation hasn't.
- No existing notification center pattern in either product. 
  Storefront has Toast (apps/storefront/components/Toast.tsx) for 
  ephemeral notifications; admin has AlertBanner 
  (apps/admin/components/AlertBanner.tsx) for page-level. Neither 
  is a "center" (collection / history view).

### Suggested approach

This consultation has three viable directions; the right one depends 
on a clarifying question about UX intent:

- **A) Unified notification center component**: same component used 
  in both products with internal density/styling props. Tokens are 
  shared; differences are accessed via props. Each product's top bar 
  consumes the same `<NotificationCenter>` with appropriate props.

- **B) Two separate notification centers, shared underlying data 
  layer**: each product has its own UI matching its density and 
  interaction conventions. Backend / state layer is shared 
  (notification list, mark-as-read, etc.). UI is bespoke per product.

- **C) Unified UI with per-product variants documented**: similar 
  to A, but the variants are first-class in the component (e.g., 
  `<NotificationCenter variant="storefront" />` vs `variant="admin" />`) 
  rather than implicit prop combinations.

Recommend **B** because:
- The two products have already diverged in density and conventions; 
  forcing a single component makes both compromise
- Storefront notifications likely include order updates, recommendations, 
  marketing messages — content-rich, narrative tone
- Admin notifications likely include alerts, system events, action 
  items — terse, actionable, possibly counted
- The interaction patterns naturally differ: storefront might prefer 
  a slide-in drawer; admin might prefer a popover anchored to the 
  bell icon
- Shared data layer captures the real coupling; UI divergence captures 
  the real difference

Direction A or C work if the team prefers code-sharing over UX fit. 
Both are viable; just costlier in the long term.

### Conflicts with request

- Request says "same UX". Investigation suggests "same UX" is the 
  wrong target — storefront and admin already differ in aesthetic 
  for good reasons. Recommend arch-shape clarify with requester:
  - "Same notification *content* across products" (yes; same data layer)
  - "Same notification *list* across products" (depends on user roles 
    overlapping; staff who use both would expect this)
  - "Same notification *UI* across products" (this is the 
    contentious one; investigation suggests it shouldn't be the goal)
- The request implicitly assumes the two products should converge. 
  This consultation argues they should remain divergent at the UI 
  level. arch-shape may have product-strategy reasons to push 
  unification; if so, that's a higher-order decision to surface 
  before this work proceeds.

### Estimated scope

- For Direction A (unified component): M-L:
  - 1 NotificationCenter component (shared)
  - 2 surface integrations (storefront top bar, admin top bar)
  - 1 spec covering the component
  - Likely 2-3 spec iterations as the two products' real needs surface
  - Effort estimate is mid-M to L because of coordination

- For Direction B (separate UIs, shared data): L (slightly larger):
  - 2 NotificationCenter components (storefront, admin)
  - 1 shared notification state / data layer (could live in 
    a shared lib)
  - 2 specs (one per product)
  - Each spec independent; less iteration coupling
  - Total cost similar but split cleaner

- For Direction C (variant-based unified): M-L; cost similar to A 
  but with explicit variant complexity in the component

### Risks

- Direction A: the two products' real needs will diverge over time; 
  the unified component accumulates conditional logic and becomes 
  the "weird shared component nobody owns". This is the classic 
  shared-component-rot pattern.
- Direction A: forcing density / pattern alignment compromises both. 
  Storefront feels too compact; admin feels too sparse.
- Direction B: data-layer drift over time if one product extends 
  notification semantics that the other doesn't need. Mitigate by 
  documenting the shared data contract.
- Direction B: communication coordination — when one team changes 
  notification behavior, the other team needs to know. Mitigate via 
  shared notification doc (arch-ddd or similar).
- All directions: the storefront and admin top-bar shapes don't 
  match. Wherever the bell icon + dropdown lives, it must visually 
  fit each top bar. This is per-product spec work regardless of 
  direction.
- Aesthetic direction: aesthetic-direction.md doesn't differentiate 
  storefront from admin, but practice has. Worth updating the doc 
  to reflect the de-facto divergence (low-priority but useful).

### Drift noticed

- aesthetic-direction.md (single file) doesn't reflect the storefront 
  vs admin divergence. The doc is stale; reality is that storefront 
  is "consumer-friendly, generous" and admin is "data-dense, compact".
  Worth documenting separately or as variants within the doc.
- skills/design/patterns/ has 6 patterns but doesn't address 
  per-product variants of the same pattern. The forms pattern, for 
  example, presents differently in storefront vs admin (signup flow 
  vs admin user-create); the pattern doc treats them as one. Drift 
  between pattern doc and practice.
- Component variant fragmentation: admin has "destructive" and 
  "icon" button variants that storefront doesn't. Either storefront 
  needs them (drift in the variant catalog) or admin shouldn't 
  (variant inflation). Worth a separate audit.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 3011 \
  --advice-file /tmp/advice-issue-3011.md
```

## What this case demonstrates

- **Surfaced the divergence with evidence**: density, variants, top-bar shapes — measured, not assumed
- **Pushed back on "same UX"**: the request's premise is wrong; surfaced the right interpretation
- **Three architectural directions**: each with cost / risk profile
- **Recommended Direction B** with reasoning rooted in current divergence patterns
- **Identified product-strategy gap**: this might be a higher-order question (should products converge?) than design-advisor can resolve
- **Multiple drifts found**: aesthetic-direction doesn't reflect divergence; pattern docs don't address variants; variant catalog inconsistencies

## Key lessons for cross-product consistency consultations

1. Measure divergence with evidence — variants, density, surface shapes
2. The request's premise ("same UX") is often the contentious thing; surface it
3. Three architectural directions covers most cases: unified, separate, unified-with-variants
4. The right direction depends on whether divergence is a feature or a bug; arch-shape decides
5. Shared data ≠ shared UI; surface this distinction
6. Multi-product systems accumulate quiet drift; consultation often surfaces broader cleanup opportunities
