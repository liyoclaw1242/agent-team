# Rule — Domain Alignment

BE code uses domain terms exactly as defined in `arch-ddd/glossary.md`. Drift between code, schema, contract, and glossary is a bug that gets reported, not silently corrected.

## What this means in practice

### Schema column names

If glossary entry is `Cargo.trackingId`, then the database column is `tracking_id` (or `trackingId` depending on team convention) — but the conceptual identity is preserved. Don't rename to `pkg_id` or `ref_code` in the schema.

When schema names differ from glossary names due to legacy:

- The BE code's exposed contract (API field names) follows glossary, with mapping in the persistence layer
- Mark the legacy schema name as a known deviation in arch-ddd or in the codebase comment
- Plan a rename if it's worth the cost

### Type / struct names

```go
// Per glossary: "Cargo"
type Cargo struct {
    TrackingID  TrackingID
    Origin      Location
    Destination Location
    Itinerary   *Itinerary
}
```

Not `Shipment`, `Package`, `Parcel`. The glossary says Cargo; the type is Cargo.

### API field names

The contract block in the issue body uses glossary names:

```
Success: 200 {effectiveDate: ISO8601}
```

Not `effective_at`, `effectAt`, `effDt`. The field name is `effectiveDate` because glossary says so.

Wire format conventions (camelCase / snake_case) are project-wide; the **conceptual identity** is what matters across the wire / glossary / code.

### Enum values

Glossary may define value sets. Use them verbatim:

- Glossary: `RoutingStatus = NOT_ROUTED | ROUTED | MISROUTED`
- DB enum: those exact strings
- API string: those exact strings
- Go const: `RoutingStatusNotRouted`, `RoutingStatusRouted`, `RoutingStatusMisrouted`

If you find yourself wanting `Pending`, `Done`, `Failed` because they're "more familiar" — drift creeping in. Use glossary.

### Bounded context names

Code is organised by bounded context:

```
src/
├── booking/        # arch-ddd/bounded-contexts/booking.md
├── routing/
├── handling/
└── tracking/
```

Folder names match context names. Cross-context calls go through documented interfaces (events per service-chain.mermaid, or context-specific facade APIs).

## What to do when you observe drift

Three sub-cases:

### Sub-case 1: minor drift, not in your task's scope

Note in PR description and Mode C informational comment. Don't unilaterally fix; flag for arch.

### Sub-case 2: drift directly affects your task

Real Mode C. `workflow/feedback.md`'s `code-conflict` or `service-chain-drift` category fits.

### Sub-case 3: glossary lags reality

Sometimes the codebase uses a term that's *better* than glossary's; the glossary is out of date.

Examples:
- Glossary says `Cancellation`; codebase has standardised on `Termination` everywhere
- Glossary says `Subscription`; codebase has `Membership` because of a product pivot

Even here, **don't update glossary yourself**. Mode C with the observation; arch-feedback updates glossary.

## Special concern: schema legacy

Sometimes the legacy schema diverges from glossary in ways that are too expensive to fix:

- Column name was `subscription_state` for years; renaming is multi-phase migration
- A whole table is named per a deprecated concept

The pragmatic approach:

1. Note the deviation in `arch-ddd` (e.g., a "Schema deviations" section in the bounded context doc)
2. New columns follow glossary
3. Existing columns are not renamed unless the rename has independent justification

This is **knowingly accepted drift** — different from invisible drift. The rule is about silent inconsistency, not deliberate exception.

## Anti-patterns

- **Translating field names at the API layer** — `db.subscription_state` → contract's `state` field — the layers should match where it's cheap
- **Inventing new terms because they "feel cleaner" in code** — `Booking → Reservation`. Names communicate.
- **Letting "internal" names diverge — "we'll just call it X internally"** — internal ≠ private; reviewers and future readers see internal too
- **Silently fixing minor casing issues in DB / code** — flag, don't unilaterally fix

## Why it matters more for BE than FE

FE drift is contained to the UI layer; if FE calls a thing `cancelReason` instead of `cancellationReason`, the cost is some confusion in code review.

BE drift propagates: schema → query → return shape → contract → FE → display. Drift here pollutes every consumer.

That's why BE's domain-alignment rule has the higher bar of "schema legacy is acknowledged in arch-ddd, not silently tolerated".
