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

---

## Amendment 2026-05-12 — Events live in sweet-home SQLite, not a Redis stream (Path B)

### What changed

The original ADR named triples as "the canonical observability stream" but left the concrete storage layer open (working assumption was Redis stream `rlm:events` with JSONL mirror at `.local/events.jsonl`). After adopting agent-sweet-home as the workflow runtime (see ADR-0014 amendment), the event store moves to the runtime's existing SQLite-backed log:

| Old (v1 design) | New (Path B with sweet-home) |
|---|---|
| Redis stream `rlm:events` (primary) | sweet-home's SQLite `one_shot_log_lines` table |
| JSONL mirror `.local/events.jsonl` (durability) | SQLite is the durable layer; no JSONL mirror needed |
| Custom event-emission CLI (`rlm emit-triple` or equivalent) | Sweet-home captures **every stdout/stderr line** of every `claude -p` spawn automatically — including the agent's stream-json events that carry assistant text where triples appear |
| Supervision consumes via Redis XREAD | Supervision consumes via `GET /one-shot/{id}/log?since=<seq>&limit=<n>` (incremental polling) — the HTTP endpoint sweet-home already exposes for the One-Shot UI panel |
| Tool-call API enforces "no triple, no call" | **Honor-system narration** for v1: SKILL.md system prompts instruct the agent to narrate; sweet-home does not gate tool calls. See "What changes about enforcement" below. |

### What stays the same

- **The six-field schema** (`action`, `reasoning`, `basis`, `agent_id`, `parent_triple_id`, `affected_resources`) remains the recommended shape for narration. Agents who choose to emit structured narration during their reasoning steps should still use these field names.
- **Trace-buildability via `parent_triple_id` chains** is still a v1 goal, just produced by the agent's emitted prose rather than a structured API.
- **Auditability** is unchanged: every spawn's full stdout/stderr is in `one_shot_log_lines` (`runId`, `seq`, `ts`, `stream`, `text`), queryable by run_id and incrementally by `since=<seq>`.
- **Machine-checkable basis verification** (Supervision verifies cited basis references resolve) still applies — Supervision reads the log via the HTTP API instead of XREAD.
- **The "rationalisation" caveat** (LLMs may produce post-hoc reasons) remains and is mitigated the same way: cheap mechanical basis checking now, semantic LLM-judging in v2.

### What changes about enforcement

The original ADR said:
> **Tool-call APIs require a triple as input.** Calls without a complete triple fail at the API layer; the agent must produce structure or get no work done.

Sweet-home's `claude -p` invocation goes through Claude Code's native tool-use machinery — we do not own that API surface. We cannot reject a tool call for missing narration at the SDK level. **For v1, narration is honor-system, instructed in each SKILL.md.**

Mitigations:
1. **System prompt language** — every role's SKILL.md (per Path B step A, 2026-05-12) ends with an Output Contract that names the JSON envelope shape the runtime expects. Skills that comply produce the contract; skills that drift produce `on_no_structured_output` → Arbiter route, which is a visible failure not a silent one.
2. **Post-hoc verifier (Phase 2 work)** — a Supervision sub-task scans the spawn log for narration density and flags spawns where, e.g., tool-call density >> reasoning density. Not built in v1.
3. **The structured JSON envelope at end-of-spawn is enforced** — it's the single point where the runtime requires schema (without it, the workflow falls through to `on_no_structured_output`). So the per-invocation summary triple **is** mechanically enforced, just not the per-tool-call ones.

This is a real reduction in enforcement strength vs the original ADR. We accept it for Path B's simplification benefits (single observability path, no second event store) and revisit in v2 if narration quality degrades materially.

### Migration cost

- **Supervision** (deferred per ADR-0012; not built yet) — when implemented, reads from sweet-home's HTTP API, not Redis.
- **`rlm` CLI** — no `emit-triple` subcommand needed (and none was implemented in our 17-subcommand v1 set). The CLI's existing event-emission code (triples.py) targeted Redis + JSONL; that code is unused under this amendment and can stay as dead code until Phase 2 (some `rlm` subcommands may still want to emit summary events to sweet-home — but that's via writing to sweet-home's HTTP API, not Redis).
- **`.local/events.jsonl`** is now unused; safe to delete or leave alone.
- **No JSONL → SQLite migration** is needed because no events have been emitted yet (sweet-home is being adopted before our first real agent spawn).

### See

- `agent-sweet-home/src-tauri/src/one_shot.rs` — `one_shot_log_lines` table schema
- `agent-sweet-home/README.md` — `GET /one-shot/{id}/log?since=<seq>&limit=<n>` HTTP endpoint
- ADR-0014 amendment (same date) — workflow runtime adoption
- ADR-0012 (unchanged) — Supervision purity invariant
