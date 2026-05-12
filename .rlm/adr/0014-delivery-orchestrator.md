# Delivery Orchestrator

A named coordination agent — **DeliveryOrchestrator** — owns the Delivery BC's runtime mechanics: ValidationPipeline sequencing, WorkPackage lifecycle transitions (`mark-in-progress`, `mark-delivered`), retry counting against `RetryBudget`, PR creation, and escalation routing. The orchestrator is thin — it holds no domain knowledge; it executes the contract specified by other ADRs.

## Why

Before this ADR, the Delivery BC's runtime sequencing was implicit. The 5-stage ValidationPipeline ([ADR-0006](./0006-validation-pipeline.md)), the global Worker lock ([ADR-0007](./0007-serial-worker-execution.md)), and the lifecycle label transitions ([ADR-0013](./0013-spec-workpackage-lifecycle.md)) all assumed a coordinator existed but no agent held the title. The fresh-eye audit surfaced concrete consequences:

- `mark-in-progress` had no caller — Worker is under lock and cannot self-promote.
- `mark-delivered` was attributed to "(auto, on PR merge)" with no agent listed in [ADR-0009](./0009-resource-access-boundaries.md).
- PR creation was attributed to Worker but no `rlm` CLI subcommand existed for it — Worker would have to exit the RLM framework (and the narration / basis observability with it).

Naming a single agent — DeliveryOrchestrator — closes all three gaps and gives a clean home for future runtime concerns (WorkPackage `depends_on` ordering, token-budget enforcement, dependency-aware queueing).

## Responsibilities

The DeliveryOrchestrator:

- **Consumes** approved WorkPackage Issues (`type:workpackage`, `status:approved`).
- **Acquires** the global Worker lock (per ADR-0007) before activating the Worker.
- **Transitions** the WorkPackage to `status:in_progress` via `rlm mark-in-progress`.
- **Hands** the WorkPackage to the Worker; receives an Artifact bundle on the WP's branch.
- **Sequences** the 5-stage ValidationPipeline (per [ADR-0006](./0006-validation-pipeline.md)). Worker has *already* opened the PR before exiting (per [ADR-0016](./0016-worker-contract.md)); the pipeline runs against that existing PR:
  - stage 1 (automated tools): runs lint/typecheck/unit on the PR; failure returns to Worker
  - stage 2 (WhiteBoxValidator): invokes it; failure returns to Worker with feedback
  - stage 3 (sandbox deploy): performs deploy of the PR's branch
  - stage 4 (BlackBoxValidator): invokes it; routes failures by classification (AC-ambiguity → return to Intake per [ADR-0013](./0013-spec-workpackage-lifecycle.md); implementation defect → return to Worker)
  - stage 5 (human review hand-off): relabels `agent:human-review` and exits the chain to wait for PR merge
- **Counts** retries against each stage's `RetryBudget`; escalates via Hermes on exhaustion.
- **Releases** the Worker lock when the Dispatch run completes — at stage 5 (`agent:human-review` relabel), escalation (`agent:human-help`), or cancellation (`status:cancelled`). **The lock is *not* held while waiting for the human PR review.** Subsequent Dispatch cron ticks may pick up other WorkPackages while #X awaits review.
- **Transitions** the WorkPackage to `status:delivered` (via `rlm mark-delivered`) after the closing PR is merged **and** the CI fact-commit check has passed (per [ADR-0013](./0013-spec-workpackage-lifecycle.md)). **This happens on a *later, separate* Dispatch cron tick** that detects the merged PR — *not* within the cycle that originally processed the WorkPackage (the lock was released long ago).
- **Routes** BlackBox AC-ambiguity findings back to Intake (specific mechanism to be specified in the forthcoming message-router ADR).

## What it does not do

- **Does not write code.** Only Worker writes code (per ADR-0009).
- **Does not author Specs, WorkPackages, ADRs, contracts, business-model snapshots, or facts.** Those belong to the agents who own them.
- **Does not decide content** beyond mechanical lifecycle moves. The decisions are in WorkPackages, AcceptanceCriteria, and Validator outputs; the orchestrator plumbs them.
- **Does not enforce serial-Worker — the global lock does** (per ADR-0007). The orchestrator just acquires it.
- **Does not halt agents.** Supervision still never halts (per ADR-0012). Retry-budget exhaustion returns control to the caller (Hermes → human), it does not "kill."

## Stateless invocation

Like every other agent (per [ADR-0010](./0010-stateless-agent-invocation.md)), the DeliveryOrchestrator is stateless. Each invocation reconstitutes the WorkPackage's state by reading:

- the WorkPackage Issue (current `status:` and `agent:*` labels, body, comment history),
- the pipeline-stage event record in Supervision's event log,
- the branch state (last commit, presence of fact commits, validation event references).

"Pick up where I left off" comes from these external sources, not from in-memory state.

## Runtime model — cron-triggered script, not a daemon or `claude -p`

Dispatch is **not** a `claude -p` invocation and **not** a long-running daemon. It is a cron-triggered orchestration script (implementation choice: shell, Python, etc.):

1. Fires every N minutes (5 min default for v1).
2. Checks the global Worker lock.
3. If lock is free and there is approved work: acquires the lock, then *within its own process lifetime* chains `claude -p` invocations (Worker → Validators → Arbiter as needed).
4. Releases the lock when the chain reaches a terminal state for this cycle (stage-5 handoff, escalation, or cancellation).
5. Exits.

Each `claude -p` Dispatch spawns is a separate stateless subprocess. The Dispatch script itself holds no state across cron ticks — its "memory" is the global lock + Issue labels + Supervision event log. This satisfies the [ADR-0010](./0010-stateless-agent-invocation.md) stateless invariant for *LLM agents*: Dispatch is operational infrastructure (analogous to the hermes-agent daemon for Hermes), not itself an LLM agent.

## In-cycle chaining and post-condition verification

Dispatch is not just a cron-triggered scheduler; *within* a single Dispatch run that holds the lock, it chains multiple `claude -p` invocations (Worker → Validators → Arbiter if needed) until the cycle reaches a terminal state (`status:delivered`, `status:cancelled`, or `agent:human-help`). The cron tick is for **acquiring the lock and starting a cycle**; in-cycle transitions happen at process boundaries within the same Dispatch run, not at subsequent cron ticks.

After each chained `claude -p` exits, Dispatch performs a **post-condition check** appropriate to the agent that just ran:

- Worker exit → branch + PR + at least one fact commit + summary comment + label `agent:validator` all present?
- WhiteBoxValidator exit → verdict (pass or specific failure feedback) recorded on the Issue?
- BlackBoxValidator exit → verdict recorded, AC-ambiguity flag set if applicable?

When the post-condition is satisfied, Dispatch advances. When it is not, Dispatch invokes the **[Arbiter](./0017-delivery-arbiter.md)** to decide recovery. The Arbiter's labelled decision (`agent:worker` retry, `agent:human-help`, or `status:cancelled`) determines the next chain step.

A Dispatch run that cannot advance (Arbiter itself fails, or escalation to `agent:human-help` happens) **releases the lock and exits**. The next cron tick treats the WorkPackage as ineligible for re-activation until a human intervenes.

## Access boundaries

DeliveryOrchestrator's scope, recorded in the [ADR-0009](./0009-resource-access-boundaries.md) revision in this round:

| Code R | Code W | RLM R | RLM W | Discord | Issue | PR |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| ❌ | ❌ | ✅ | ✅ WorkPackage labels only | via Hermes | R + flip `status:` and `agent:*` on assigned WP | ❌ |

Notably:
- Cannot read code — does not need to; sequencing is content-blind.
- Cannot write facts — that is Worker's domain.
- Cannot write contracts, ADRs, or CONTEXT changes — those belong to Hermes's design-domain skills (see [ADR-0008](./0008-hermes-scope-lifecycle-governance.md)).
- Cannot edit WorkPackage bodies — immutability is preserved per ADR-0013.

## Consequences

- **Worker opens the PR within its own `claude -p` invocation** (per [ADR-0016](./0016-worker-contract.md)), bringing PR creation inside the narration/basis observability framework. Dispatch *verifies* the post-condition (PR exists, fact commit included, label transitioned to `agent:validator`) but does not create the PR itself.
- **WorkPackage lifecycle has a clear actor.** `mark-in-progress` and `mark-delivered` are both DeliveryOrchestrator calls; the CI fact-commit check is a precondition for `mark-delivered` but not the actor.
- **Adding a future ValidationStage** (e.g., a security validator) means modifying the orchestrator's sequence — one place, not many.
- **Token-budget control (deferred per ADR-0012) lands here naturally.** When the ADR materialises, DeliveryOrchestrator is the enforcement point.
- **WorkPackage `depends_on` ordering** (audit hole) is the orchestrator's responsibility when introduced — it already owns the activation gate.
- **The architecture no longer assumes invisible coordination.** Every lifecycle move is traceable to a named agent emitting triples.
