# Message-router contract: how other BCs reach humans via Hermes

Hermes is the system's only Discord-facing agent (per [ADR-0008](./0008-hermes-scope-lifecycle-governance.md)). Hermes itself originates most human-bound messages (intake-confirmation, design-approval) as part of its own skill flow — these use the enqueue mechanism for symmetry, though Hermes is also the consumer. Other agents (DeliveryOrchestrator escalating retry exhaustion, Supervision raising basis-verification alerts, BlackBoxValidator flagging AC ambiguity) enqueue messages that Hermes routes. This ADR specifies that contract.

## The contract

A sending agent does **not** call Discord directly. It invokes the `rlm enqueue-message` CLI subcommand, which deposits the message into one of two backends:

- **A comment + `outbound:<kind>` label on a related Issue** — when the message has an obvious parent (WorkPackage, Spec, Signal).
- **A new `type:supervision-alert` Issue** — when there is no natural parent (system-wide concerns, agent-behaviour anomalies).

Hermes, on its next cron invocation, scans for outbound work:

1. Issues whose comments carry an unprocessed `outbound:*` label.
2. Open `type:supervision-alert` Issues not yet marked routed.

For each, Hermes formats the payload for Discord, posts to the appropriate channel, then removes the `outbound:*` label (or comments on the alert Issue with `routed` marker). The enqueuing agent does not wait — it has already exited.

## Message kinds (v1)

| `<kind>` | Sender | Parent | Notes |
|---|---|---|---|
| `intake-confirmation` | Hermes (self) | Spec Issue | Listed for symmetry; in practice Hermes posts directly during its own invocation. |
| `design-approval` | Hermes (self-invoked via design-approval skill) | WorkPackage Issue | Posted by Hermes when a WorkPackage draft is ready for human ack; same agent processes the reply (no cross-agent routing). |
| `retry-exhausted` | DeliveryOrchestrator | WorkPackage Issue | Sent when WhiteBox/BlackBox `RetryBudget` is exhausted (per [ADR-0006](./0006-validation-pipeline.md)). |
| `ac-ambiguity` | DeliveryOrchestrator (routing BlackBoxValidator's finding) | Spec Issue | Triggers the in-flight cancellation + new-Spec path in [ADR-0013](./0013-spec-workpackage-lifecycle.md). |
| `supervision-alert` | Supervision; Hermes (stale-fact reports); Dispatch (Arbiter-failure escalations) | None — creates a new `type:supervision-alert` Issue | Used for basis-verification failures, access-violation observations, queue-depth or token-budget warnings (per [ADR-0012](./0012-supervision-pure-observability.md)), stale-fact reports under Approach F (per [ADR-0004](./0004-rlm-knowledge-base.md)), and Arbiter-failure escalations (per [ADR-0017](./0017-delivery-arbiter.md)). |

New `<kind>` values are added by changing this ADR plus Hermes's routing prompt — no other architectural change.

## Why this shape

Three design forces:

1. **Hermes remains the only Discord-credential holder.** No other agent gets Discord write privilege; this preserves the consolidated cross-cutting Hermes scope (per ADR-0008).
2. **Statelessness is preserved.** Enqueuing is one CLI invocation; it does not block, does not maintain a connection, does not wait for a human response. The sender exits.
3. **The audit trail stays in GitHub.** Outbound messages live on the relevant Issue (or in a dedicated alert Issue). Anyone reading the WorkPackage history sees exactly what Hermes was asked to post — no hidden side channel.

## Rejected alternatives

- **A file-based queue (`docs/outbox/`)** — adds a directory that has no human-reader value and duplicates information already adjacent to the WorkPackage / Spec it concerns.
- **A message-bus service (Redis, NATS)** — new infrastructure that buys no observability over the GitHub-Issue approach for v1.
- **Direct Discord API calls from non-Hermes agents** — distributes credentials, breaks the Hermes scope invariant, and bypasses the audit trail.

## Consequences

- **Every cross-BC-to-human message is auditable in GitHub.** Issue history shows what was asked, by whom, and when.
- **Hermes batches outbound posts.** If three agents enqueue in the same 5-minute cron window, Hermes posts all three on its next run. Acceptable latency for the message kinds this routes.
- **Hermes downtime is queue backup, not message loss.** Enqueued messages persist until Hermes runs successfully. No message dropped on the floor.
- **The contract scales naturally.** A future agent that needs to alert humans adds a new `<kind>` value here and a routing branch in Hermes — no architectural change.
- **Supervision now has an Issue-creation capability** (specifically for `type:supervision-alert`); this is recorded as a delta in [ADR-0009](./0009-resource-access-boundaries.md).
