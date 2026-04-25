# Cargo Shipping — Domain Overview (DDD example)

> This is an illustrative example, taken from Eric Evans's *Domain-Driven Design* (2003), Chapter 7. It demonstrates what a project's `arch-ddd/overview.md` should look like. Replace with your own when copying this template.

## Business

A shipping company manages international cargo transport. Customers book cargo for delivery from one location to another. Cargo travels through a network of voyages between ports. Throughout its journey, cargo is handled at intermediate locations and customs, with each handling event recorded.

## Tech stack (placeholder)

| Layer | Choice | Notes |
|-------|--------|-------|
| Frontend | React + TypeScript | Booking portal + tracking UI |
| Backend | Java / Spring (legacy) → Kotlin | Original example was Java |
| Persistence | PostgreSQL | Aggregate roots map to tables; events to event log |
| Async | RabbitMQ | Handling events fan out to interested contexts |
| Deployment | Kubernetes | One service per bounded context |

## Bounded contexts at a glance

```
┌─────────────────────────────────────────────────────────┐
│  Booking          ←  routing  →     Routing            │
│  - Cargo booking                    - Itinerary search  │
│  - Customer wants                   - Voyage schedule   │
│                                                          │
│  ↓ tracking events                  ↓ planned itinerary │
│                                                          │
│  Tracking         ←  events   →     Handling           │
│  - Where is it?                     - Customs / port    │
│  - On schedule?                     - Loading / unload  │
└─────────────────────────────────────────────────────────┘
```

Each context has its own model. The same word ("Cargo") means different things in each — this is intentional.

## Read order for agents

1. `glossary.md` — the words you'll see everywhere
2. `bounded-contexts/booking.md` — the entry point; how cargo enters the system
3. `bounded-contexts/routing.md` — how itineraries get built
4. `bounded-contexts/handling.md` — what happens during transit
5. `bounded-contexts/tracking.md` — how the customer sees it
6. `service-chain.mermaid` — the full picture
7. `domain-stories/` — concrete flows from booking to delivery
