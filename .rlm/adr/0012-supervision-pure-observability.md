# Supervision: pure observability, no enforcement

Supervision is the observability layer. It collects agent narration triples, verifies that cited bases exist, and emits alerts to humans via Hermes when configured anomalies appear. **Supervision never halts an agent or rejects an action.** Enforcement of every system invariant lives in the layer that owns that invariant — never in Supervision.

## Why

Production-software observability (Prometheus, Datadog, NewRelic) does not stop services; it reports and alerts. Conflating observability with enforcement makes both worse: observability becomes coupled to control-plane policy churn, and enforcement becomes ad-hoc and hard to audit. Separating them keeps Supervision a pure data-collection-and-alerting concern, and forces every constraint to declare its own enforcement mechanism in the ADR that owns it.

## Runtime model — cron-triggered LLM agent with read-only outputs

Supervision is implemented as an **LLM agent class** (it appears in [ADR-0009](./0009-resource-access-boundaries.md)'s access matrix as a distinct agent). Specifically:

- **Cron-triggered** — periodic invocations (default 5 min) scan the event log + Issue state and decide what to alert on.
- **Stateless per invocation** (per [ADR-0010](./0010-stateless-agent-invocation.md)) — each tick reads the world fresh from the event log + GitHub state; nothing is retained between ticks.
- **Reactive mechanical checks** (basis verification, access-violation detection) may also run *inline at the runtime layer* for each new triple/event — they emit *failure-event* entries that Supervision's later LLM invocation reads and synthesises into alerts when patterns warrant.
- **Output is alerts only** — via `rlm enqueue-message --kind=supervision-alert`. No code access, no enforcement actions, no halting authority.

The "*pure observability*" framing means Supervision's only **output channel** is alerts; it does **not** mean Supervision is non-agentic. Supervision *is* an LLM agent — it makes decisions about what counts as anomaly, what severity to assign, and how to phrase the alert. Its read-only relationship to system state is enforced by the access matrix, not by being "just code."

## Where enforcement actually lives

| Invariant | Enforcement mechanism | Owner ADR |
|---|---|---|
| Resource access boundaries | API authz — agents cannot call APIs outside their scope | [ADR-0009](./0009-resource-access-boundaries.md) |
| Single active Worker | Global lock / queue — a second activation waits, it is not killed | [ADR-0007](./0007-serial-worker-execution.md) |
| Retry budgets | ValidationPipeline control flow — exhaustion returns to caller | [ADR-0006](./0006-validation-pipeline.md) |
| Triple-required tool calls | Tool-call API rejects calls missing a complete triple | [ADR-0011](./0011-structured-agent-self-narration.md) |
| Runaway / infinite loop | Per-WorkPackage token budget — exhaustion fails the task | (control plane; not yet ADR'd) |

Each violation produces a *failure event* (rejected call, lock timeout, budget exhaustion). Supervision observes the event and may alert — it never initiates the failure.

## v1 alert set

Supervision raises alerts (via Hermes → Discord) on the following conditions only. Further detectors are deferred to v2.

| Alert | Severity | Detection |
|---|---|---|
| Cited basis does not exist | Mid | Mechanical lookup against RLM / file paths / Issue IDs / prior triple IDs |
| Access-boundary violation attempt (API returned 401-class error) | High | Failure event observed in the trace |
| Token-budget approaching limit (>80% per task) | Mid | Running sum against per-task budget |
| Worker queue depth above configured threshold | Low | Sampled metric, trend-tracked |

Deferred to v2: triple-homogeneity loops (same `reasoning` repeated N times), cross-agent semantic disagreement, LLM-judged basis relevance.

## Event schema

Supervision's event log is the canonical record of system behaviour. Each event is one of:

- a **triple** emitted by an agent (per [ADR-0011](./0011-structured-agent-self-narration.md)),
- a **failure event** emitted by an enforcement layer (API authz reject, lock timeout, budget exhaustion, validation-stage failure),
- an **alert** raised by Supervision itself.

Every event carries: timestamp, source (agent_id or layer name), event_type, payload, and where applicable a `parent_triple_id` to anchor it in the trace tree.

## Consequences

- **Supervision is read-only relative to BC state.** It can read every agent's triples and every layer's failure events but cannot reach in to stop anything.
- **Halt comes from elsewhere.** A "system stops" outcome occurs through human inaction at a gate, an enforcement-layer rejection, or token-budget exhaustion — never through Supervision deciding to halt.
- **The event log becomes load-bearing infrastructure.** It must be durable, queryable, and survive Supervision restarts.
- **Future expansion (semantic checks, LLM-judged basis verification) lives behind v2 alert detectors.** Adding detectors does not change Supervision's no-enforcement posture.
