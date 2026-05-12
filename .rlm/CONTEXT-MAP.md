# AI Agent-Team Context Map

A multi-agent system for building and maintaining software products from zero,
following a layered architecture with three Bounded Contexts and one cross-cutting
Supervision concern. Designed for the "actually ships" school of agent design —
human-in-the-loop at three deliberate gates, autonomous between them.

> **2026-05-12 amendment notice — Path B adoption.** This document was authored
> before [agent-sweet-home](https://github.com/liyoclaw1242/agent-sweet-home) was
> selected as the workflow runtime. Three ADRs carry the architectural deltas:
>
> - **ADR-0008** — Hermes splits into Discord-bridge daemon + workflow-spawned
>   intake/design skills (sweet-home spawns `claude -p` for the skills; daemon
>   handles only Discord I/O).
> - **ADR-0011** — Event store moves from Redis stream `rlm:events` to
>   sweet-home's SQLite `one_shot_log_lines` + HTTP `/one-shot/{id}/log` API.
> - **ADR-0014** — DeliveryOrchestrator implementation is now sweet-home's
>   declarative workflow engine; config lives in `agent-team.workflow.yaml`
>   at the repo root. The "cron-triggered Python script" model in this doc's
>   bullet #2 below is superseded by sweet-home's poll loop.
>
> Each ADR's amendment is at its file's end. Inline references in this map
> still point at the right ADR — readers should follow the link and read the
> amendment alongside the original.

## Quick orientation (read first if you're new)

Four things that are easy to misread on a first pass:

1. **Hermes spans both Intake and Design BCs at the operational layer.** BCs are *language boundaries* (Spec, WorkPackage, AcceptanceCriteria are distinct concepts), not *agent boundaries*. A single Hermes agent owns conversations and design work across both — see [ADR-0008](./adr/0008-hermes-scope-lifecycle-governance.md). There is no separate "Architect" agent.

2. **Dispatch is a cron-triggered script, not an LLM.** It coordinates the Delivery pipeline mechanically, spawning `claude -p` subprocesses for Worker / Validators / Arbiter. See [ADR-0014](./adr/0014-delivery-orchestrator.md) Runtime model.

3. **Supervision is an LLM agent — but its only output is alerts.** "Pure observability" doesn't mean non-agentic; it means no enforcement. See [ADR-0012](./adr/0012-supervision-pure-observability.md) Runtime model.

4. **`agent:validator` does not distinguish white-box from black-box.** Dispatch infers which to invoke from the `retry:<stage>:<n>` label combined with the in-cycle stage it is at. The label is a coarse handoff signal; the precise stage lives in Dispatch's in-cycle chain state.

### Three coordination roles compared

| Role | What it does | When it runs | LLM? | Can halt anything? |
|---|---|---|---|---|
| **Dispatch** | Mechanical pipeline: lock, chain `claude -p`s, flip labels, count retries | Cron-triggered script (5 min default) | ❌ | Acquires/releases lock; never "halts" an agent — agents exit on their own |
| **Arbiter** | Emergency decision when an agent exits without satisfying post-condition: retry / human-help / cancel | Event-triggered by Dispatch (only on post-condition failure) | ✅ | No — its outputs are labels; Dispatch acts on them |
| **Supervision** | Read-only observation + basis verification + anomaly alerts | Cron-triggered LLM (5 min default) | ✅ | No, ever — alerts only (via Hermes → Discord) |

## Contexts

- [Intake](./bc/intake/CONTEXT.md) — translates external signals (business metrics, product observations, GitHub Issues) into structured specs. *Operational owner: Hermes (cross-cutting; see [ADR-0008](./adr/0008-hermes-scope-lifecycle-governance.md)).*
- [Design](./bc/design/CONTEXT.md) — translates specs into technical work packages and records architectural decisions. *Operational owner: Hermes (same agent as Intake, different skill set).*
- [Delivery](./bc/delivery/CONTEXT.md) — executes work packages via Worker agents, validates output through a 5-stage pipeline, and produces Pull Requests.

## Cross-cutting concerns

- **Hermes** — cross-cutting conversation + design agent, runs on the [hermes-agent](https://github.com/nousresearch/hermes-agent) framework. Operational owner of both **Intake** and **Design** BCs (BCs remain distinct as *language boundaries*, but a single agent spans them). Per-skill tool access — design-domain skills have code R; intake-domain skills do not. See [ADR-0008](./adr/0008-hermes-scope-lifecycle-governance.md).
- **Supervision** — pure observability layer; collects agent narration triples, verifies cited bases, alerts humans via Hermes on configured anomalies. Does not enforce invariants — enforcement lives in the ADRs that own each constraint. Not a BC; has no domain language of its own. See [ADR-0002](./adr/0002-supervision-as-cross-cutting.md) and [ADR-0012](./adr/0012-supervision-pure-observability.md).
- **RLM** — shared knowledge base with two backends: **GitHub Issues** for workflow items (Signal, Spec, WorkPackage — have lifecycle) and **markdown + git** for durable knowledge (CONTEXT.md, ADRs, contracts, facts, business-model snapshots). All writes flow through the unified `rlm` CLI (three routes: open PR, direct commit, create/label Issue). See [ADR-0004](./adr/0004-rlm-knowledge-base.md) and [ADR-0013](./adr/0013-spec-workpackage-lifecycle.md).
- **Resource access boundaries** — every agent has a strictly bounded scope for code / RLM / Discord / GitHub. Enforced by infrastructure, not convention. See [ADR-0009](./adr/0009-resource-access-boundaries.md).

## Relationships

- **Intake → Design**: Intake produces `Spec`; Design consumes it to produce `WorkPackage`. One Spec may map to multiple WorkPackages when scope exceeds a single Worker iteration.
- **Design → Delivery**: Design produces `WorkPackage` carrying `ImpactScope` and `ADR` references; Delivery consumes them and produces `Artifact` → `PullRequest`. Gated by human approval.
- **Delivery → Intake**: validation failures the `BlackBoxValidator` attributes to ambiguous `AcceptanceCriteria` flow back to **Intake** for spec refinement, not to Design — the root cause is a Spec defect, not an implementation defect.
- **All BCs ↔ RLM**: every agent reads RLM. Write privileges restricted per ADR-0004.
- **All BCs ↔ Supervision**: every agent emits narration triples (per [ADR-0011](./adr/0011-structured-agent-self-narration.md)); Supervision observes, verifies cited bases, and alerts — never halts.

## Runtime integrations

- **GitHub Issues** — physical home for all workflow items: Signals (Intake entry point), Specs (Hermes output), WorkPackages (Architect output). Item kind via `type:` labels; lifecycle via `status:` labels (`draft → confirmed / approved → in_progress → delivered → superseded` or `cancelled`). Bodies immutable post-gate. See [ADR-0013](./adr/0013-spec-workpackage-lifecycle.md).
- **GitHub Pull Requests** — canonical Delivery output. Human reviews and merges. No agent merges autonomously in v1.
- **Discord (via Hermes)** — human conversation channel for the three gates (Intake confirmation, Design approval, PR review escalation) and Supervision alerts. Hermes ([nousresearch/hermes-agent](https://github.com/nousresearch/hermes-agent)) is an Intake-only agent; other BCs reach Discord by handing structured payloads to Hermes. See [ADR-0008](./adr/0008-hermes-scope-lifecycle-governance.md).

## Execution invariants

- **Serial Worker execution**: at most one Worker is active globally at any time. Quality and observability take priority over speed. See [ADR-0007](./adr/0007-serial-worker-execution.md). Within a Delivery cycle, Worker → Validators → Arbiter run sequentially under the global lock. Across BCs, non-Delivery agents (Hermes, Architect) may operate while a Delivery cycle is active.
- **Stateless agent invocation**: every agent is invoked fresh; no agent retains state across invocations. State lives in Discord, Issues, RLM, and agent-output metadata. See [ADR-0010](./adr/0010-stateless-agent-invocation.md).
- **Failure budgets**: WhiteBoxValidator retry = 3, BlackBoxValidator retry = 2. Exceeded budgets escalate to Hermes → human.

## Flagged ambiguities

- **"Orchestrator"** was used early to mean both "architectural designer" and "execution coordinator" — resolved: design responsibilities live in **Hermes's design-domain skills** (per [ADR-0008](./adr/0008-hermes-scope-lifecycle-governance.md)); execution coordination is **DeliveryOrchestrator / Dispatch** (per [ADR-0014](./adr/0014-delivery-orchestrator.md)); observation is **Supervision** (not a BC, per [ADR-0002](./adr/0002-supervision-as-cross-cutting.md)). The previously-planned "Architect" agent was scrapped — its work is now Hermes's design-domain skills.
- **"Worker"** initially implied many specialist sub-types (web, server, DB, UE5, Unity, Blender). Resolved: a single **generic Worker agent** (per [ADR-0016](./adr/0016-worker-contract.md)) configured with a **`web-stack` skill profile** for v1 (frontend + server backend + DB migrations + deployment-as-code). Future domains are skill-set expansions, not new agent classes (see [ADR-0003](./adr/0003-v1-single-worker-web-stack.md)).
- **"Validator"** without qualifier was ambiguous early — resolved: always qualify as **WhiteBoxValidator** or **BlackBoxValidator**. They are distinct agents with distinct context windows.
