# Rule — Schema Compliance

The advice comment is mechanically validated. Format violations cause `actions/respond.sh` to refuse posting.

## The exact schema

```markdown
## Advice from design-advisor

### Existing constraints
- {bullet}

### Suggested approach
- {bullet}

### Conflicts with request
- {bullet}
(or single line: "none")

### Estimated scope
- {S | M | L | L+} — {N new patterns / M tokens / Y components}

### Risks
- {bullet}

### Drift noticed
- {bullet}
(or single line: "none")
```

## What the validator checks

`validate/advice-format.sh --role design-advisor`:

1. First non-empty line is exactly `## Advice from design-advisor`
2. All six required `### ` sections present
3. Each section has at least one non-empty content line
4. Estimated scope contains S, M, L, or L+

## Sections in detail (design specifics)

### Existing constraints

Cite locations:

```
- Aesthetic direction: refined utilitarian, restrained palette
  (_shared/design-foundations/aesthetic-direction.md, last updated 
  2024-08; codebase still aligns with this direction in primary 
  product surfaces)
- Type scale: Major Third, 12 / 14 / 16 / 18 / 23 / 29 / 36 / 45px
  (_shared/design-foundations/typography.md)
- Color tokens: 9-stop neutral ramp + brand-blue + 4 semantic colors;
  dark mode tokens defined for all (verified: tokens.json)
- Existing patterns documented: forms, data-display, navigation, 
  feedback-states, modals-and-overlays, responsive-and-density
  (skills/design/patterns/, 6 patterns)
- Form pattern: established in 12 places across the product 
  (verified: grep "<form" components/ | wc -l → 12)
- Modal pattern: established with focus trap, escape handling, 
  body scroll lock; used by 18 surfaces (grep <Modal/ → 18)
- Mobile-first: established practice; touch targets ≥44px 
  consistently in established components (sampled 5 components)
```

### Suggested approach

Direction with rationale; reference patterns rather than draft specs:

```
- This request fits the existing form pattern (skills/design/patterns/forms.md). 
  No new pattern needed. Mode A spec authoring follows the existing 
  pattern's three sections.
- The "step indicator" element is novel; not in the existing pattern 
  catalog. Recommend either (a) introducing as a small pattern in 
  patterns/forms.md (extends an existing file), or (b) treating as 
  a one-off internal component just for this surface (cheaper, less 
  reusable).
- Mobile behavior: aligns with the responsive-and-density pattern; 
  full-screen mobile, centered card desktop is well-established 
  (existing onboarding flow uses same shape).
```

### Conflicts with request

Be specific about design-system conflicts:

```
- Request says "use vibrant gradients in the hero section". Aesthetic 
  direction (aesthetic-direction.md) is "refined utilitarian, restrained 
  palette". Vibrant gradients depart from this direction. Either:
  (a) update the aesthetic direction (system-level decision; not a 
  one-off spec change), (b) make this surface a deliberate exception 
  with documented rationale, or (c) reinterpret "vibrant" within 
  the existing palette (e.g., bolder use of brand-blue without gradients).
- Request implies a new spacing scale stop (14px). The current scale 
  starts at 12px and skips to 16px; 14px is off-scale. Adding it is 
  a system-level change; using existing 12px or 16px keeps the system 
  intact. See _shared/design-foundations/space-and-rhythm.md.
- Request implies color-only encoding for status (red/green/gray). 
  This fails WCAG 1.4.1 Use of Color. Spec must include a non-color 
  signal (icon or text). This is a hard floor, not a preference.
```

If genuinely no conflicts:

```
- none
```

### Estimated scope

Includes new patterns + new tokens + components:

```
- M — 1 new component, 0 new patterns, 0 new tokens:
  - 1 new ProgressBar component (extends bar primitive used in 
    upload widget)
  - Reuses existing color, type, spacing tokens
  - No new pattern document needed; fits feedback-states pattern
```

If L+, decompose:

```
- L+ — request implies "introduce dark mode across product". This requires:
  1. Define dark-mode token mappings (~30 token additions)
  2. Update each component to consume tokens correctly (~80 components)
  3. Add toggle UI (1 new component)
  4. Update marketing surfaces (~15 surfaces, each with custom styling)
  5. QA across all surfaces in dark mode
  Strongly suggest decomposing — each step is M.
```

### Risks

Design-specific failure modes:

```
- Pattern fragmentation: introducing a one-off form pattern for this 
  surface diverges from the established form pattern. If other surfaces 
  later copy this one-off, fragmentation accelerates.
- Accessibility floor: request's interaction model (drag-only) doesn't 
  meet keyboard accessibility (WCAG 2.1.1). Must include keyboard 
  alternative; recommend arrow-key + space-to-confirm.
- Aesthetic drift: small accumulated departures from aesthetic-direction.md 
  add up; this single surface is borderline acceptable, but worth flagging 
  as the third recent surface with similar departures.
- Cross-surface inconsistency: this design choice will be visible 
  alongside the existing dashboard; users will notice if styles diverge. 
  Recommend matching key tokens (radius, padding, type) even if the 
  layout differs.
- Mobile compromise: the "dense table" interaction pattern doesn't 
  translate to mobile. The spec needs an explicit mobile alternative 
  (stack into cards, or dedicated mobile UI), not just "responsive 
  table".
```

### Drift noticed

```
- _shared/design-foundations/aesthetic-direction.md updated 2024-08; 
  recent landing pages have heavier animations and gradients than 
  documented direction. Drift between docs and code.
- 3 hex codes hardcoded in components/marketing/Hero.tsx that should 
  be tokens (verified: grep #[0-9a-f] components/marketing/ → 3 matches).
  These predate the token system rollout; could be cleanup.
- skills/design/patterns/forms.md describes a single-step form 
  pattern; the codebase has 2 multi-step flows (onboarding, checkout) 
  that aren't documented as a separate pattern. Worth documenting.
```

## Common violations

- **Spec-like content under "Suggested approach"** — listing exact px / colors / fonts is a Mode A spec, not advice
- **Wrong header level** — `# Advice from design-advisor` instead of `## `
- **Wrong header role** — `## Advice from design` (the implementer) confused with `design-advisor`
- **Missing section** — skipping "Drift noticed"; even then write `- none`
- **Empty section**
- **Wrong section names**
- **Scope without S/M/L/L+**
- **Adding extra sections**

## Quick checklist

Before running `respond.sh`:

- [ ] Header is exactly `## Advice from design-advisor`
- [ ] All six required sections with exact wording
- [ ] Every section has at least one bullet (or `- none`)
- [ ] Estimated scope contains S, M, L, or L+
- [ ] No spec-like content (px values, exact colors, exact font sizes) — that's Mode A territory
- [ ] No extra sections
