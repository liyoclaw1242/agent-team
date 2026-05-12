# Delivery

Executes WorkPackages via a single Worker agent, runs a 5-stage validation
pipeline on every Artifact, and produces Pull Requests for human review and
merge. The only BC that touches code.

## Language

**Worker**:
A generic agent equipped with `Skill`s. Invoked by Dispatch when a WorkPackage Issue carries `agent:worker`. Within a single `claude -p` invocation, Worker writes code on a branch `wp/<issue-number>-<slug>`, calls `rlm append-fact` / `supersede-fact`, opens the PR via `rlm open-pr`, leaves a human-readable summary comment on the WorkPackage Issue, and relabels `agent:worker` → `agent:validator`. Self-declared inability path: relabel `agent:human-help` with explanatory comment instead of completing. v1 ships with a `web-stack` skill profile (per [ADR-0003](../../adr/0003-v1-single-worker-web-stack.md)); future domains are skill-set expansions, not new agent classes. Full contract: [ADR-0016](../../adr/0016-worker-contract.md). Emits narration triples per [ADR-0011](../../adr/0011-structured-agent-self-narration.md) on every invocation and tool call.

**Skill**:
A named, invokable capability available to an agent — domain knowledge encapsulated as a Claude Code skill (markdown file with defined inputs and outputs). Worker selects skills from its configured skill profile to accomplish a WorkPackage; if it needs a skill it lacks, it takes the self-declared inability path. Specific skill names are TBD pending implementation; the Worker contract ([ADR-0016](../../adr/0016-worker-contract.md)) is intentionally skill-agnostic. Adding a new domain (UE5, Blender, ...) is a skill-set expansion, not an agent class change.

**Artifact**:
The output of a Worker iteration: code changes, migration scripts, test additions, and metadata describing what was changed and why.
_Avoid_: Output, change, diff

**ValidationPipeline**:
The five sequential stages every Artifact passes through before becoming a PullRequest. Failure at any stage halts the pipeline and returns stage-specific feedback to the Worker. See [ADR-0006](../../adr/0006-validation-pipeline.md).

**DeliveryOrchestrator** (a.k.a. **Dispatch**):
The coordination layer that owns this BC's runtime mechanics: holding the global Worker lock, chaining `claude -p` invocations within a single Dispatch run (Worker → Validators → Arbiter as needed), driving WorkPackage lifecycle transitions (`mark-in-progress`, `mark-delivered`), counting retries against `RetryBudget`, and escalating to Hermes when budgets exhaust. Worker (not Dispatch) opens the PR. **Dispatch is a cron-triggered orchestration script — not an LLM agent and not a long-running daemon** (per [ADR-0014](../../adr/0014-delivery-orchestrator.md) Runtime model). Holds no domain knowledge; has no code access; stateless per cron tick (its "memory" is the global lock + Issue labels + Supervision event log). Emits failure events and lifecycle-transition records to the Supervision event log; does **not** emit narration triples — that contract (per [ADR-0011](../../adr/0011-structured-agent-self-narration.md)) is for LLM-agent invocations only.

**Arbiter** (Delivery):
A recovery agent invoked by Dispatch when any chained agent's `claude -p` invocation exits without satisfying its post-condition. Reads the WorkPackage Issue, branch state, PR, and event-log triples; decides exactly one of three outcomes: **retry the failed stage**, **escalate to `agent:human-help`**, or **mark the WorkPackage `status:cancelled`**. Cannot read code; cannot write RLM. Full contract: [ADR-0017](../../adr/0017-delivery-arbiter.md). Emits narration triples per [ADR-0011](../../adr/0011-structured-agent-self-narration.md).

**WhiteBoxValidator**:
The LLM validator with full access to code and Spec. Inspects logic, edge cases, security, and adherence to Design. Stage 2 of the pipeline. Distinct agent from BlackBoxValidator. Emits narration triples per [ADR-0011](../../adr/0011-structured-agent-self-narration.md) on every invocation and tool call.

**BlackBoxValidator**:
The LLM validator that sees only the Spec and the running Artifact behaviour. Has no access to source code, deliberately, to stay unbiased by implementation. Stage 4 of the pipeline. Distinct agent from WhiteBoxValidator. Emits narration triples per [ADR-0011](../../adr/0011-structured-agent-self-narration.md) on every invocation and tool call.

**RetryBudget**:
The capped number of rework attempts per validation stage. v1: WhiteBoxValidator = 3, BlackBoxValidator = 2. Exhaustion escalates via Supervision → Hermes → human.

**PullRequest**:
The final, human-reviewable output of this BC. A GitHub PR. No agent merges autonomously in v1.

## Relationships

- A **WorkPackage** is consumed by one **Worker**, which produces one **Artifact** per iteration.
- An **Artifact** enters the **ValidationPipeline**; only artifacts that pass all five stages become **PullRequests**.
- Failures within the **RetryBudget** loop back to the same Worker with stage-specific feedback only.
- Failures exceeding the **RetryBudget** escalate via Supervision → Hermes → human.
- **BlackBoxValidator** failures attributed to ambiguous AcceptanceCriteria flow back to **Intake**, not Design — the root cause is a Spec defect.

## Workflow labels on WorkPackage Issues

A WorkPackage Issue carries multiple label axes that together encode its full state. The `rlm` CLI is the only writer (per [ADR-0004](../../adr/0004-rlm-knowledge-base.md)).

**`type:*`** — kind of workflow item:
- `type:spec` — Hermes's published output (Intake)
- `type:workpackage` — Hermes's design-domain output (Design BC, via `decompose-spec` skill)
- `type:signal` — Raw input from human or ProductionMonitor
- `type:supervision-alert` — Anomaly raised by Supervision, Hermes (stale-fact detection during design-domain skill), or Dispatch (Arbiter failure)

**`status:*`** — lifecycle state (exactly one at a time):
- `status:draft` → `status:confirmed` / `status:approved` → `status:in_progress` → `status:delivered`, with terminal exits `status:cancelled` and `status:superseded` (see [ADR-0013](../../adr/0013-spec-workpackage-lifecycle.md)).

**`agent:*`** — current chain handoff (Delivery only):
- `agent:worker` — Dispatch has assigned this; Worker should pick up
- `agent:validator` — Worker exited; Validators (white-box, then black-box) should run in chain
- `agent:human-review` — Validators passed; PR is ready for human review
- `agent:human-help` — Worker self-decline or Arbiter escalation; human intervention required

**`retry:<stage>:<n>`** — Dispatch's machine-readable retry counter (single current value per stage, replaced on each retry):
- `retry:white-box:N` — current WhiteBox retry attempt (max 3 per [ADR-0006](../../adr/0006-validation-pipeline.md))
- `retry:black-box:N` — current BlackBox retry attempt (max 2)

**`outbound:<kind>`** — message destined for Discord (see [ADR-0015](../../adr/0015-message-router-contract.md)):
- `outbound:retry-exhausted`, `outbound:ac-ambiguity`, `outbound:supervision-alert` — sent by *other* agents (Dispatch, Supervision); Hermes routes them on next cron tick.
- `outbound:intake-confirmation`, `outbound:design-approval` — Hermes self-originates. Hermes posts in-line during its own invocation (no routing latency); the label exists for audit symmetry and is removed when Hermes processes the human reply.

A WorkPackage Issue's full state at any moment is the join of these axes — e.g. `type:workpackage` + `status:in_progress` + `agent:validator` + `retry:white-box:2`.

## Example dialogue

> **Worker:** "WorkPackage DES-47 done. Artifact: inlined address summary in payment step, 8 unit tests added, 2 existing tests adjusted."
> **WhiteBoxValidator:** "Pass. Minor note: the new `summariseAddress` helper duplicates logic in `formatBillingAddress`; consider extracting in a follow-up."
> **(sandbox deploy)**
> **BlackBoxValidator:** "Fail. AcceptanceCriterion 'completion event fires once per successful checkout' — the event fires twice when a user toggles the address summary open and then submits. Retry 1/2 with details."
> **Worker:** "Fixed: event now bound to submit, not summary state. Re-running."
> **BlackBoxValidator:** "Pass."
> **Delivery:** "PR #214 opened. Awaiting human review."

## Flagged ambiguities

- **"Validator"** without qualifier was ambiguous early — resolved: always qualify as **WhiteBoxValidator** or **BlackBoxValidator**.
- **"Worker"** implied multiple specialists in early discussion — resolved for v1: single web-stack Worker. Future workers are scope, not capability.
