# RLM: storage, write interface, and lifecycle

The RLM (Retrieval-augmented knowledge base) spans two physical backends: **GitHub Issues** for workflow items that flow through lifecycle gates (Signal, Spec, WorkPackage), and **curated markdown files in the repository** for durable knowledge (ADRs, contracts, code-derived facts, business-model snapshots). All writes flow through the unified `rlm` CLI, which enforces format, permissions, and routing. Conflicts resolve through git or GitHub's native primitives; staleness is detected on read, not by background scan.

## Storage

**Workflow items (have lifecycle — stored as GitHub Issues):**

- `type:signal` — raised by a human or by ProductionMonitor; the system's entry point.
- `type:spec` — produced by Hermes after IntakeConfirmation; immutable once confirmed.
- `type:workpackage` — produced by Hermes (design-domain skill `decompose-spec`) after DesignApproval; immutable once approved.

Lifecycle flows via `status:` labels (`draft → confirmed / approved → in_progress → delivered → superseded` or `cancelled`). Body content is canonical; comments support discussion without changing the body. See [ADR-0013](./0013-spec-workpackage-lifecycle.md) for the discipline.

**Knowledge documents (no lifecycle — stored as markdown in repo):**

```
D:\darfts\
├── .rlm\                     RLM root (knowledge base; CLI reads/writes here)
│   ├── CONTEXT-MAP.md
│   ├── bc\{bc}\CONTEXT.md
│   ├── adr\                  decisions
│   ├── contracts\            API / event / schema definitions
│   ├── facts\                code-derived facts (append-only, supersede chain)
│   ├── business\             BusinessModel / DeploymentConstraints snapshots
│   ├── v2-todo.md            tracked open architectural decisions
│   └── flow-visualization.html
└── src\                      application code (Worker-written; empty until v1 ships)
```

Git is the version system for markdown; GitHub Issue events are the version system for workflow items. No additional database, no vector store in v1. `grep` and `gh issue list` are the baseline query interfaces.

## Write interface: the `rlm` CLI

All RLM writes go through `rlm <subcommand>`. The CLI:

- **Enforces format** — required args map to required fields (frontmatter for markdown, structured body + labels for Issues); agents cannot emit malformed entries.
- **Enforces permission** — each subcommand is callable only by the agent class declared in [ADR-0009](./0009-resource-access-boundaries.md).
- **Routes writes** — three modes: open PR, direct commit, create/label Issue.
- **Self-narrates** — each invocation emits a triple per [ADR-0011](./0011-structured-agent-self-narration.md).

The full v1 subcommand set:

| Subcommand | Caller | Backend | Routing |
|---|---|---|---|
| `propose-adr` | Hermes (`draft-adr` skill) | `.rlm/adr/NNNN-slug.md` | Opens PR |
| `propose-context-change` | Hermes (design-domain skill) | `.rlm/bc/{bc}/CONTEXT.md` or `CONTEXT-MAP.md` | Opens PR |
| `add-contract` | Hermes (`draft-contract` skill) | `.rlm/contracts/{slug}.md` | Opens PR |
| `append-fact` | Worker | `.rlm/facts/{date}-{slug}.md` | Direct commit |
| `supersede-fact` | Worker | `.rlm/facts/{date}-{slug}.md` (frontmatter `supersedes:`) | Direct commit |
| `append-business-model` | Hermes | `.rlm/business/business-model-{date}.md` | Direct commit |
| `append-deployment-constraints` | Hermes | `.rlm/business/deployment-constraints-{date}.md` | Direct commit |
| `commit-spec` | Hermes | GitHub Issue (`type:spec`, `status:draft`) | Create Issue |
| `confirm-spec` | Hermes (after IntakeConfirmation ack) | Spec Issue: `status:confirmed`, body becomes immutable | Label change + freeze |
| `commit-workpackage` | Hermes (`decompose-spec` skill) | GitHub Issue (`type:workpackage`, `status:draft`, lists `adr_refs`) | Create Issue |
| `approve-workpackage` | Hermes (after DesignApproval ack) | WorkPackage Issue: `status:approved`, body becomes immutable. **CLI mechanically verifies every `adr_refs` entry already exists in `main`; refuses if any referenced ADR PR is still pending.** | Label change + freeze + verify |
| `record-signal` | Hermes (ProductionMonitor) | GitHub Issue (`type:signal`) | Create Issue |
| `mark-superseded` | Hermes | Existing Issue: `status:superseded` + reference to superseding Issue | Label change |
| `mark-in-progress` | DeliveryOrchestrator | WorkPackage Issue: `status:in_progress` + `agent:worker` | Label change |
| `mark-delivered` | DeliveryOrchestrator (after CI fact-commit check passes) | WorkPackage Issue: `status:delivered` | Label change |
| `open-pr` | Worker | GitHub PR from the WorkPackage branch, links the WorkPackage Issue | Create PR |
| `enqueue-message` | Hermes (self-routing), DeliveryOrchestrator, Supervision | Comment + `outbound:<kind>` label on parent Issue, OR new `type:supervision-alert` Issue | Hermes routes on next cron — see [ADR-0015](./0015-message-router-contract.md) |

## Three routing modes, one principle

- **PR-routed (decisions):** ADRs, CONTEXT.md changes, contracts. These are *commitments* the system will rely on; human PR review is the gate.
- **Direct-commit (observations):** facts, business-model snapshots, deployment constraints. These record *current reality*; the gate that mattered already fired upstream (Spec confirmation via Hermes; Hermes's own design-domain curation).
- **Issue-routed (workflow items):** Signals, Specs, WorkPackages. These have *lifecycle and discussion*; GitHub's labels, comments, and Issue references express that lifecycle natively.

For Hermes specifically: by the time it calls `commit-spec`, IntakeConfirmation has already gated the human ack. By the time Hermes calls `commit-workpackage` (via the `decompose-spec` design-domain skill), DesignApproval has gated it. Neither needs a PR.

## Workflow item immutability

Once a Spec Issue receives `status:confirmed` or a WorkPackage Issue receives `status:approved`, **its body is immutable**. Required changes happen by creating a new Issue with `Supersedes #<old>` in its body, and labelling the old one `status:superseded`. This mirrors the `supersede-fact` discipline applied to RLM facts.

Comments are not body changes — humans and agents may comment freely for context, but the canonical content does not change.

## Conflict resolution

- **PR-routed writes:** standard merge-conflict resolution at the PR.
- **Direct-commit writes:** append-only by construction; unique time-stamped filenames eliminate overwrite.
- **Issue-routed writes:** immutability + supersession eliminates body-conflict modes; concurrent label changes resolve last-writer-wins (acceptable for monotonic lifecycle transitions).

## Staleness — verified on read, not scanned in background

Facts in `.rlm/facts/` carry `last_verified` in frontmatter. When an agent cites a fact as `basis` per [ADR-0011](./0011-structured-agent-self-narration.md), Supervision's basis verification (per [ADR-0012](./0012-supervision-pure-observability.md)) checks freshness:

- **For `.rlm/facts/`** — cited code shape is checked against current code. Mismatch behaviour follows the **Approach F discipline** (Worker is the sole writer of facts):
  - **Worker** detects stale → calls `supersede-fact` during its normal RLM-write flow (it is changing code and knows the new shape).
  - **Hermes (design-domain skill)** detects stale → **does not** supersede the fact; falls back to reading code directly (design-domain skills have read-only code access per [ADR-0009](./0009-resource-access-boundaries.md)) and emits `enqueue-message --kind=supervision-alert` flagging the stale fact for eventual Worker correction. Rationale: facts describe code reality, and only the agent that *owns* that reality (Worker, which writes code) is qualified to rewrite them — letting Hermes derive a "fix" from a read-only view risks LLM hallucination corrupting the knowledge base.
  - **Validators** detect stale → fail the validation stage with an explicit "stale basis: fact `<id>` differs from code" message; Dispatch returns control to Worker, which supersedes the fact during its retry pass.
- **For `.rlm/business/`** — no automatic check; humans curate freshness via new Hermes-written entries.
- **For workflow Issues** — the lifecycle label *is* the freshness signal. `delivered` and `superseded` Issues are historical by construction (see [ADR-0013](./0013-spec-workpackage-lifecycle.md)).

Periodic background scans are explicitly rejected: too expensive, too noisy, and verify-on-read catches every fact actually used.

## A note on Supervision's event log

Supervision's high-volume event log (every triple, every failure event, every alert) is **operational data, not RLM**. It lives in its own queryable log infrastructure. RLM entries by Supervision are reserved for curated incident summaries; v1 ships without such a subcommand.

## Consequences

- **No `.rlm/specs/`, `.rlm/workpackages/`, or `.rlm/monitoring/`.** Workflow items live as Issues, eliminating a class of "is this current?" confusion (lifecycle is a label, not a filename guess).
- **Three storage backends, one CLI.** Agents do not know which backend a subcommand uses; the CLI hides that.
- **The repo + GitHub Issues *are* the RLM.** No separate "knowledge service" — the same artifacts humans use are the ones agents query. Two systems collapse into one.
- **Vector search is deferred.** When RLM growth exceeds grep/`gh issue list`, a vector index can be added without changing the source-of-truth — the index is a *view*.
- **Future Worker specialists** inherit the same RLM contract; the Issue/markdown split is at the workflow boundary, not the Worker class boundary.
