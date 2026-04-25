# Bounded Contexts (Cargo Shipping example)

The cargo-shipping domain is split into four bounded contexts. Each has its own model — "Cargo" in `booking` is a different thing from "Cargo" in `tracking`, intentionally.

| Context | One-line description | Document |
|---------|---------------------|----------|
| Booking | Accept cargo, generate tracking ID, attach itinerary | `booking.md` |
| Routing | Compute itineraries from voyage schedules | `routing.md` |
| Handling | Record physical events (load, unload, customs, claim) | `handling.md` |
| Tracking | Show customers where their cargo is and whether it's on schedule | `tracking.md` |

## Relationships

```
Booking      ─── needs itinerary from ───→  Routing
Booking      ─── publishes "cargo booked" event ───→  Tracking, Handling
Handling     ─── publishes "handling event recorded" ───→  Tracking, Booking
Tracking     ─── reads from ───→  Booking, Handling (via events)
```

Booking is the upstream context (the source of truth for what cargo exists). Routing is a separate service that Booking consults synchronously. Handling and Tracking subscribe to events and maintain their own read models.
