# Rule — Design System Awareness

Design decisions have unusual properties that don't appear in fe / be / ops:

- **Patterns are permanent**: once introduced, hard to remove without coordinated migration
- **Drift is silent**: hardcoded values and one-off styles don't break tests; they accumulate
- **Aesthetic direction is fragile**: small departures compound into a different aesthetic
- **Accessibility floor is non-negotiable**: AA is a floor, not a goal

design-advisor must surface these dimensions when the request implies them.

## Patterns vs one-offs

Every design decision is one of:

1. **Use existing pattern** — best default; preserves consistency
2. **Extend existing pattern** — moderate; documents a variant
3. **Introduce new pattern** — system-level commitment; heavy
4. **One-off** — surface-specific; doesn't aim to be reusable

Surface which category in the advice:

```markdown
### Suggested approach

- Recommended: Option 1 (use existing form pattern). Request fits 
  forms.md exactly; no extension needed.

OR

- Recommended: Option 3 (new "wizard" pattern). The codebase has no 
  multi-step form pattern. The request is the second multi-step flow 
  this quarter; rather than two one-offs, document a wizard pattern. 
  Adds 1 file to skills/design/patterns/, becomes the reference for 
  future multi-step flows.

OR

- Recommended: Option 4 (one-off for this surface). The marketing 
  splash page deliberately departs from product UI; it's appropriate 
  here. Don't document as a pattern; explicitly note it's a one-off 
  in the spec.
```

The framing matters because arch-shape's decomposition depends on which category the work is.

## Pattern fragmentation

When a one-off looks like a pattern departure, fragmentation accumulates:

- 1 surface with a slightly different button style: noise
- 5 surfaces with slightly different button styles: fragmentation; users notice
- 10 surfaces all slightly different: design system is dead

Surface fragmentation evidence in advice:

```markdown
### Risks

- Pattern fragmentation: this would be the third "list with inline 
  edit" variant in 6 months (transactions list, customers list, 
  now invoices). Each is slightly different. If we land this as a 
  fourth one-off, we should also schedule a "consolidate inline 
  edit pattern" task. Otherwise the fragmentation continues.
```

## Aesthetic direction adherence

Aesthetic direction (in `_shared/design-foundations/aesthetic-direction.md`) is:

- The committed visual character of the product
- A system-level decision, not per-surface
- Fragile (small departures compound)

When a request potentially departs:

```markdown
### Conflicts with request

- Aesthetic direction (aesthetic-direction.md) is "refined utilitarian, 
  restrained palette". Request's "playful illustrated empty states" 
  reads as departure. Three readings:
  (a) Aesthetic direction needs updating to allow this — 
      system-level decision; should be deliberate
  (b) This surface (marketing-style empty states) is a known 
      exception zone — needs documentation
  (c) The request should be reinterpreted within the existing 
      direction (e.g., "minimal hand-drawn line illustrations" 
      rather than "playful colorful")
- arch-shape should decide which framing applies; design-advisor 
  doesn't unilaterally adjust aesthetic direction.
```

## Token coverage

Tokens are the design system's vocabulary. When a request implies a value not in the vocabulary:

- **Adding a token is a system-level change** — affects future use
- **Using off-system value is drift** — accumulates if unchecked
- **Reinterpreting within existing tokens** is usually best

```markdown
### Conflicts with request

- Request implies a "softer" gray for backgrounds. Current neutral 
  ramp (tokens.json) has 9 stops. The request's implied color sits 
  between neutral-50 (#FAFAFA) and neutral-100 (#F5F5F5) — about 
  #F8F8F8. Three options:
  (a) Use neutral-100 (closest scale value); minor visual shift
  (b) Use neutral-50; lighter than implied
  (c) Add a new neutral-75 token; expands scale
- Recommend (a). Adding scale stops is system-level; not worth it 
  for one surface.
```

## Accessibility floor

WCAG 2.2 AA is a hard floor. design-advisor surfaces a11y conflicts as Critical, not as preference:

| Issue | Severity | Why |
|-------|----------|-----|
| Color contrast < 4.5:1 (text) | Critical | WCAG 1.4.3 |
| Color contrast < 3:1 (UI components) | Critical | WCAG 1.4.11 |
| Color-only state encoding | Critical | WCAG 1.4.1 |
| No keyboard alternative | Critical | WCAG 2.1.1 |
| Touch target < 24x24 | Critical | WCAG 2.5.8 |
| No focus visible | Critical | WCAG 2.4.7 |
| No reduced-motion handling | Major | not mandatory but expected |

When request conflicts with the floor:

```markdown
### Conflicts with request

- Request implies status indication via color only (red/green/gray). 
  This fails WCAG 2.2 SC 1.4.1 (Use of Color). Mode A spec must 
  include a non-color signal (text label, icon, or shape). This is 
  a hard requirement, not a design preference.
```

## System-level vs feature-level decisions

design-advisor categorises work:

- **System-level**: aesthetic direction, token additions, foundation changes, new patterns documented in patterns/
- **Feature-level**: applying existing system to a new surface; a one-off; a pattern variant

The categorisation matters because:

- System-level decisions need to be deliberate; arch-shape should know they're system-level
- Feature-level decisions can land in a single PR with one spec

Surface in the advice when the categorisation is ambiguous:

```markdown
### Suggested approach

- The request reads as a feature-level question ("design the new 
  invoice page") but contains a system-level component: "introduce 
  inline editing in tables" is a new pattern, not just an invoice 
  page feature. Recommend splitting into:
  1. System-level: introduce / document inline-edit-in-tables pattern (M)
  2. Feature-level: apply pattern to invoice page (S)
- Otherwise, the inline-edit pattern lands without documentation 
  and gets copied inconsistently to other tables.
```

## Cross-product consistency

Larger systems often have multiple "products" with implicit design direction:

- Storefront vs admin
- Marketing vs product
- Mobile app vs web

When a request crosses products:

```markdown
### Risks

- Cross-product impact: this affects both storefront and admin. 
  Storefront aesthetic is "consumer-friendly, generous whitespace"; 
  admin aesthetic is "data-dense, compact". A unified treatment 
  would compromise both. Recommend separate treatments per surface 
  with shared underlying logic.
```

## What to surface in advice

For requests with design system implications:

### In "Existing constraints"

- Documented direction + sample of code adherence
- Pattern catalog + relevant patterns
- Token coverage for the relevant axes
- A11y baseline in the affected area

### In "Suggested approach"

- Categorise: existing pattern / extension / new pattern / one-off
- Reference the system content the recommendation builds on
- Note token requirements (use existing, propose new)

### In "Conflicts with request"

- Aesthetic direction departures
- A11y floor violations (always Critical)
- Off-token values without justification
- Pattern fragmentation risk

### In "Risks"

- Pattern fragmentation
- Aesthetic drift
- A11y compromise
- Cross-product inconsistency
- Adoption cost for new patterns

## Anti-patterns

- **Treating all design decisions as preference** — some are floors (a11y) or system commitments (patterns)
- **Ignoring documented direction** — direction exists for a reason; departures should be deliberate
- **Conflating one-off with pattern** — one-off is fine; pretending it's not (or pretending an emerging pattern is "just a one-off") is harmful
- **Off-system values without flag** — drift compounds silently
- **Approving a11y violations as "we'll add it later"** — a11y isn't deferrable

## Quick checklist

For any design-touching request:

- [ ] Categorised: existing pattern / extension / new pattern / one-off
- [ ] Checked aesthetic-direction adherence
- [ ] Checked token coverage for implied values
- [ ] Verified a11y floor (contrast, keyboard, color-coding, touch targets)
- [ ] Surfaced fragmentation risk if applicable
- [ ] Flagged system-level vs feature-level mix if applicable
- [ ] Considered cross-product consistency if relevant
