# Serial Worker execution is a global invariant

At most one Worker agent is active globally at any time. There is no parallel Worker execution at any level — not across BCs, not within a BC, not within a WorkPackage chain.

## Why

Observability is the load-bearing justification, not throughput economics. Parallel Worker execution makes failure attribution ambiguous: when two Workers run concurrently and the system misbehaves, the cause may be either Worker, an interaction between them, or a shared resource — and the 5-stage ValidationPipeline cannot reliably attribute the failure to a stage. Without single-trail attribution, RetryBudget tracking degrades to guesswork and post-hoc audit becomes archaeology.

Throughput cost is accepted: quality and traceability take priority over speed in v1. Parallel execution remains a *replanned* future architecture — it would require explicit per-Worker trace IDs, resource isolation, and a reworked Supervision contract. It is not an incremental tuning of the current design.

## Consequences

- **Infrastructure enforces this via a global lock object** (e.g., a Redis key, database row, or file-based mutex — implementation choice). Dispatch acquires the lock before a Worker cycle and releases it at stage 5 / escalation / cancellation (per [ADR-0014](./0014-delivery-orchestrator.md) Runtime model). The lock has a TTL so a crashed Dispatch does not hang it forever. Supervision *observes* lock contention as a metric but does not own or enforce the lock — per [ADR-0012](./0012-supervision-pure-observability.md), Supervision never enforces.
- **Queue depth becomes a primary observability signal.** Monotonically growing queue → upstream overload or downstream blockage. This is the kind of failure that is invisible under parallel execution.
- **Within a single Delivery cycle, all agents run sequentially under the lock.** Worker → Validators → Arbiter (when needed) do not overlap — Dispatch chains them at process boundaries (per [ADR-0014](./0014-delivery-orchestrator.md) in-cycle chaining). Across BCs, non-Delivery agents (Hermes, Architect) may operate while a Delivery cycle is active; that is the only sense in which anything "runs concurrently with" a Delivery cycle.
- **The single-Worker ceiling is the v1 throughput ceiling.** Capacity planning assumes one Worker iteration at a time, end to end.
