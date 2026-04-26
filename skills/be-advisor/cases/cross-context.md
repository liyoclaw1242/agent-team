# Case — Cross-Context Request

A request that requires changes across two or more bounded contexts. be-advisor's job is to surface the cross-context nature, propose where the new logic should live, and flag the coordination cost.

## The consultation

Parent issue #910: "When a customer is set to 'fraud_review' status, automatically pause their active subscriptions and refund any charges from the last 7 days."

arch-shape opened consultation #911 to be-advisor:

```
- This touches customers, subscriptions, payments — what's affected?
- Where should the orchestration live?
- What's the failure-handling story?
```

## Phase 1 — Investigate

```bash
# Bounded contexts in arch-ddd
ls arch-ddd/bounded-contexts/
# → customers.md, subscriptions.md, payments.md, ...

# Customers domain
git grep -l "fraud_review\|FraudReview\|fraud_status" services/customers/
# → services/customers/status.go (FraudReview is a defined status; transition function exists)

# Subscriptions domain
git grep -l "PauseSubscription\|pause_subscription" services/subscriptions/
# → services/subscriptions/handler.go has PauseSubscription RPC

# Payments domain
git grep -l "Refund\|RefundCharge" services/payments/
# → services/payments/refund_handler.go has RefundCharge RPC

# How do these services currently coordinate?
git grep -l "subscriptions_pb\|payments_pb\|customers_pb" services/
# → customers imports subscriptions_pb (calls subscriptions when needed)
# → subscriptions imports payments_pb
# → payments doesn't import customers (one-way)

# Is there orchestration / saga infra?
git grep -l "saga\|orchestrat\|workflow" services/
# → none — no orchestration framework

# Existing cross-service flows
git grep -A5 "transaction\|Tx" services/ | head -30
# → Each service has its own DB; no cross-service transactions
# → Pattern: if a multi-service call fails, manual cleanup or eventual consistency

# Recent cross-service PRs (look for pattern hints)
git log --oneline --all -- services/customers/ services/subscriptions/ | head
# → mostly isolated changes; few cross-service PRs in recent history

# arch-ddd cross-context guidance
grep -l "cross-context\|cross_context" arch-ddd/
# → arch-ddd/cross-context-decisions.md exists
cat arch-ddd/cross-context-decisions.md
# → "Cross-context invariants are coordinated via explicit handlers in the
#    customers context (the 'master' context for user state). Other contexts
#    expose intent-revealing RPCs but don't reach across."
```

## Phase 2 — Compose response

```markdown
## Advice from be-advisor

### Existing constraints

- Three bounded contexts touched: customers, subscriptions, payments.
- Customers context already has `FraudReview` status (services/customers/status.go);
  the status transition exists but currently has no side effects.
- Subscriptions context has `PauseSubscription` RPC (services/subscriptions/handler.go);
  takes a customer_id and pauses all active subscriptions for that customer.
- Payments context has `RefundCharge` RPC (services/payments/refund_handler.go);
  refunds a single charge by ID.
- No "list charges in last N days for customer" RPC exists; would need
  one. Closest existing: `ListCharges` with no time-bound filter.
- Existing cross-context coordination pattern (per arch-ddd/cross-context-decisions.md):
  the customers context is the "master"; other contexts expose RPCs;
  customers calls them. customers already imports subscriptions_pb (one
  example precedent: when a customer is deleted, customers calls
  subscriptions.DeleteCustomerSubscriptions).
- No saga / orchestration framework exists; cross-service work uses
  best-effort RPC calls with manual error handling.

### Suggested approach

Per the existing cross-context-decisions guidance, the orchestration
should live in customers context — when status transitions to
FraudReview, customers triggers downstream actions:

- Add a transition hook: in services/customers/status.go, when status
  becomes FraudReview, call:
  1. `subscriptions.PauseSubscriptions(customer_id)` (existing RPC; already supports this)
  2. New RPC `payments.RefundChargesSince(customer_id, since=now-7d)`
- The "refund last 7 days" requires a new RPC in payments. Two shape options:
  - `RefundChargesSince(customer_id, since)` — payments enumerates and refunds
  - `ListChargesSince(customer_id, since)` returning charge IDs;
    customers calls RefundCharge for each
- Recommend the first shape (RefundChargesSince): keeps the iteration
  inside payments where the charge data lives; customers passes
  intent ("refund recent for fraud") not an enumeration.

Failure-handling pattern, given no saga framework:

- Each downstream call (PauseSubscriptions, RefundChargesSince) is its
  own RPC; failures are logged and queued for retry via the existing
  job system (lib/jobs/queue.go).
- Status transition (customer → FraudReview) succeeds independently;
  downstream effects are eventually consistent.
- Build a reconciliation job that periodically scans FraudReview
  customers and verifies subscriptions are paused + recent charges
  refunded; emits alerts for inconsistencies.

This is "intent + best-effort + reconciliation", which matches the
codebase's existing pattern for cross-service work.

### Conflicts with request

- Request implies atomicity ("automatically pause AND refund"). Without
  a saga framework, true atomicity isn't available. The proposed pattern
  (eventually consistent + reconciliation) means there's a window where
  status is FraudReview but subscriptions / refunds haven't yet
  processed. Acceptable in fraud-review context (review takes hours
  anyway), but worth confirming with product.
- "Refund any charges from the last 7 days" is fuzzy — does that mean:
  a) Refund all charges where charged_at > now-7d
  b) Refund all charges in subscription billing cycles that started in last 7d
  c) Refund all successfully captured charges in last 7d (skip failed/pending)
  Recommend arch-shape clarify with the requester. Default interpretation
  (c) seems safest but the spec should be explicit.

### Estimated scope

- L — ~15 files, 1 contract change, 1 migration:
  - services/payments/refund_charges_since_handler.go (new RPC implementation)
  - contracts/payments.proto (add RefundChargesSince RPC) — additive
  - services/customers/status.go (transition hook)
  - services/customers/fraud_review_handler.go (new — orchestration)
  - services/customers/internal/{subscriptions,payments}_client.go
    (extend existing clients; no new ones needed)
  - lib/jobs/jobs/fraud_review_reconcile.go (reconciliation job)
  - Migration: 1 file adding fraud_review_actions table for audit
  - 4-5 test files (unit + integration)
- Cross-service coordination doubles the testing surface; allow extra
  iteration time.

### Risks

- Race condition: customer transitions to FraudReview, downstream calls
  fire, but a NEW charge happens between transition and refund call.
  The new charge wouldn't be in the "last 7 days at time of transition"
  set. Reconciliation job needs to handle this — check periodically
  while customer is in FraudReview, not just once.
- Refund idempotency: if reconciliation re-fires RefundChargesSince,
  payments must not double-refund. Existing RefundCharge supports
  idempotency keys; the new RefundChargesSince must propagate this.
- Subscription pause vs cancel: PauseSubscription preserves the
  subscription; if FraudReview leads to cancellation, that's a separate
  flow. Confirm with product whether pause is correct (vs cancel).
- Audit trail: when the system auto-pauses / auto-refunds, the customer
  and the agent (Trust & Safety) need a clear log of what happened.
  Recommend the new fraud_review_actions table records each action
  with timestamps.
- Webhook implications: subscription pause + payment refund both fire
  webhooks; external systems (SaaS partners, accounting integrations)
  will see a flurry of events. Worth verifying the pattern matches
  human-initiated pause / refund webhooks (so consumers don't have
  to special-case fraud-triggered ones).

### Drift noticed

- arch-ddd/bounded-contexts/customers.md mentions FraudReview status
  but doesn't describe its consequences (subscriptions, refunds).
  This consultation's design should be reflected in the bounded-context
  doc once arch-shape decides.
- arch-ddd/cross-context-decisions.md cites customers as the
  orchestration master; this case follows that pattern. The doc
  could benefit from this case as an additional example.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 911 \
  --advice-file /tmp/advice-issue-911.md
```

## What this case demonstrates

- **Identified all involved contexts upfront**: customers, subscriptions, payments — listed each
- **Used existing arch-ddd guidance**: cross-context-decisions.md was consulted; the recommendation aligned with it (not invented from nothing)
- **Proposed orchestration location**: customers context as master, per existing pattern
- **Reasoned about failure mode**: no saga framework, so eventual consistency + reconciliation is the right model
- **Surfaced ambiguity**: "last 7 days" has at least 3 interpretations; advisor named them
- **Adjacent risks called out**: race conditions, audit trail, webhook fan-out — none asked but all relevant
- **Drift noted**: arch-ddd doesn't describe FraudReview consequences; should be updated

## Key lessons

1. Cross-context requests need explicit identification of which contexts are involved
2. Always check arch-ddd for existing cross-context guidance — and align with it (or surface why deviation is needed)
3. Without saga / orchestration infra, eventual consistency + reconciliation is the realistic pattern; surface this trade-off
4. Idempotency, race conditions, audit trails are special concerns for cross-context flows; treat them as default Risks
5. arch-ddd files often describe states but not consequences; cross-context consultations often reveal these gaps
