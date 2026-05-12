# Stateless agent invocation

Every agent in the system is invoked fresh. No agent retains state across invocations. All state lives in external, durable systems — Discord threads for conversations, GitHub Issues for task lifecycle, RLM for knowledge and history, WorkPackage / Artifact / Supervision-event metadata for in-flight work.

## Why

Long-running, context-accumulating agents are the central failure mode of multi-agent architectures: they grow opaque, become unsafe to restart, and develop emergent behaviour that cannot be audited. The "all-knowing Architect agent" and "self-evolving Hermes" anti-patterns this design has repeatedly rejected are both instances of the same root mistake — agent state living inside the agent.

Stateless invocation forces the opposite: state is **legible** (you can read the Discord thread, the Issue history, the RLM), **durable** (it survives an agent crash), and **parallel-testable** (you can re-run an invocation against the same external state and reproduce the result). These properties compound — losing any one of them in pursuit of "remembering more in-context" sacrifices the others as well.

The cost — every invocation re-reads its context — is real but bounded. RLM retrieval is already required for knowledge-aware reasoning; re-reading a Discord thread is cheap; Issue state is essentially free. The cost is paid in tokens, not in design clarity.

## Consequences

- **No "session" abstraction.** Multi-turn flows (BusinessModelProbe, DesignApproval, BlackBoxValidator retries) are sequences of stateless turns each reconstituting from Discord + Issues + RLM. There is no in-memory session object.
- **ProductionMonitor is not an exception.** It polls continuously, but each poll is a fresh, stateless invocation. Its watched metrics and thresholds live in configuration / RLM, not in agent memory.
- **Agent crash is harmless.** A killed Hermes / Architect / Worker / Validator resumes on next invocation with no loss — all relevant state was external.
- **Supervision's event log becomes the operational ground truth.** Since no agent retains a private log of what it did, Supervision's externalised record is the canonical history.
- **Token cost goes up; design risk goes down.** This is the intentional trade. Optimisation of per-invocation read cost (caching, partial reads) is permissible *within* the principle — bypassing the principle for performance is not.
- **v1 reference runtime is `claude -p` non-interactive invocations**, triggered by cron, GitHub Actions, or parent-agent CLI calls. Other stateless runtimes are permitted; long-running agent processes (daemons, persistent sessions, `claude serve`-style) are forbidden by this principle. The runtime choice is operational; the invariant is statelessness.
- **Framework infrastructure may be long-running; LLM cognition must not be.** Specifically, Hermes runs on the [hermes-agent](https://github.com/nousresearch/hermes-agent) framework (per [ADR-0008](./0008-hermes-scope-lifecycle-governance.md)), which is itself a long-running event-loop daemon. The daemon is *infrastructure* — it accepts Discord / cron / webhook events and *spawns* fresh LLM invocations to handle them. Each LLM invocation reads the world from scratch (Discord thread + RLM + Issues) and exits. This satisfies the principle. The hermes-agent framework's optional features that *would* violate the principle — cross-session memory and autonomous skill creation — are explicitly disabled for v1.
