# Five-stage sequential validation pipeline

Every Artifact passes through five validation stages in strict order:

1. **Automated white-box tools** — lint, typecheck, unit tests. No LLM.
2. **LLM WhiteBoxValidator** — full code + Spec access. Inspects logic, edge cases, security.
3. **Sandbox deployment** — the Artifact is deployed to an isolated runtime.
4. **LLM BlackBoxValidator** — Spec + running app only, no code access. Judges behaviour against `AcceptanceCriteria`.
5. **Human review hand-off** — the PR (opened by Worker per [ADR-0016](./0016-worker-contract.md)) is relabelled `agent:human-review` by Dispatch, signalling readiness for the human PR review gate.

Failure at any stage halts the pipeline and returns stage-specific feedback to the Worker. Retries are budgeted (WhiteBoxValidator = 3, BlackBoxValidator = 2); exhaustion escalates via Supervision → Hermes → human.

## Why two LLM validators, in sequence, not in parallel

The value of black-box validation comes from being unbiased by implementation. An LLM that has read the code cannot un-read it; the same agent cannot be both validators in different modes. Two distinct agents with distinct context windows are required — WhiteBoxValidator sees code, BlackBoxValidator never does.

Running them in parallel was rejected: it routinely produces contradictory rework prescriptions ("the code has issue X" vs. "the behaviour has issue Y"), forcing the Worker to guess which to address and risking regressions on the other. Sequential execution guarantees the Worker receives at most one feedback channel at a time. Stage 1 (automated tools) runs before stage 2 to fail fast on cheap mistakes without engaging the LLM validator at all.

## Consequences

- BlackBoxValidator must be architecturally and operationally separate from WhiteBoxValidator. The constraint is enforced by infrastructure, not by convention.
- BlackBoxValidator failures attributed to ambiguous AcceptanceCriteria flow back to **Intake**, not Design — the defect is in the Spec, not the implementation.
- Future Worker domains (see ADR-0003) cannot share this pipeline directly: stages 3–4 assume a runnable web Artifact. Per-domain validation profiles will be needed when expansion happens.
