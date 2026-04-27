# Rule — Scope Honesty

The S/M/L estimate is the most consequential part of the advice. arch-shape uses it to decide whether to decompose further. An estimate wrong by 3-5x leads to wrong decompositions and rework cycles.

## The S/M/L scale (design)

For design, "scope" is patterns + tokens + components + spec authoring rounds:

- **S (Small)**: 0 new patterns, 0 new tokens, 1 new component (or extending existing). One pencil-spec covers it. No system-level changes.
- **M (Medium)**: 0-1 new pattern, 1-3 new tokens, 2-5 new components. May need 2 pencil-specs if multi-surface.
- **L (Large)**: 1-2 new patterns, 4-10 new tokens, 6+ new components. Multiple specs across surfaces; possibly cross-surface alignment.
- **L+ (Beyond Large)**: introduces a system-level change (new aesthetic direction, dark mode, multi-brand support, design-language overhaul). **Should be decomposed at the arch-shape level**.

A new pattern is the heaviest single dimension — it's a permanent system commitment.

If L+, say so explicitly:

```markdown
### Estimated scope

- L+ — request to "add dark mode across product" would:
  - 30 new dark-mode token mappings
  - ~80 components verified for dark mode
  - 1 new toggle component + persistence
  - QA across all surfaces
  - Updates to aesthetic-direction.md acknowledging dark mode
  - 4-6 pencil-specs for non-trivial surfaces (settings page, modal 
    variants, charts)
  Strongly suggest decomposing — each step is M. Order matters: 
  tokens first, then component verification in batches.
```

## How to estimate

The estimate is grep-driven, not vibe-driven.

### Step 1: Identify what's new

What of these does the request introduce?

- New pattern (e.g., never had a tabs pattern; now we do)
- New token category (e.g., never had motion tokens; now we do)
- New component (e.g., we have Card; now we need ProductCard)
- New surface (e.g., settings page never existed; now we have one)
- New variant (e.g., destructive button variant where only primary existed)

Each has different scope weight:

- **New pattern**: heavy. Documents a permanent system commitment. M+ minimum.
- **New token category**: moderate. Adds vocabulary to the system. M.
- **New component**: light if extending pattern (S). Heavy if novel pattern (M+).
- **New surface**: depends on how much it reuses. S to L.
- **New variant**: light (S to M).

### Step 2: Count touched components

For requests that affect many surfaces:

```bash
# How many surfaces would consume this?
grep -rl "<Form" apps/   # 12 surfaces use forms
grep -rl "<Modal" apps/  # 18 surfaces use modals
```

A change touching all forms is M-L; touching all modals is L (more surfaces, higher visual prominence).

### Step 3: Count specs needed

Each unique surface usually needs its own pencil-spec. If the pattern is well-defined, specs can be near-template ("uses card pattern; copy spec from billing-card"). If it's novel, each spec is full work.

```
For a feature with 3 distinct surfaces (list, detail, edit):
- If all use existing patterns: 3 specs, mostly template-fill
- If one introduces a new pattern: ~1.5x effort
- If all three are novel: ~3x effort + pattern documentation
```

### Step 4: Sum + factor

```
Modified: 0 patterns
Added: 0 patterns (uses existing card + form patterns), 1 component variant 
       (filled-only "destructive" button), 0 tokens
Components: 1 new component (DangerConfirmDialog)
Specs: 1 spec covers all uses
Cross-surface impact: 1 (new dialog appears only in delete-account flow)
= S
```

Round up if uncertain.

## Design-specific bias traps

### Underestimating new patterns

Adding a pattern feels light ("just a markdown file"). Real cost:
- Document the pattern (1 file)
- Implement the pattern's components (varies)
- Update other patterns if they relate
- Communicate the pattern to fe team
- Pattern adoption takes time; first 3-5 surfaces are reference

A pattern is M minimum; often L because of adoption cost.

### Underestimating dark mode / theming

Token swaps look mechanical. Real cost includes verifying every component visually, fixing drift (hardcoded values), handling images / icons that may need theme-aware versions. L+ unless surgical.

### Underestimating cross-product consistency

When a request affects both storefront (consumer) and admin (internal) surfaces, coordinating across two implicit design directions is heavier than either alone. M to L.

### Underestimating accessibility upgrades

"Make it accessible" can be S (add aria-label) or L+ (rebuild interaction model). The scope depends entirely on the existing baseline. Inspect first.

## When the request is vague

If the request says "improve the design quality" and you can't tell what's meant:

```markdown
### Estimated scope

- Cannot estimate without clarification. Range:
  - "Polish a single surface" (apply existing patterns better): S
  - "Refresh primary surfaces": M-L
  - "Design language overhaul": L+
  Suggest arch-shape narrow the request before scope estimation.
```

## Calibration

After several consultations, check estimates against actual rounds. If your M estimates routinely require 2+ rounds of feedback, recalibrate. Note in journal.

## Anti-patterns

- **"Just a small visual tweak"** — visual tweaks accumulate; tweaks across surfaces compound
- **"Just one new component"** — a component without a pattern is a one-off; pattern + component is more
- **Defaulting to M** for everything
- **Ignoring spec authoring effort** — even small specs take time to write well
- **Estimating only the "design work"** — also count token additions, foundation updates, communication
- **Hand-waving over a11y rework** — a11y issues found in advice can be the scope-driver

## Quick checklist

- [ ] Counted new patterns, tokens, components introduced
- [ ] Counted touched surfaces
- [ ] Considered spec authoring count (one per surface)
- [ ] Considered cross-product coordination if applicable
- [ ] Marked L+ if applicable, with decomposition suggestion
- [ ] Gave a range with named scenarios if request is vague
