# Cargo Shipping — Glossary (DDD example)

> Ubiquitous language for the cargo-shipping domain. Every term here matches its spelling in code. Disagreements between code and glossary are bugs to fix in code, not glossary entries to add.

## Core entities

**Cargo**
The unit of shipment. Has a unique tracking ID, an origin, a destination, and a current itinerary. *Code: `Cargo`*

**Tracking ID**
The customer-facing identifier for a piece of cargo. Format: 4 letters + 6 digits, e.g. `ABCD123456`. Generated at booking; never reused. *Code: `TrackingId`*

**Route Specification**
The customer's stated requirement: "I want this cargo from origin O to destination D, arriving by date X." Doesn't specify how. *Code: `RouteSpecification`*

**Itinerary**
A sequence of legs that, executed in order, satisfy a route specification. Built by Routing context, used by Booking. *Code: `Itinerary`*

**Leg**
One segment of an itinerary: a load location, an unload location, a voyage that connects them, and scheduled times for both. *Code: `Leg`*

## Locations & movement

**Location**
A port, terminal, or warehouse. Identified by UN/LOCODE (5-letter codes like `USNYC` for New York). *Code: `Location`, `UnLocode`*

**Voyage**
A specific scheduled service that moves cargo between ports. Has a schedule (multiple legs over time), a vessel, and a voyage number. *Code: `Voyage`, `VoyageNumber`*

**Carrier Movement**
One leg of a voyage's schedule: ship from port A to port B, departing at T1, arriving at T2. *Code: `CarrierMovement`*

## Handling & state

**Handling Event**
Something that happened to cargo: it was received, loaded, unloaded, in customs, claimed. Always recorded with location, time, and (when applicable) the voyage. *Code: `HandlingEvent`*

**Handling Event Type**
The kind of handling event: `RECEIVE`, `LOAD`, `UNLOAD`, `CUSTOMS`, `CLAIM`. *Code: `HandlingEventType`*

**Delivery History**
The sequence of handling events for a cargo, used to compute its current state. *Code: `DeliveryHistory`*

**Delivery**
The current state of a cargo derived from its handling events: where it is, what's next, whether it's misdirected, whether it's on schedule. *Code: `Delivery`*

**Routing Status**
Where the cargo is in the routing lifecycle: `NOT_ROUTED`, `ROUTED`, `MISROUTED`. *Code: `RoutingStatus`*

**Transport Status**
Physical state of the cargo: `NOT_RECEIVED`, `IN_PORT`, `ONBOARD_CARRIER`, `CLAIMED`, `UNKNOWN`. *Code: `TransportStatus`*

## People

**Customer**
The party that books and pays for shipment. Has billing details, claims contact, etc. (In the original DDD example, this was simplified.) *Code: `Customer`*

## Operations

**Booking**
The act of accepting a cargo for shipment, generating a tracking ID and route specification. *Code: `BookingService.bookNewCargo()`*

**Routing**
Computing one or more itineraries that satisfy a route specification, using current voyage schedules. *Code: `RoutingService.fetchRoutesForSpecification()`*

**Misdirection**
A cargo's last handling event indicates it's not following its planned itinerary. *Code: `Cargo.isMisdirected()`*

**Claiming**
The end of a cargo's lifecycle: it's been received by the consignee. *Code: `HandlingEvent` of type `CLAIM`*
