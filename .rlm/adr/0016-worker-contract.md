# Worker contract

The Worker is a **generic agent equipped with `Skill`s**. Its sole job: read a `type:workpackage` Issue labelled `agent:worker`, accomplish its goal by invoking whatever skills it has, produce code on a WorkPackage-named branch, append the fact(s) reflecting the change, open the PR, leave a human-readable summary comment, and hand off to validators by relabelling `agent:worker` → `agent:validator`. **All five outputs happen within a single `claude -p` invocation**; statelessness is preserved by externalising every artifact (branch, fact files, Issue labels, PR, comment).

## Why a generic Worker with skills (not specialised Worker classes)

[ADR-0003](./0003-v1-single-worker-web-stack.md) originally framed v1 as "a single Worker specialised in `web-stack`," with future Workers (UE5, Blender) as separate agent classes. The Worker-with-skills framing — settled in the round that produced this ADR — is structurally cleaner:

- **One agent class, many capabilities.** Adding UE5 in v2 means adding skills, not adding a new Worker. The contract is skill-agnostic; the agent is the same.
- **Symmetric with Hermes.** Hermes is a cross-cutting agent equipped with skills spanning Intake (probes, monitor) and Design (decompose-spec, draft-adr, select-deployment-strategy, etc.); Worker follows the same *generic agent + skill toolkit + `rlm` CLI* shape. See [ADR-0008](./0008-hermes-scope-lifecycle-governance.md).
- **ADR-0003's promise becomes operational.** "Future specialists slot in without restructuring the Delivery BC" is now concrete: drop new skills into the skill set; the Worker contract does not change.

The skill set for v1 is intentionally **not** enumerated here — the contract is what matters. Implementation defines the specific skills (frontend, backend, db migration, test, refactor, etc.).

## Input — what Worker reads when invoked

Worker is invoked by [Dispatch](./0014-delivery-orchestrator.md) when an Issue carries `type:workpackage`, `status:in_progress`, and `agent:worker`. On invocation, it reads:

| Source | Purpose |
|---|---|
| The WorkPackage Issue (body, comments, label history) | What to do; scope; depends_on; retry history (per H decision: comment trail is the canonical retry counter) |
| Parent Spec Issue (`Refs #<spec>`) | AcceptanceCriteria reference only — never as current-state input (per [ADR-0013](./0013-spec-workpackage-lifecycle.md)) |
| Code (read + write per [ADR-0009](./0009-resource-access-boundaries.md)) | Current implementation |
| `.rlm/facts/` (non-superseded) | Current behavioural truths |
| `.rlm/contracts/` | API / event / schema definitions |
| Relevant ADRs | Historical decision context |

Worker **does not** read past Specs or past WorkPackages as current-state references (per ADR-0013 source-of-truth discipline).

## Output — atomic within one `claude -p` invocation

When Worker's `claude -p` exits successfully, **all five** must be true:

1. **A branch** named `wp/<issue-number>-<slug>` exists with the code changes.
2. **At least one `rlm append-fact` or `rlm supersede-fact` commit** is included in the branch (CI enforces on PR close per [ADR-0013](./0013-spec-workpackage-lifecycle.md)).
3. **A PR** is opened via `rlm open-pr`, linking the WorkPackage Issue.
4. **A summary comment** on the WorkPackage Issue states *what was done* and *why* — human-readable counterpart to the machine-readable triples (per [ADR-0011](./0011-structured-agent-self-narration.md)).
5. **The Issue label** has transitioned from `agent:worker` to `agent:validator`.

Failure to produce all five = incomplete cycle; Dispatch invokes the [Arbiter](./0017-delivery-arbiter.md) to decide recovery (per [ADR-0014](./0014-delivery-orchestrator.md)).

## Self-declared inability

If Worker determines it cannot complete the WorkPackage (no relevant skill, ImpactScope file no longer exists, Spec contradicts current code irreducibly), it must **not** partially commit. It must:

1. Leave a comment on the WorkPackage Issue explaining *why* with cited basis (per [ADR-0011](./0011-structured-agent-self-narration.md)).
2. Relabel `agent:worker` → `agent:human-help` **and** set `status:cancelled`. Both labels are set together: `agent:human-help` signals that human attention is required; `status:cancelled` terminates the WorkPackage (per [ADR-0013](./0013-spec-workpackage-lifecycle.md)) because a self-declared inability is not recoverable by re-running the same Worker against the same WorkPackage — the parent Spec remains active and Hermes can produce a fresh WorkPackage if the human resolves the underlying gap.
3. Exit cleanly.

Dispatch detects `agent:human-help` (or equivalently `status:cancelled` on a self-decline exit), releases the global lock, and routes the issue via `rlm enqueue-message` (per [ADR-0015](./0015-message-router-contract.md)).

**Worker should err on early inability declaration** rather than burning retry budget on something it knows it cannot do.

## Retry semantics

On validator rejection within budget ([ADR-0006](./0006-validation-pipeline.md): WhiteBox = 3, BlackBox = 2 — per G decision), Dispatch relabels back to `agent:worker` and re-invokes Worker.

**The machine-readable retry counter is the `retry:<stage>:<n>` label on the WorkPackage Issue.** Dispatch maintains a single current value per stage, replacing the previous label on each retry (`retry:white-box:1` → `retry:white-box:2`). Comments still narrate every attempt in natural language for human readability, but the *counter* is the label — parsing comments for arithmetic is fragile by design and not permitted.

Worker reads the WorkPackage Issue to know:
- The current `retry:<stage>:<n>` label — which stage and which attempt this is (machine-readable, robust).
- The comment thread — which validator failed, the specific failure, what was tried previously (human-readable narrative).

Each retry is a fresh `claude -p` invocation; statelessness is preserved.

## Skills

The skill set is intentionally TBD in this ADR; the contract is **skill-agnostic** (per K2 decision). When skills are implemented:

- Each skill is a Claude Code skill (markdown file invokable by name) with defined inputs and outputs.
- Adding new skills or skill sets (for future Worker domains) does **not** modify this contract.

The only invariant: **a Worker invocation must use only skills present in its configured skill set**. If Worker determines it needs a skill it lacks, that is the self-declared inability path.

## Worker also handles PR creation (revising ADR-0014 round-1 design)

A previous round of this architecture (the audit-fix round) attributed PR creation to Dispatch. The current design returns PR creation to Worker (per K1 decision):

- Worker knows what was done; Worker writes the PR title and description.
- All five outputs happen in one stateless invocation — simpler post-condition check.
- Dispatch becomes purely a coordinator; it never writes code, branches, or PRs.

`rlm open-pr` is callable by Worker (matrix updated in [ADR-0009](./0009-resource-access-boundaries.md) and table updated in [ADR-0004](./0004-rlm-knowledge-base.md)).

## Consequences

- **Worker is thin.** Almost all *what to do* comes from the WorkPackage; almost all *how to do it* comes from skills. Worker is the orchestrator-of-skills, not the doer.
- **Stateless is preserved end-to-end.** Each `claude -p` reads Issue + branch + comments + RLM; nothing persists across invocations.
- **Retry history is human-readable.** Issue comments narrate every attempt — humans can audit a stuck WorkPackage by reading the thread.
- **Adding a Worker domain (UE5, Blender, etc.) is a skill-set expansion**, not a new agent class. ADR-0003 is updated accordingly.
- **The post-condition check is now well-defined.** Five concrete outputs to verify after each Worker invocation — Dispatch can decide deterministically whether to chain forward or invoke the Arbiter.
