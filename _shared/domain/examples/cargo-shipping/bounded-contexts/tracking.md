# Bounded Context: Tracking

Customer-facing read model. Answers two questions: "Where is my cargo?" and "Is it on schedule?"

## Aggregate roots

This context has no write-side aggregate roots in the strict sense — it is a read model maintained by subscribing to events from Booking and Handling.

What it stores conceptually:

**CargoTrackingView** — a denormalised projection per cargo:
- `TrackingId`
- Latest known location
- Transport status
- Routing status
- Misdirected flag
- Eta vs deadline
- Recent handling events (last N)

## Operations

**Get tracking view** (`TrackingService.getCargoTracking`)
Input: tracking id
Output: `CargoTrackingView` or null if the tracking id is unknown.

The customer portal calls this; nothing else.

## How the projection is maintained

Subscribers:
- `CargoBookedEvent` → create empty `CargoTrackingView`
- `CargoAssignedToRouteEvent` → store itinerary, recompute eta
- `HandlingEventRegistered` → update last-known-location, transport status, recompute misdirection

The projection can be rebuilt from event replay; it has no authoritative state of its own.

## Why a separate context

Tracking is the only customer-facing read path. By isolating it as a bounded context with its own model:
- Booking and Handling don't need to optimise their schemas for tracking queries
- Tracking can be cached aggressively, denormalised, even replicated to a CDN
- The tracking page can evolve independently of the operational model
