# Bounded Context: Booking

The customer-facing entry point. Owns the lifecycle of a `Cargo` from intent ("I want to ship X") to completion ("X has been claimed").

## Aggregate roots

**Cargo** — root of the booking aggregate. Holds:
- `TrackingId`
- `RouteSpecification` (origin, destination, deadline)
- `Itinerary` (assigned by Routing context, may be null until routed)
- `Delivery` (computed read-side projection, derived from handling events)

Cargo is the only aggregate root in this context. All booking-side operations go through `Cargo`.

## Operations

**Book new cargo** (`BookingService.bookNewCargo`)
Input: route specification (origin, destination, deadline)
Output: a new `TrackingId`
Side effects: persists the cargo in `NOT_ROUTED` state; publishes `CargoBookedEvent` to the bus.

**Request routing** (`BookingService.requestPossibleRoutesForCargo`)
Input: tracking id
Output: list of candidate `Itinerary` (from Routing context)
Side effects: none — routing is read-only from Booking's POV.

**Assign itinerary** (`BookingService.assignCargoToRoute`)
Input: tracking id, chosen itinerary
Side effects: updates cargo, transitions to `ROUTED`, publishes `CargoAssignedToRouteEvent`.

**Change destination** (`BookingService.changeDestination`)
Input: tracking id, new destination
Side effects: route spec updated; cargo transitions back to potentially `NOT_ROUTED` if old itinerary no longer satisfies; publishes event.

## Invariants

- Once a cargo has a `CLAIM` handling event, it cannot be modified.
- Cargo's `Delivery` state is always derived from handling events; never written directly.
- A tracking ID is unique forever; never reused.

## Storage

`cargo` table:
- `tracking_id` PK
- `origin_unlocode`, `destination_unlocode`, `arrival_deadline`
- `itinerary_legs` (JSON array of leg refs, or null)
- `routing_status`, `transport_status`, `last_known_location`, etc. (denormalised projection)

The denormalised projection is rebuilt from handling events on a cron; reads can use it directly without replaying events.
