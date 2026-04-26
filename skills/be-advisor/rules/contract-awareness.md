# Rule — Contract Awareness

Backend changes that alter contracts have downstream effects FE / mobile / partner integrations all feel. be-advisor must surface contract implications as part of every consultation that touches a public surface.

## What's a "contract" here

Anything other systems consume:

- **gRPC `.proto` definitions**
- **OpenAPI / Swagger specs** for REST APIs
- **GraphQL schemas**
- **Webhook payloads** sent to external systems
- **Event schemas** on internal queues (Kafka topics, RabbitMQ messages, etc.)
- **Database views / shared tables** consumed by other services
- **Job payloads** if jobs are produced by one service and consumed by another

## Three change categories

### Additive (safe)

- New optional field in a message
- New RPC / endpoint
- New enum value (only if consumers handle "unknown" gracefully)
- New event type (consumers can ignore unknown)

Most consumers tolerate additive changes without code changes — they just don't see the new thing. Surface in advice as "additive; existing consumers unaffected".

### Compatible (mostly safe with caveats)

- Field that becomes required — for new consumers (existing data may have it null)
- Stricter validation on existing fields — old clients may now be rejected
- Default value changes — clients relying on the old default break
- Renaming with deprecation — old name and new name coexist temporarily

These are the dangerous middle zone. Surface with explicit "consumers X, Y, Z would need updates". If consumers are external, include rollout plan in the suggestion.

### Breaking

- Removing a field
- Removing an RPC / endpoint
- Type change of an existing field (string → int)
- Required field added to existing message
- Renaming without deprecation
- Field number reuse in proto

Breaking changes need explicit migration paths. Surface as "breaking — coordination required". Often the right answer is "introduce v2 alongside v1; deprecate v1 over time" rather than break v1.

## Contract evolution patterns

Some patterns make contract evolution easier; recognise which the codebase uses:

### proto field numbers

In Protocol Buffers, field numbers are forever — once assigned, they can't be reused. Adding a field uses a new number; removing a field reserves the number; renaming changes the field name but keeps the number.

```protobuf
message Charge {
  reserved 5;  // formerly removed_field
  string charge_id = 1;
  int64 amount_cents = 2;
  string currency = 3;
  Status status = 4;
  // 5 is reserved; do not reuse
  string idempotency_key = 6;  // newer
}
```

When proposing changes, use new numbers; don't reuse.

### REST versioning

If the codebase uses URL versioning (`/v1/charges`, `/v2/charges`), breaking changes go in the next version. Internal API patterns may be different (header versioning, content-type versioning).

Note which pattern is used so the advice aligns:

```markdown
- Codebase uses URL-path versioning: existing endpoints at /v1/charges
- For breaking change: introduce /v2/charges; keep /v1 with deprecation
  header for 6 months
```

### GraphQL deprecation

GraphQL has built-in `@deprecated`:

```graphql
type Charge {
  id: ID!
  oldStatus: String @deprecated(reason: "Use status instead")
  status: ChargeStatus!
}
```

Schema evolves additively; deprecation gives clients time to migrate.

### Event schema evolution

Event payloads usually evolve via:
- Backward-compatible additions (new optional fields)
- Versioned topics (`payments.charges.v1`, `payments.charges.v2`)
- Schema registries (Avro, Protobuf with registry)

Surface which approach the codebase uses; advice should follow it.

## What to surface in advice

Whenever the request implies a contract change:

### In "Existing constraints"

- The contract location and version
- Current consumers (count + location)
- Recent contract evolution (last few changes)
- Whether deprecation pattern exists

### In "Suggested approach"

- Whether the proposed change is additive / compatible / breaking
- The proposed contract shape (text, not code commits)
- Versioning / deprecation strategy if breaking

### In "Conflicts with request"

- If the proposed change forces a breaking pattern when additive would suffice
- If consumer coordination is required and may not be feasible
- If the contract design forces clients into awkward shapes

### In "Risks"

- Schema evolution mistakes (field number reuse in proto, etc.)
- Latency / fan-out implications on consumers
- Versioning rollout coordination
- Backward-compat windows

## Examples

### Example 1: simple additive change

```markdown
### Suggested approach

- Add `refunded_at TIMESTAMPTZ NULL` to charges table (additive migration;
  existing rows get NULL).
- Add `refunded_at` field to Charge message in payments.proto as field 7
  (next unused number).
- Additive only; existing FE / SDK consumers continue to work; new
  consumers can use the field once they upgrade to the regenerated SDK.
```

### Example 2: breaking change handled with versioning

```markdown
### Suggested approach

- Request implies changing `amount: int64` (cents) to `amount: Money` (struct
  with currency). This is a type change → breaking.
- Recommended: introduce ChargeV2 RPC + ChargeV2 message; keep Charge
  RPC for existing consumers. Deprecate Charge over 90 days; coordinate
  consumer migrations.
- Alternative considered: rename `amount` to `amount_cents` and add
  `amount` as Money. This is also breaking (field semantics change);
  not better than v2 introduction.
```

### Example 3: pushback on breaking when additive would suffice

```markdown
### Conflicts with request

- Request says "remove the deprecated `status_text` field". Removing it is
  breaking; checking consumers reveals 2 services still consume it
  (orders/internal/status_display.go, admin/components/StatusBadge.tsx).
  Recommend deprecation announcement + 90-day removal window with active
  monitoring of consumer migrations, not direct removal.
- Alternative (better): mark deprecated, replace consumers in a series of
  PRs, then remove. Lower coordination cost.
```

## Internal vs external contracts

Internal contracts (consumed by services in the same monorepo) are easier to evolve — you control all consumers. External contracts (public APIs, partner webhooks) can't be coordinated; breaking changes require versioning.

Surface the distinction:

```markdown
- payments.proto is internal (consumed by 4 services in this monorepo);
  breaking changes are coordinated via batch updates
- /webhooks/charge endpoint is external (consumed by Stripe → us, fixed
  shape from Stripe's side); we cannot change Stripe's webhook payload
- /v1/api/charges is public (consumed by partner integrations); breaking
  changes require new version + deprecation cycle
```

## Anti-patterns

- **Treating contracts like internal code** — internal types can be refactored freely; contracts can't
- **Ignoring SDK regeneration cost** — every contract change forces a regen + consumer update
- **Forgetting webhook payloads are contracts** — they go to external systems too
- **"Just remove the deprecated thing"** — without verifying consumer migration is complete
- **Reusing proto field numbers** — silent data corruption
- **Recommending breaking changes when additive would work** — gratuitous breakage
- **Recommending additive when it leaves cruft** — sometimes a deprecation cycle is the right answer

## Quick checklist

For any request that touches a backend public surface:

- [ ] Identified the contract (location, version, type)
- [ ] Counted consumers
- [ ] Categorised the proposed change (additive / compatible / breaking)
- [ ] If breaking: proposed versioning / deprecation strategy
- [ ] Surfaced the strategy in "Suggested approach"
- [ ] Surfaced cost / coordination in "Risks"
- [ ] Distinguished internal vs external contracts
