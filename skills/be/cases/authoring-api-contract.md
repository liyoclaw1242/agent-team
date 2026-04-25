# Case — Authoring an API Contract

The most common BE-FE collaboration shape. Your task is to add an endpoint that an FE sibling task will consume. Phase 2 of `workflow/implement.md` is "publish the contract before implementation"; this case covers what to put in it.

## Worked example

Task #143:

```markdown
[BE] Cancellation endpoint with effective-date computation

## Acceptance criteria
- POST endpoint to cancel a subscription
- Computes effective date based on the subscription's billing cycle
- Returns 404 if not found, 409 if already cancelled
- Publishes CargoCancelledEvent on success
```

Sibling FE task #144 has `<!-- deps: #143 -->`.

## Phase 1 — Phase reading reveals the shape

After reading the spec, AC, parent issue, bounded-contexts/booking.md, you understand:

- Path: standard REST shape, `POST /billing/subscriptions/{id}/cancel`
- Auth: subscription belongs to a user; need to verify ownership
- Behaviour: idempotent (calling twice = first cancels, second returns 409)
- Effective date: end of current billing cycle for the plan

Now you compose the contract.

## Phase 2 — Compose the contract

Create `/tmp/contract-143.md`:

```markdown
## Contract (defined by BE, consumed by FE)

### Endpoint
POST /billing/subscriptions/{id}/cancel

### Auth
- **Authentication**: Bearer JWT (validated by `requireAuth` middleware)
- **Authorization**: subscription specified by `id` must belong to the
  authenticated user. Otherwise return 404 (not 403 — we don't reveal
  whether other users' subscriptions exist)

### Request

**Path parameter**: `id` — subscription's tracking ID, format `[A-Z]{4}[0-9]{6}` (per `arch-ddd/glossary.md`)

**Body**: empty (no body required; ignored if present)

### Responses

**Success: 200 OK**

```json
{
  "effectiveDate": "2026-05-15T23:59:59Z"
}
```

- `effectiveDate` is the timestamp at which the cancellation takes effect.
  For monthly subscriptions, this is the end of the current billing cycle.
  ISO8601 UTC.

**Error: 404 Not Found**

```json
{
  "error": "subscription_not_found",
  "message": "Subscription not found"
}
```

- Returned when:
  - `id` doesn't match any subscription
  - Subscription exists but doesn't belong to the authenticated user
- These two cases are merged intentionally to prevent enumeration

**Error: 409 Conflict**

```json
{
  "error": "subscription_already_cancelled",
  "message": "Subscription is already cancelled",
  "cancelledAt": "2026-04-20T10:00:00Z"
}
```

- Returned when the subscription is already in `CANCELLED` state
- `cancelledAt` is the timestamp of the original cancellation, included for FE display

**Error: 401 Unauthorized**

Standard. JWT missing or invalid.

### Side effects

On success:
- Subscription transitions: `ACTIVE` → `CANCELLED`
- `cancellation_requested_at` set to now
- `effective_date` set to the computed value
- Event published: `CargoCancelledEvent { trackingId, userId, effectiveDate }`
  - Subscribers per `arch-ddd/service-chain.mermaid`: tracking-svc, email-svc

### Idempotency

- Calling twice on an active subscription: first call cancels (200), second returns 409
- Calling on an already-cancelled subscription: 409 immediately
- The endpoint is therefore safe-to-retry from a client perspective: if the
  client doesn't know whether the first call landed, retrying gives a
  consistent answer (either 200 or 409 — both indicate the cancellation is in effect)

### Rate limit

Standard authenticated rate limit (60/min/user). Cancellation is rare enough that this is unlikely to be hit.
```

## Phase 3 — Publish

```bash
bash actions/publish-contract.sh \
  --issue 143 \
  --contract-file /tmp/contract-143.md
```

The action appends (or replaces) the contract block in the issue body. FE can now read it.

## Phase 4 — Now write tests, then implementation

The TDD loop kicks in. Tests written from the contract:

```go
func TestCancel_Success_ReturnsEffectiveDate(t *testing.T) {
    // setup: create active subscription for user
    // act: POST /billing/subscriptions/{id}/cancel with valid JWT
    // assert: 200, body has effectiveDate matching cycle end
}

func TestCancel_404_WhenNotOwner(t *testing.T) {
    // setup: subscription belongs to user A; auth as user B
    // act: cancel call
    // assert: 404 (not 403)
}

func TestCancel_404_WhenNotFound(t *testing.T) { ... }
func TestCancel_409_WhenAlreadyCancelled(t *testing.T) { ... }
func TestCancel_PublishesEvent(t *testing.T) { ... }
func TestCancel_IsIdempotent_SameAnswerOnRetry(t *testing.T) { ... }
```

Tests written from contract → implementation makes them green → integration tests verify end-to-end.

## What this case is NOT

- A code skeleton for the implementation (that's not in scope; implementation comes after)
- A specification of internal handler structure (that's BE's call within the constraints of the contract)
- A binding spec for FE's UX (FE decides how 404/409 are presented)

The contract is the **wire format and behaviour**. Internal implementation choices stay internal.

## Common contract authoring mistakes

### Mistake 1: forgetting authorization details

> Auth: required

This is too vague. Specifically: what about resource ownership? What about admin access? Be explicit:

> Auth: Bearer JWT. Authz: resource belongs to authenticated user (return 404 otherwise; admins can act on any resource via X-Admin-Override: true header).

### Mistake 2: error response without body shape

> 404 if not found

What does the body look like? FE has to decide. Specify:

```json
{
  "error": "subscription_not_found",
  "message": "..."
}
```

### Mistake 3: not specifying side effects

If the cancellation publishes events, says so. FE may need to know that subsequent reads (after the call returns 200) will see eventual-consistency effects.

### Mistake 4: forgetting idempotency / retry semantics

Mobile FE clients especially may retry on network failure. Document what happens.

### Mistake 5: using non-glossary names

`effectiveAt` vs `effectiveDate` (or any inconsistency with glossary) creates drift across the contract → wire → FE consumer chain. Use glossary terms.

## When the contract changes mid-flight

You're implementing and discover the contract you published is wrong (e.g., the database can't actually support the response you described).

This is rare if Phase 1 reading was thorough, but it happens. The reaction:

- If FE hasn't started yet: re-publish updated contract; comment explaining
- If FE has started: don't update silently. Comment proposing change; if FE agrees, both update; if FE disagrees, Mode C (contract conflict)

Per `rules/contract-authorship.md`, the published contract is binding. Changes go through process, not unilateral edits.
