# Delivery Arbiter

The **Arbiter** is a recovery agent invoked by [Dispatch](./0014-delivery-orchestrator.md) when any chained agent's `claude -p` invocation exits without satisfying its post-condition — its expected world-state changes did not happen, or only partially happened. The Arbiter reads the current state (Issue, PR, branch, comments, previous-agent triples) and decides exactly one of three outcomes: **retry the failed stage**, **escalate to `agent:human-help`**, or **mark the WorkPackage `status:cancelled`**.

## Why this exists

The architecture is end-to-end stateless ([ADR-0010](./0010-stateless-agent-invocation.md)) — every agent is invoked fresh, does work, exits. The strength of this model is observability and crash-recovery; its weakness is that a `claude -p` invocation can exit *without* completing the work it was asked to do (timeout, model error, network failure, hallucinated completion without action). Dispatch verifies post-conditions after each chained invocation. When they fail, *something has to decide what to do next*. Hard-coding that decision in Dispatch reduces Dispatch to ever-growing rule-based plumbing that cannot handle novel failure modes. Delegating to an LLM agent keeps recovery logic adaptable without distributing recovery knowledge across every agent type.

The Arbiter is invoked **only when post-condition verification fails**. In the happy path, Dispatch never calls it.

## Scope — any agent's post-condition failure

The Arbiter handles failures from **any** agent in the Delivery cycle (per I decision: option ii, not just Validator failures):

- **Worker exited without producing the expected branch + PR + fact commit + comment + label transition.**
- **WhiteBoxValidator or BlackBoxValidator exited without writing a verdict / relabel.**
- **Any future agent class** (e.g., a security stage) that fails post-condition.

Its decision logic lives in its prompt, not in code. Adding new failure modes is a prompt revision, not a structural change.

## Inputs

Arbiter reads:

- The WorkPackage Issue (body, all labels including `agent:*` and `status:*`, full comment history)
- The parent Spec Issue (AC reference)
- The branch state (last commit, presence of expected commits including fact commits)
- The PR associated with the WorkPackage, if any
- The previous agent's narration triples from the Supervision event log (per [ADR-0011](./0011-structured-agent-self-narration.md), [ADR-0012](./0012-supervision-pure-observability.md))

It does **not** read source code — recovery decisions are made at the workflow boundary, not by reanalysing implementation.

## Outputs — exactly one of three decisions

| Decision | Action |
|---|---|
| **Retry the failed stage** | Relabel to the appropriate `agent:*` for re-invocation + comment "Arbiter decision: retry <stage>; reason: <X>". Dispatch picks up on the next chain step. |
| **Escalate to human-help** | Relabel `agent:human-help` + comment with reasoning. Dispatch detects the label, releases the lock, and routes via `rlm enqueue-message` (per [ADR-0015](./0015-message-router-contract.md)). |
| **Cancel the WorkPackage** | Relabel `status:cancelled` + comment justifying cancellation. Dispatch releases the lock. The parent Spec remains active; a new WorkPackage can be created later. |

Every Arbiter invocation must produce one of these three; "no decision" is not a valid post-condition.

## Access boundaries

| Code R | Code W | RLM R | RLM W | Discord | Issue | PR |
|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| ❌ | ❌ | ✅ | ❌ | via Hermes (on escalate) | R + label changes + comment on assigned WorkPackage | ❌ |

Arbiter cannot write to RLM (no facts, no contracts, no specs, no WorkPackages); its only outputs are label changes + a comment on the WorkPackage Issue, plus optional `rlm enqueue-message` for human escalation. Recorded in [ADR-0009](./0009-resource-access-boundaries.md).

## Stateless invocation

Like every agent (per [ADR-0010](./0010-stateless-agent-invocation.md)), Arbiter is stateless per invocation. "What happened before this Arbiter invocation" comes entirely from Issue + branch + event log.

## Why a separate agent class, not Dispatch logic

Three reasons (per J decision: option α):

1. **LLM judgment over rules.** Failure modes vary; a rules engine inside Dispatch becomes a forever-growing if/else block. An LLM with a focused prompt adapts.
2. **Observability symmetry.** Arbiter emits narration triples like every other agent; its decisions are auditable in the same trace stream. Hidden Dispatch logic would not be.
3. **Dispatch stays thin.** Per [ADR-0014](./0014-delivery-orchestrator.md), Dispatch is plumbing. LLM judgment inside Dispatch violates that role.

## What if the Arbiter itself fails?

Arbiter's own `claude -p` can fail. When that happens (rare): Dispatch releases the lock, leaves the Issue in whatever state it is in, and posts a `supervision-alert` via `rlm enqueue-message` (per [ADR-0015](./0015-message-router-contract.md)) — humans then handle the case manually.

There is no recursive Arbiter-of-Arbiter. **The buck stops at humans** when the recovery mechanism itself cannot recover.

## Consequences

- **Recovery from stateless-LLM failure modes is a defined path**, not an ad-hoc retry hack.
- **Arbiter decisions are auditable.** Every recovery action has a comment trail and a triple stream.
- **Adding new agent stages does not require new recovery code.** Arbiter handles any post-condition failure under the same contract.
- **The architecture acknowledges its own fallibility.** Statelessness combined with LLM nondeterminism means agents will sometimes exit without completing — pretending otherwise would make the system brittle. Arbiter is the deliberate place where that reality is handled.
