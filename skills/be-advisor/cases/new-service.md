# Case — Request Implies New Service

A request that, if implemented, would either need a new service or substantially extend an existing one. be-advisor's job is to surface the magnitude and recommend the right boundary.

## The consultation

Parent issue #710: "Add a notification system that emails users when their order ships."

arch-shape opened consultation #711 to be-advisor:

```
- Where would notification logic live? Existing service or new?
- What downstream coordination is needed?
- Roughly how many files / services / migrations would change?
```

## Phase 1 — Investigate

```bash
# Existing notification code?
git grep -l "email\|notification\|notify" services/
# → services/orders/email_receipt.go (only)
# → services/auth/password_reset_email.go
# → no general notifications service

# Email sending infrastructure?
grep -r "smtp\|sendgrid\|ses\|postmark" services/ | head
# → services/orders/email_receipt.go uses sendgrid (lib/email/sendgrid.go)
# → services/auth/password_reset_email.go uses sendgrid same way

# How are these called?
git grep -A2 "SendReceipt" services/orders/
# → directly from order-fulfillment handler synchronously
git grep -A2 "SendPasswordReset" services/auth/
# → directly from password-reset handler synchronously

# Job / queue infrastructure?
git grep -l "rabbitmq\|kafka\|sqs\|workers/" services/
# → services/jobs/ (workers infrastructure)
# → uses internal job queue at lib/jobs/queue.go

# Event bus?
git grep -l "EventBus\|publish.*event" services/
# → none; orders are stored, not eventified

# Order shipping logic
git grep -l "ShipOrder\|ship_order\|order_shipped" services/
# → services/orders/ship_handler.go
# → services/fulfillment/ (calls into orders to mark shipped)

# arch-ddd
cat arch-ddd/bounded-contexts/notifications.md 2>/dev/null
# → file doesn't exist
ls arch-ddd/bounded-contexts/
# → orders.md, payments.md, users.md, auth.md — no notifications.md
```

## Phase 2 — Compose response

```markdown
## Advice from be-advisor

### Existing constraints

- No general notification service exists. Email is sent ad-hoc:
  - services/orders/email_receipt.go (order receipts)
  - services/auth/password_reset_email.go (password resets)
  - Both call lib/email/sendgrid.go directly, synchronously, from their
    respective handlers.
- No event bus / pub-sub infrastructure. Services communicate via
  direct RPC or shared DB. The "fulfillment service ships an order" path
  goes: fulfillment → orders.MarkShipped RPC → DB write. No events fire.
- Job queue exists (services/jobs/, lib/jobs/queue.go) and is used for
  scheduled tasks but not currently used for inter-service work.
- arch-ddd has no `notifications.md` bounded context file. Email is
  treated as an implementation detail of orders / auth domains.

### Suggested approach

Three architectural directions:

- **A) Inline at the shipping moment**: in services/orders/ship_handler.go,
  call SendShipmentEmail directly after the DB write. Mirrors the
  existing receipt pattern. Smallest change. Doesn't generalise to
  future notifications.

- **B) Job-queued from the shipping moment**: enqueue a "send shipment
  email" job from ship_handler.go via lib/jobs/queue.go; worker process
  picks it up and sends email. Decouples shipping from email delivery
  (resilience to email service outages). Reuses existing job infra.

- **C) New notifications bounded context + event-driven**: introduce a
  `notifications` service that subscribes to events (order.shipped,
  user.password_reset_requested, etc.) and fans out per user
  preferences (email, SMS, push). Requires event bus introduction.
  Largest change but lays groundwork for future notification channels.

Recommend **B as the next step**. It's a meaningful improvement
(decoupling) without introducing a new service or new architectural
pattern. The "shipped" notification fits naturally into an extension
of the existing job-based pattern.

If product roadmap includes "many notification types, multiple
channels, user preferences" within next 6 months, **C is the right
investment** — but that's an architectural decision belonging at
arch-shape level, not a one-off feature.

### Conflicts with request

- "Email when order ships" is described as a single feature. Direction
  C treats it as the first instance of a generalised notification
  system. Direction B treats it as one more specific email. arch-shape
  should pick the framing.
- Direction A would add notification logic into ship_handler.go which
  is already 320 lines and does several things; further expansion may
  warrant refactoring, but that's separate from this consultation.

### Estimated scope

- For Direction A (inline): S — 3 files: ship_handler.go (call new
  email function), shipment_email.go (new — analogous to email_receipt.go),
  test for new email function. No migration. No contract change.
- For Direction B (job-queued): M — ~7 files: ship_handler.go (enqueue
  job instead of direct call), new shipment_email_job.go (job handler),
  job registration in lib/jobs/queue.go config, email template, 2-3
  test files. No migration. No contract change. Possible 1 migration
  if persisting notification log is wanted.
- For Direction C (new service): L+ — would require:
  1. Event bus introduction (Kafka or similar) — major infra
  2. New notifications service skeleton with subscribe pattern
  3. User preferences table (new migration)
  4. Event emission from orders, auth, etc. (~10 services)
  5. arch-ddd file for notifications context
  Strongly suggest decomposing if this direction chosen.

### Risks

- Direction A: synchronous email send inside the shipping path means
  if SendGrid is slow, shipping confirmation appears slow. Existing
  receipts have the same issue (shipped one already; risk is "more
  of the same").
- Direction B: jobs need monitoring (failed jobs visible somewhere);
  existing jobs are scheduled, this would be the first event-triggered
  job. Verify job retry semantics handle email failures (currently jobs
  retry 3x; for email we may want exponential backoff to avoid
  spamming on transient failures).
- Direction C: event bus introduction is a significant architectural
  decision affecting all services; should be evaluated separately
  from the immediate notification need.
- All directions: user preference / unsubscribe handling. Currently
  the receipt email has no unsubscribe link. New "shipment emails" need
  one (CAN-SPAM compliance). Worth verifying with legal which categories
  of email require explicit opt-out vs transactional exemption.

### Drift noticed

- arch-ddd has no notifications context. Existing email logic in
  orders/auth services is undocumented; arch-ddd treats it as if email
  isn't part of the system. Worth documenting the current state
  regardless of which direction is chosen.
- arch-ddd/bounded-contexts/orders.md doesn't reference the existing
  receipt email path (services/orders/email_receipt.go). The email
  logic has accreted without arch documentation.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 711 \
  --advice-file /tmp/advice-issue-711.md
```

## What this case demonstrates

- **Surfaced the architectural inflection point**: this isn't "small task"; it's "do we want a notification system?"
- **Three honestly-scoped options**: not just "do it the existing way"; the cost difference is huge (S vs L+) and arch-shape needs to know
- **Recommended pragmatic next step**: B is the recommended option because it's improvement without commitment to a bigger pattern
- **Pushed scope decision back to arch-shape**: the framing of "single feature" vs "first of many" is the deciding question; advisor doesn't unilaterally answer
- **Cross-domain awareness**: noted CAN-SPAM / unsubscribe as real concerns even though not asked
- **Drift surfaced for follow-up**: arch-ddd has gaps regardless of decision

## Key lessons

1. When a request is small in user-facing surface but large in architectural implication, surface the implication. The user-facing scope is misleading.
2. Three options is the sweet spot — fewer hides trade-offs, more is overwhelming.
3. The recommended option should usually be the smallest one that's a real improvement; ambitious options should be flagged but not picked unilaterally.
4. Cross-cutting concerns (compliance, monitoring, future-proofing) belong in Risks even when not asked about.
5. New bounded contexts should never be silently introduced; they're an arch-shape decision.
