# Bounded Context: Handling

Records the physical events that happen to cargo as it travels. Append-only event log; this context is the source of truth for what has actually happened.

## Aggregate roots

**HandlingEvent** — each event is itself the aggregate root. Events are immutable.

Holds:
- `TrackingId` (which cargo)
- `HandlingEventType` (RECEIVE / LOAD / UNLOAD / CUSTOMS / CLAIM)
- `Location` (where it happened)
- `VoyageNumber` (when applicable, for LOAD/UNLOAD)
- `completionTime` (when the action took place)
- `registrationTime` (when this event was recorded in the system)

## Operations

**Register handling event** (`HandlingEventService.registerHandlingEvent`)
Input: tracking id, event type, location, voyage (if applicable), completion time
Output: void
Side effects: validates and persists the event; publishes `HandlingEventRegistered` to the bus.

Validation includes:
- Tracking id refers to an existing cargo (anti-corruption call to Booking)
- LOAD/UNLOAD events require a voyage; CUSTOMS/CLAIM/RECEIVE don't
- Completion time is not in the future, registration time is now

## Invariants

- Events are immutable. Corrections are added as new events, not edits.
- A `CLAIM` event for a tracking id is terminal — subsequent events for that id are rejected.

## Why a separate context

In the original example, Handling is operated by a different team (port operators, customs agents) than Booking (sales/customer service). The model is different too: Handling cares about timestamps and ports; Booking cares about commitments and customers. Splitting them prevents either team's concerns from polluting the other's model.
