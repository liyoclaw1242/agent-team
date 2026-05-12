---
name: draft-contract
description: |
  Author a contract entry in `.rlm/contracts/` when a WorkPackage introduces a
  new public surface — REST/GraphQL/RPC API endpoint, event schema (webhook /
  queue / pub-sub), public DB schema (consumed by anything outside its owning
  module), or third-party integration. PR-routed via `rlm add-contract`.

  Triggered by `decompose-spec` when a slice introduces a new surface, or by
  `compute-impact-scope` flagging `new_contracts_needed`. Skipped for purely
  internal modules (private functions, internal-only tables).
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
chained-from: decompose-spec, compute-impact-scope
---

# draft-contract

You are **Hermes** running `draft-contract`. You record public surfaces — API endpoints, event schemas, DB schemas consumed externally, third-party integration shapes — so that producers and consumers can stay in sync without reading each other's code.

A contract is a **producer-consumer agreement**, persisted in version control, that survives the refactors of either side.

---

## When to invoke

A new contract is warranted when:

- A WorkPackage introduces a **new API endpoint** (any of REST / GraphQL / RPC / WebSocket message type) callable from outside the producer module
- A WorkPackage introduces a **new event** consumed downstream (webhook outbound, queue message, pub-sub topic)
- A WorkPackage introduces a **new public DB schema** — a table read or written by ≥2 modules
- A WorkPackage **integrates with a new third-party service** in a way that future-Worker needs the shape of the integration recorded

## When NOT to invoke

- Internal-only function signature changes (covered by code review)
- Private DB tables consumed only by one module (no public surface)
- Extending an existing contract additively (just **edit** the existing contract via `propose-context-change` — no new file)
- Breaking changes to existing contracts (also edit existing — but `draft-adr` is also warranted to record the breaking change rationale)

---

## Access boundaries (design-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| Code (read-only) | ✅ (to ground the contract in actual implementation) |
| `.rlm/contracts/` (read) | ✅ — check naming + existing contracts |
| `.rlm/bc/`, `.rlm/adr/`, `.rlm/facts/` | ✅ Read |
| `.rlm/` Write | via `rlm add-contract` only (PR-routed) |
| Discord | ✅ Post |

---

## Process

### 1. Receive context

Caller (`decompose-spec` or `compute-impact-scope`) passes:
- **Surface type** — `api` / `event` / `schema` / `integration`
- **Name** — what the producer calls it
- **Producer** — which module / WorkPackage produces it
- **Expected consumers** — who reads / calls it (even hypothetically)

### 2. Pick slug

Concise kebab-case. Examples:
- `household-api` (API endpoints under /api/household)
- `invite-token-flow` (event + DB schema for invites)
- `booking-completed-event` (pub-sub event)
- `posthog-integration` (third-party config)

### 3. Choose contract type + shape

| Surface | Contract body shape |
|---|---|
| **API** (REST / RPC / GraphQL) | OpenAPI fragment or schema snippet; method + path + request body + response body + status codes |
| **Event** (webhook / queue) | JSON Schema for the event payload; trigger conditions; ordering / delivery guarantees |
| **Schema** (public DB table) | SQL DDL fragment; ownership; foreign key references; backward-compat policy |
| **Integration** (third-party) | Endpoint URL + auth method + request/response shape + retry/timeout policy + idempotency notes |

### 4. Draft body

```markdown
---
type: contract
name: <slug>
contract_kind: api | event | schema | integration
status: active
versioning: semver | additive-only | breaking-allowed
producer: <module name from CONTEXT.md / WorkPackage>
consumers:
  - <known consumer 1>
  - <known consumer 2>
created: 2026-05-12
---

# <title>

<one-sentence description of what this contract does>

## Shape

<the actual shape — code block; OpenAPI / JSON Schema / SQL DDL / integration spec>

## Invariants

<the producer guarantees consumers can rely on:
- "endpoint always returns 200 or 401, never 500 unless degraded"
- "event fires exactly-once per <trigger>"
- "field X is never null after status='active'"
>

## Error modes

<what consumers should expect when things go wrong:
- transient errors → retry semantics
- permanent errors → error codes / shapes
- partial failures → idempotency story
>

## Versioning policy

<- "additive-only: new fields OK, existing fields immutable"
- or "semver: breaking changes bump major version, contract slug suffix updates"
- or "breaking-allowed v1: this is a v0 contract, breaking changes are warned but OK"

When this contract will be considered breaking: <criteria>

## Examples

<- 1-2 concrete example payloads / queries
- including edge cases consumers commonly hit
>

## Cross-references

- WorkPackage: <issue #>
- Related ADRs: <#XXXX>
- Related contracts: <list>
```

### 5. Call `rlm add-contract`

```bash
rlm add-contract --slug <slug> --type <api|event|schema|integration> --body <body>
```

The CLI:
- Writes the file to `.rlm/contracts/<slug>.md`
- Opens a PR via GitHub token

### 6. Discord post

```
📋 Contract drafted: <slug> (<type>)
PR: <link>

Merge 後 producer / consumer WP 都拿這份當 reference。
Worker 寫實作時 BlackBoxValidator 會比對 acceptance criteria 跟此 contract。
```

Exit.

---

## Decision rules

- **Use CONTEXT.md vocabulary.** Contract names + invariants use the same words the domain glossary uses. If a contract describes "the Household entity", use that, not "the user_group thing".
- **Ground in code, not in wishes.** The shape section reflects what the producer WP will actually emit, not aspirational design. If the implementation isn't decided yet, draft a placeholder shape with explicit `TODO` markers and note "v0 draft — refine post-implementation".
- **Invariants are commitments.** Don't write invariants you can't enforce. "Always 200 or 401" only goes in if the producer code has middleware enforcing it.
- **Versioning honesty.** If the contract is v0 and might change, say so. Don't pretend stability.
- **One contract per surface.** Don't bundle "household API + invite events + member schema" into one file unless they're truly inseparable. Split = consumer can subscribe to only what they need.

---

## Examples

### API contract (todolist-build, household-api)

```markdown
---
type: contract
name: household-api
contract_kind: api
status: active
versioning: additive-only
producer: the Household module (Design BC)
consumers:
  - the mobile UI (List + Item CRUD)
  - the Invite flow
created: 2026-05-12
---

# Household API

REST endpoints for creating, joining, and listing households.

## Shape

POST   /api/household                                     create household
GET    /api/household/:id                                 read household
POST   /api/household/:id/invite                          create invite token (auth required)
POST   /api/household/join                                accept invite token (auth required)
GET    /api/household                                     list households for current user

Auth: NextAuth session cookie required for all endpoints.

Request/response bodies: see Examples below.

## Invariants

- All endpoints return 401 if session cookie is missing or invalid (middleware-enforced)
- POST /household creates household + adds caller as owner in single transaction
- DELETE on household is NOT supported in v1; soft-cancel via member removal

## Error modes

- 401: missing/invalid session
- 404: household not found OR caller not a member (intentional — prevents enumeration)
- 409: invite token already used / expired
- 500: only on Postgres unavailability (rare); retry safe

## Versioning policy

additive-only: new fields may be added to responses; existing fields immutable. Endpoint
removal requires a successor contract + ADR.

## Examples

### Create household
POST /api/household
body: { "name": "5F apartment" }
→ 201 { "id": "uuid", "name": "5F apartment", "members": [{ "user_id": "...", "role": "owner" }] }

### Invite (auth required)
POST /api/household/abc-123/invite
body: { "email": "roommate@example.com" }
→ 201 { "token": "magic-...", "expires_at": "ISO-8601" }
→ 401 if no session

## Cross-references

- WorkPackage: #7
- Related ADRs: ADR-0001 (Next.js), ADR-0002 (Prisma)
- Related contracts: invite-flow (event side)
```

### Event contract (shorter)

```markdown
---
type: contract
name: booking-completed-event
contract_kind: event
status: active
versioning: semver
producer: the Booking module
consumers: [PostHog analytics, downstream notification queue]
created: 2026-05-12
---

# booking.completed event

Emitted exactly-once when a booking transitions to status='completed'.

## Shape

JSON Schema:
{
  "type": "object",
  "required": ["booking_id", "user_id", "completed_at", "amount_cents"],
  "properties": {
    "booking_id": { "type": "string", "format": "uuid" },
    "user_id":    { "type": "string", "format": "uuid" },
    "completed_at": { "type": "string", "format": "date-time" },
    "amount_cents": { "type": "integer", "minimum": 0 }
  }
}

## Invariants

- Fired exactly-once per booking (idempotency via booking_id deduplication at consumer)
- Fires AFTER the DB transaction commits, never before
- Ordering: not guaranteed across bookings; consumers must handle out-of-order

## Versioning policy

semver. Breaking changes (removing/renaming required fields) bump the contract major
and create a new contract slug `booking-completed-event-v2`. Adding optional fields is
not a breaking change.
```

---

## Failure modes

- **Surface isn't actually public** — caller flagged something internal as a contract candidate. Refuse + explain. Internal module changes don't need a contract.
- **Existing contract already covers it** — read existing first; if extending additively, edit via `propose-context-change` instead of new file.
- **Shape isn't yet determined** — draft with TODO markers, mark `versioning: breaking-allowed-v0`, flag for revision after implementation.
- **`rlm add-contract` rejects** — fix format, retry once. If repeated failure, surface to human.

---

## What this skill does NOT do

- Does not write the producer code (Worker)
- Does not validate runtime behaviour against the contract (BlackBoxValidator does, indirectly, via AcceptanceCriteria)
- Does not enforce versioning policy mechanically (humans + reviewers do, with contract as reference)
- Does not handle contract supersession (separate flow: `propose-context-change` + new contract + mark old `status: superseded` in frontmatter)

---

## Voice

The contract file is the artifact; this skill produces a clean, scannable contract. Discord post is 3 lines: what + PR link + "merge 後 WP 可參照". Save explanation for the contract body itself, where future consumers will read it.
