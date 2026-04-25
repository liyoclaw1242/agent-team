# Bounded Context: Routing

A specialist context that knows about voyage schedules and computes itineraries to satisfy route specifications. Stateless from the booking perspective — Routing doesn't store cargo, only schedules and computed routes.

## Aggregate roots

**Voyage** — root of the schedule aggregate. Holds:
- `VoyageNumber`
- A list of `CarrierMovement` entries forming a schedule (a sequence of port-to-port legs over time)

Voyages are managed separately (likely by an admin tool out of scope here); Routing reads them.

## Operations

**Find routes** (`RoutingService.fetchRoutesForSpecification`)
Input: `RouteSpecification` (origin, destination, arrival deadline)
Output: a list of candidate `Itinerary`, each composed of legs across one or more voyages, all of which satisfy the spec.

This is the only public operation. It is read-only and side-effect-free.

## Algorithms (sketch)

In the original DDD example, this is delegated to a graph-traversal algorithm over the voyage network. Anti-corruption layer between Routing and Booking translates between the two contexts' representations of `Itinerary`.

## Storage

`voyage` and `carrier_movement` tables, both essentially append-only — voyages are scheduled, then occasionally amended. Past voyages remain for historical tracking lookups.
