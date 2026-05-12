# Structured agent self-narration

Every agent emits a structured *narration triple* at two granularities — (1) once per invocation as a summary, and (2) once per tool call. Each triple has six fields:

| Field | Meaning |
|---|---|
| `action` | What was done (machine-readable identifier of the operation) |
| `reasoning` | Why it was done (human-readable intent) |
| `basis` | What evidence backed the decision (references to RLM entries, file:line, Issue IDs, prior triple IDs) |
| `agent_id` | Which agent emitted this |
| `parent_triple_id` | The triple this action descends from (builds the trace tree per invocation) |
| `affected_resources` | Files, Issues, PRs touched by the action |

## Why

Supervision cannot read an LLM's internal reasoning, and raw tool-call logs alone do not capture *why* an action was taken. Without explicit self-narration, the only honest observability is "agent did X" — never "agent did X because Y, citing Z." Forcing the triple at every meaningful action point produces a paper trail that is:

- **machine-checkable** — Supervision verifies that cited bases actually exist (see [ADR-0012](./0012-supervision-pure-observability.md))
- **trace-buildable** — `parent_triple_id` chains form an action tree per invocation
- **auditable** — humans can replay reasoning chains long after the fact

A practical limit must be acknowledged: LLMs can rationalise post-hoc — produce convincing reasons that do not reflect their real decision path. v1 mitigates this by mechanically verifying cited bases (cheap, catches hallucinated references); stronger semantic checks (LLM-judging whether a basis actually supports the reasoning) are deferred to v2. The principle accepts imperfect truthfulness in exchange for structured, citable, auditable narration — which is still strictly better than what most agent systems produce today.

## Consequences

- **Tool-call APIs require a triple as input.** Calls without a complete triple fail at the API layer; the agent must produce structure or get no work done. Enforcement lives in the API, not in Supervision.
- **The trace tree replaces in-agent memory.** Multi-turn flows reconstitute from the chain of past triples plus external state — consistent with [ADR-0010](./0010-stateless-agent-invocation.md).
- **Triples are the canonical observability stream.** Supervision, audits, debugging, and any future cross-agent semantic checks all read from the same trace — there is no second source of truth.
- **The cost is real.** Every tool call produces structured prose; token cost is the price of legibility. Compressing `reasoning` for trivial calls or caching identical `basis` references is permitted within the schema, not by skipping the schema.
