# Domain Story — Book and ship a cargo

End-to-end happy-path flow. This is the kind of artefact agents read when they need to understand "how does this whole thing actually work".

Format note: each numbered step has WHO, DOES, WHAT, IN, → OUT (or "publishes" for events). This is the Domain Storytelling notation simplified for markdown.

---

1. **Customer** submits a booking request via **Booking UI** with origin SHANGHAI, destination ROTTERDAM, deadline 2026-06-01.

2. **Booking UI** calls **Booking Service** `POST /cargos` with the route specification.

3. **Booking Service** generates a fresh `TrackingId` (`ABCD123456`), persists the cargo in `NOT_ROUTED` state, returns the id to the UI, and **publishes** `CargoBookedEvent` to the bus.

4. **Tracking Service** consumes `CargoBookedEvent`, creates an empty `CargoTrackingView` keyed by the tracking id.

5. **Customer** is shown the tracking id; UI offers "see route options".

6. **Booking UI** calls **Booking Service** `GET /cargos/ABCD123456/routes`.

7. **Booking Service** delegates to **Routing Service** `fetchRoutesForSpecification`.

8. **Routing Service** searches the voyage graph and returns three candidate `Itinerary` values.

9. **Booking Service** returns the candidates to the UI; **Customer** chooses one.

10. **Booking UI** calls **Booking Service** `PUT /cargos/ABCD123456/itinerary` with the chosen itinerary.

11. **Booking Service** persists the itinerary, transitions cargo to `ROUTED`, **publishes** `CargoAssignedToRouteEvent`.

12. **Tracking Service** consumes the event, populates the tracking view with the planned itinerary and computed ETA.

13. **Email Provider** (subscribed to the same event) sends a booking confirmation to the customer.

— *time passes; cargo physically moves* —

14. **Port operator at SHANGHAI** registers a `LOAD` event via **Handling Service** `POST /handling-events`. **Handling Service** validates, persists, **publishes** `HandlingEventRegistered`.

15. **Tracking Service** updates the view: transport status `ONBOARD_CARRIER`, last-known-location `SHANGHAI`.

16. **Booking Service** also consumes `HandlingEventRegistered` to check invariants — confirms the load is consistent with the assigned itinerary, no misdirection.

— *more events: UNLOAD at ROTTERDAM, then CLAIM* —

17. **Customer** receives the cargo, signs for it. **Operator** registers `CLAIM` event.

18. **Handling Service** publishes the event; **Tracking Service** marks the view as completed; **Booking Service** locks the cargo from further mutation.

---

## Misdirection branch

If between steps 14 and 17 the cargo loads onto a voyage that's not part of the assigned itinerary, step 16 detects it: `Cargo.isMisdirected()` returns true. **Booking Service** publishes `CargoMisdirectedEvent`. **Customer support tooling** (out of scope here) picks it up and triages.

## What this story tells an agent

When `arch-shape` is asked "add ability for customer to change destination mid-shipment", the agent reads this story, then sees:

- Step 11 already handles `CargoAssignedToRouteEvent`. A change-destination flow would publish a similar `CargoRouteChangedEvent`.
- Step 16's misdirection check runs against the *current* itinerary. A mid-flight route change must update the itinerary atomically with the route-change event, otherwise misdirection alarms will fire.
- Tracking view (step 12) needs to handle "destination changed mid-flight" — display both the old and new destinations until handover.

This is the texture domain stories provide that bounded-contexts.md alone can't.
