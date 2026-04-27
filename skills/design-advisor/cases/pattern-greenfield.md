# Case — Pattern Greenfield

A request that, if implemented, would require a new pattern that doesn't exist in the system. design-advisor surfaces this as a system-level decision, not just feature work.

## The consultation

Parent issue #2010: "Add a comparison view where users can select 2-4 products and see specs side-by-side."

arch-shape opened consultation #2011 to design-advisor:

```
- Does our design system have a "comparison" pattern?
- What's the closest existing pattern?
- What's the cost of introducing this as a new pattern?
```

## Phase 1 — Investigate

```bash
# Existing patterns
ls skills/design/patterns/
# → forms, data-display, navigation, feedback-states, modals-and-overlays, responsive-and-density

# Closest pattern fit
cat skills/design/patterns/data-display.md | head -50
# → covers tables, lists, cards
# → mentions "comparison" briefly under tables ("comparing values across rows")
# → but not "side-by-side comparison of N products"

# Existing implementations
grep -rl "compare\|comparison" components/ apps/
# → no hits in code
# → product surfaces don't have any comparison UI today

# Closest visual analog
grep -rl "<Card.*Card.*Card" apps/  # multi-card grid
# → product listing pages use Card pattern (data-display.md)
# → but listings are 1-N, not "select 2-4 to compare"

# Pricing tables / plans
grep -rl "pricing\|plan" apps/marketing/
# → 1 pricing page (apps/marketing/pricing.tsx) has 3 plans side-by-side
# → uses bespoke layout, not a documented pattern

# Aesthetic direction
cat _shared/design-foundations/aesthetic-direction.md
# → "refined utilitarian, restrained palette, content-first"
# → comparison views often have heavy visual treatment; need to align

# Mobile considerations
cat skills/design/patterns/responsive-and-density.md | grep -A5 "tables don't shrink"
# → "Tables don't shrink well to mobile. Three approaches: ..."
# → comparison is similar; mobile is a known hard problem
```

## Phase 2 — Compose response

```markdown
## Advice from design-advisor

### Existing constraints

- Pattern catalog (skills/design/patterns/) has 6 patterns: forms, 
  data-display, navigation, feedback-states, modals-and-overlays, 
  responsive-and-density. None cover "side-by-side product comparison".
- Closest documented pattern is data-display.md (covers tables / 
  lists / cards). Tables briefly mention "comparison" in the context 
  of "comparing values across rows" — but that's table-row comparison, 
  not "select N items, see them as columns".
- No existing implementation of comparison UI in the product (verified: 
  grep "compare\|comparison" → 0 matches in components/ and apps/).
- One closest visual analog: pricing page (apps/marketing/pricing.tsx) 
  shows 3 plans side-by-side. This is a bespoke layout, not a 
  documented pattern. The "select N to compare" interaction model 
  doesn't exist there either.
- Aesthetic direction (aesthetic-direction.md) is "refined utilitarian, 
  restrained palette, content-first". Comparison views in many products 
  use heavy visual treatment (highlights, callouts, "best value" 
  badges); fitting the aesthetic requires deliberate restraint.
- Mobile: comparison is a known hard problem. Tables don't shrink well; 
  comparison views have the same property. responsive-and-density.md 
  documents 3 approaches for tables (horizontal scroll / stack-as-cards / 
  truncate); same approaches apply.

### Suggested approach

This is a system-level addition, not just a feature. Two framings:

- **A) Treat as a one-off (feature-level)**: build the comparison UI 
  bespoke for this surface; don't document as a pattern. Future 
  comparison needs would also be bespoke. Risk: pattern fragmentation 
  if more comparison features arrive.

- **B) Introduce as a new pattern (system-level)**: document the 
  pattern in skills/design/patterns/comparison.md with selection 
  model, layout shapes, mobile fallback, accessibility rules. Then 
  apply the pattern to the requested surface. More upfront work; 
  future comparison features have a reference.

Recommend **B** because:
- Comparison is a recognisable UI primitive that recurs in mature products
- The pricing page already implies a comparison-like layout; documenting 
  the pattern lets us bring pricing into the system retroactively
- A new pattern is M scope (the pattern doc + first implementation); 
  the marginal cost of doing it as pattern vs one-off is small

If the product roadmap doesn't include further comparison features, 
**A is acceptable** — but worth confirming with arch-shape that 
comparison won't recur.

For the new pattern's shape (architectural; not the spec):
- Selection model: explicit "Add to compare" interaction with a 
  comparison drawer (visible while browsing) → "View comparison" 
  expanding to full view. Drawer pattern from existing modals-and-overlays.
- Layout: column-per-product grid; 2-4 columns based on selection 
  count. Each column scrolls independently if content is long, OR 
  rows are aligned across columns (more readable for spec comparison).
- Mobile fallback: pick one (likely "stack as cards with anchor links 
  per row"; horizontal scroll works but loses comparison value)
- Accessibility: sticky row labels for screen readers; arrow-key 
  navigation between columns; comparison count announced

These are directional; the actual spec is design Mode A's job.

### Conflicts with request

- Request says "select 2-4 products" — the maximum (4) matters for 
  layout decisions. 2 is two columns; 4 is dense. Above 4 (e.g., 
  user wants 6) the pattern visibly fails. Need to enforce max=4 
  in the spec; surface this constraint in the new pattern doc.
- "Specs side-by-side" — what counts as "spec"? Image, name, price 
  are obvious. Description, features, dimensions, weight? Without 
  bounding the spec list, the comparison can become unwieldy. 
  Recommend defining a fixed spec set per category (electronics 
  shows X spec rows; apparel shows Y spec rows).
- Aesthetic alignment risk: comparison UIs typically use color 
  highlights, "best value" badges, etc. These read as "marketing-y". 
  The product's aesthetic is restrained. Recommend the pattern 
  enforce restraint (no badges, no color-coded callouts, no 
  promotional styling).

### Estimated scope

- M — introducing the pattern + implementing on one surface:
  - 1 new pattern document (skills/design/patterns/comparison.md, 
    ~150 lines like other patterns)
  - 1 pencil-spec for the comparison surface (Mode A)
  - 1 pencil-spec for the comparison drawer (separate or combined)
  - Possibly 1 new component (ComparisonView) — could be in fe scope 
    only, or could be reusable enough to live in components/ui/
  - 0 new tokens (existing should suffice)
  - 0 foundation updates (the pattern fits within existing 
    aesthetic-direction)
- If the request also implies comparison for the pricing page 
  (retroactive consolidation): L — additional spec + migration of 
  existing pricing layout to use the pattern.

### Risks

- Pattern fragmentation if Option A is chosen: future comparison 
  features land bespoke; system fragmentation grows.
- Aesthetic drift: "comparison" UI is a magnet for visual decoration 
  (highlights, badges, callouts). The pattern document must explicitly 
  forbid these to align with aesthetic direction. Without that, the 
  pattern devolves over time.
- Mobile fallback is a known compromise; users on mobile will have 
  a degraded comparison experience. Worth confirming the value of 
  comparison for mobile users (analytics?) before committing to 
  full mobile parity.
- Accessibility: comparison views are hard for screen readers (lots 
  of cross-cell context). The pattern doc should include explicit 
  a11y rules (semantic table-like structure, row labels announced 
  for each cell). Otherwise default implementation will fail.
- Adoption: the pattern's first use is the request; second use is 
  unknown. If second use never comes, the pattern doc is overhead. 
  Mitigate by writing the pattern doc lean — describe what's needed 
  for current use, not speculative future variants.

### Drift noticed

- pricing.tsx implements a side-by-side layout that should arguably 
  be the comparison pattern. It predates pattern documentation; this 
  is drift between code and pattern catalog. Worth noting (could be 
  consolidation work alongside this).
- skills/design/patterns/data-display.md briefly mentions 
  "comparison" but doesn't define the selection-and-compare 
  interaction; that minor mention will need updating once a real 
  comparison pattern exists (cross-reference).
- aesthetic-direction.md doesn't address marketing surfaces 
  explicitly; the pricing page's mild departures aren't documented 
  as exceptions. Worth aligning.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 2011 \
  --advice-file /tmp/advice-issue-2011.md
```

## What this case demonstrates

- **Confirmed pattern doesn't exist**: grep verified zero comparison code
- **Surfaced system-level vs feature-level decision**: a comparison feature is also a pattern decision
- **Two options with cost trade-off**: one-off vs pattern; recommended pattern with reasoning
- **Surfaced aesthetic risk**: comparison UI is a "decoration magnet"; pattern must enforce restraint
- **Mobile fallback acknowledged**: known hard problem; analytics-driven decision recommended
- **A11y considerations included**: comparison views are hard for screen readers
- **Drift identified**: existing pricing page is a latent example of the same pattern

## Key lessons for pattern-greenfield consultations

1. Verify pattern catalog absence with grep, not memory
2. Identify the closest existing pattern and explain why it's not enough
3. Frame as system-level vs feature-level explicitly; don't decide unilaterally
4. New patterns have aesthetic-direction implications; surface them
5. Mobile and a11y are first-class concerns for new patterns
6. Latent examples (existing bespoke implementations) are valuable evidence
7. Pattern doc effort isn't speculative ROI — write lean for current use, expand as second/third use emerges
