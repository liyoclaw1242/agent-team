# Case — Spec Conflicts with Codebase

The reality-check phase of `workflow/implement.md` flagged something. This case covers what to do — same shape as FE's spec-conflict case, with BE-specific examples.

## Worked example: phantom service

Task #143 spec:

```markdown
[BE] Cancellation endpoint

## Acceptance criteria
- POST /billing/subscriptions/{id}/cancel
- Persist cancellation_reason via SubscriptionAuditService
- ...
```

Reality check:

```bash
# Does SubscriptionAuditService exist?
grep -rn "SubscriptionAuditService" .
# (no results in code; one mention in arch-ddd from 6 months ago)

# What's actually used for audit?
grep -rn "audit" --include="*.go" .
# Returns: package audit/recorder.go (used in 23 places)
```

The spec references a service that was renamed (or never built). Mode C:

```markdown
## Technical Feedback from be

### Concern category
code-conflict

### What the spec says
"Persist cancellation_reason via SubscriptionAuditService"

### What the codebase shows
- No SubscriptionAuditService exists in the codebase
- arch-ddd/bounded-contexts/booking.md mentions it from 2024-12 but no code matches
- The audit pattern in use is `package audit` (src/audit/recorder.go), used in 23 places
- audit.Record(actor, action, resource, before, after) is the standard call

### Options I see
1. Use existing `audit.Record(...)` (current standard)
2. Create new SubscriptionAuditService (would duplicate functionality)

### My preference
Option 1. The existing pattern works for our case.

### Drift noticed
arch-ddd's booking.md mentions SubscriptionAuditService that doesn't exist. arch-feedback may want to update arch-ddd in this round.
```

Route to arch-feedback. Default-accept rule should kick in.

## Worked example: schema doesn't support it

Task #144 spec:

```markdown
[BE] Add bulk cancellation endpoint

## Acceptance criteria
- POST /billing/subscriptions/bulk-cancel
- Accepts array of subscription IDs
- Cancels all in a single transaction
- Returns per-ID success/failure
```

Reality check:

```bash
# Look at the cancellation flow
cat src/billing/cancel.go

# It already has cancellation logic but it does:
# - Transactional update on subscriptions table
# - Outbox event publish (within transaction)
# - Cron job picks up outbox events and publishes to event bus
```

The single-cancel logic uses an outbox pattern. The spec's "single transaction" requirement is unclear: does it mean DB transaction (yes, already supported) or distributed transaction (not supported)?

Mode C:

```markdown
## Technical Feedback from be

### Concern category
missing-AC

### What the spec says
"Cancels all in a single transaction"

### What the codebase shows
- Cancellation uses outbox pattern: DB transaction + outbox event row
- Bulk via DB transaction is straightforward (begin, multiple updates, commit)
- True distributed transaction across services not supported (we don't have 2PC)

### Options I see
1. DB-level transaction: all cancellations succeed or all fail at the DB level. Outbox events all written together. Some events may fail to publish later (outbox retry handles).
2. Per-cancel transaction: each cancellation is its own DB transaction; bulk endpoint orchestrates.

### Question for clarification
Which transaction semantics does the spec mean? Option 1 looks like the spec's intent but I want to confirm before building.

### My preference
If the answer is "DB-level transaction is fine", option 1.
```

Route. arch-feedback (or arch-judgment if outcome is unclear) responds with clarification.

## Worked example: bounded context violation

Task #145 spec:

```markdown
[BE] On cancellation, deactivate user's marketing-preferences row

## Acceptance criteria
- After cancellation succeeds, set user.marketing.churn_prevention_emails = false
- ...
```

Reality check:

```bash
# Where does marketing.churn_prevention_emails live?
grep -rn "churn_prevention_emails" .
# In: src/marketing/preferences.go and src/marketing/preferences_repository.go

# Bounded context check
cat arch-ddd/bounded-contexts/marketing.md
# Says: "Marketing owns user preferences. External contexts subscribe to user
# events; Marketing acts on its own data internally."
```

The spec asks Booking to reach into Marketing's data. That violates bounded context.

```markdown
## Technical Feedback from be

### Concern category
context-violation

### What the spec says
"Deactivate user's marketing-preferences row in the cancellation handler"

### What the codebase / arch-ddd shows
- arch-ddd/bounded-contexts/marketing.md states Marketing owns preferences;
  external contexts subscribe to user events, don't touch the data directly
- Reaching into Marketing's tables from Booking would couple them

### Options I see
1. Booking publishes CancellationCompletedEvent; Marketing subscribes and updates preferences as it sees fit
2. Move the marketing-preference change to a separate task in Marketing context, listening to CancellationCompletedEvent

### My preference
Option 1. Standard event-driven decoupling. Marketing context already has a
subscriber framework that picks this up easily.

### Drift noticed
None.
```

This kind of feedback prevents architectural decay. arch-feedback typically accepts and re-decomposes (or at minimum accepts and amends the spec to use events).

## Worked example: deprecated pattern

Task #146 spec:

```markdown
[BE] Add cancellation rate-limiting using Redis-based limiter

## Acceptance criteria
- Limit to 5 cancellations per user per day
- Use Redis-based rate limiter
- ...
```

Reality check:

```bash
grep -rn "rate.*limit" --include="*.go" .
# The codebase uses package limiter/golang-leaky-bucket; Redis-based limiter was
# deprecated in PR #501 last quarter. Memory + DB-backed limiter is the new standard.
```

```markdown
## Technical Feedback from be

### Concern category
over-prescription / deprecated-pattern

### What the spec says
"Use Redis-based rate limiter"

### What the codebase shows
- Redis-based limiter was deprecated in PR #501 (2026-Q1)
- Standard is package `limiter` (memory-backed with DB persistence)
- All new rate-limiting code uses the new pattern

### Options I see
1. Use the new `limiter` package (current standard); spec updated to outcome-only language
2. Re-introduce Redis limiter (regression)

### My preference
Option 1. Spec should say "limit cancellations to 5/user/day" without
prescribing the implementation; that lets BE pick the standard.

### Drift noticed
arch-shape's spec discipline rule was meant to prevent this; flagging in case the rule needs strengthening.
```

This is a default-accept case for arch-feedback.

## Pattern recognition

The common BE-specific spec conflict patterns:

| Pattern | Mode C category |
|---------|-----------------|
| References a service that doesn't exist or was renamed | code-conflict |
| Implies schema not in current DB | schema-conflict |
| Asks for capability not supported by stack | missing-AC (if ambiguous) or wrong-outcome (if explicit) |
| Crosses a bounded context boundary | context-violation |
| Implies a service-chain edge not in mermaid | service-chain-drift |
| Prescribes a deprecated pattern | over-prescription |
| Implies destructive migration with no path | migration-impossibility |

For each, the workflow is the same: confirm, write feedback with category + evidence + options + preference, route, wait.

## Anti-patterns

- **Working around the conflict silently** — implementing with a temporary hack and "TODO" comment. The spec is now divergent from code; future readers can't trust either.
- **Inventing the missing service** — if SubscriptionAuditService doesn't exist, don't create a tiny one to satisfy the spec. Use existing patterns.
- **Doing context violations because "it's faster"** — yes it is, this time. Compounding cost over many tasks is what kills architectures.
- **Skipping reality check** — saves 5 minutes, costs hours.
