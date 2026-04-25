# Rule — Domain Alignment

FE code uses domain terms exactly as defined in `arch-ddd/glossary.md`. Drift between code and glossary is a bug that gets reported, not silently corrected.

## What this means in practice

### Variable names

If the glossary entry is `Cargo` (capitalised, singular), then:

- Type / interface name: `Cargo`
- Variable holding one: `cargo` (camelCase singular)
- Variable holding many: `cargos` or `cargoList` (NOT `shipments`, `packages`, `items`)

If the glossary entry is `TrackingId`:

- Type: `TrackingId`
- Variable: `trackingId` (NOT `id`, `code`, `ref`)

Names from the glossary travel from arch-ddd → BE schema → API field → FE prop unchanged. This is the ubiquitous-language rule from DDD; FE is one of the destinations.

### Component names

When a component represents a glossary concept, its name uses the glossary spelling:

- `<CargoCard />` (NOT `<ShipmentCard />`)
- `<TrackingDisplay />` (NOT `<PackageStatus />`)

If you find yourself wanting a different name "because it reads better in code", that's drift creeping in. The glossary is the source; mismatch is a fix-the-glossary or fix-the-code action, not "let it be".

### Status / enum values

Glossary may define enum values. Use them verbatim:

- Glossary says `RoutingStatus` has `NOT_ROUTED | ROUTED | MISROUTED` → API returns those exact strings → FE branches on those exact strings, not on `'pending'` / `'done'` / `'failed'`.

If the API returns different strings than the glossary, that's a BE bug to file, not an FE adapter to write.

## What to do when you observe drift

You're reading code while implementing and notice the codebase already uses different names than the glossary. Three cases:

### Case 1: minor drift, your task doesn't touch it

Note in your PR description: "Observed: `glossary.md` says X but `src/Y.tsx` calls it Z. Out of scope for this PR; flagging via Mode C feedback comment."

Then post a small Mode C comment on the issue:

```markdown
## Technical Feedback from fe

### Concern category
drift-noticed (informational, not blocking this task)

### What's drifted
glossary.md "Cargo" vs src/components/ShipmentCard.tsx (uses "Shipment").

### Suggested follow-up
File a refactor task in arch-shape to rename either the glossary or the
component to align. I'm proceeding with this task using glossary terminology
in new code.
```

This is informational; you don't route the issue back. Just leaves a record for arch.

### Case 2: drift directly affects your task

The spec uses glossary term but the code uses drift term. You can't implement faithfully without reconciling.

This is real Mode C: route back to arch-feedback per `workflow/feedback.md`, with `Drift noticed` populated.

### Case 3: glossary is wrong, codebase is right

Sometimes the glossary lags behind genuine evolution in the codebase. You can tell when:

- Multiple files use the codebase term consistently
- Recent commits adopted the new term
- The codebase term genuinely better describes the concept

Even here, **don't update glossary yourself**. arch-feedback will handle that as part of accepting your feedback. Your job is to flag.

## Anti-patterns

- **"Translating" terms in your component code** — `interface CargoProps { tracking_id: string; }` then internally `const ref = props.tracking_id; ...` to use `ref` everywhere. Don't. Use the glossary term throughout.
- **Inventing new terms because they "feel cleaner"** — `Booking → Reservation`, `Itinerary → Plan`. Names communicate; deviating from glossary obscures.
- **Silently fixing minor casing inconsistencies** — even casing is part of the contract. `trackingId` ≠ `trackingID`. If you notice inconsistency, flag.

## Why it matters

Domain alignment isn't pedantic. The reasons:

1. **Future searchability**: when someone greps `Cargo` they should find every place involved with cargo. Drift fragments knowledge.
2. **Onboarding**: new team members read glossary then code. Drift makes the glossary lying.
3. **Cross-role consistency**: BE / FE / Design / QA all reference the same concepts. Each role inventing its own names is the path to confusion in design discussions and reviews.
