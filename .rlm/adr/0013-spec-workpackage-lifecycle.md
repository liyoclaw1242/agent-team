# Spec / WorkPackage lifecycle and source-of-truth discipline

Specs and WorkPackages are workflow items with explicit lifecycle states recorded on their GitHub Issues. Their content is immutable once they pass their gate (`confirmed` for Spec, `approved` for WorkPackage); their state advances via labels. Once a WorkPackage is `delivered`, neither it nor its parent Spec represent the system's *current* state — they are historical decisions. The system's current state is read from code, `.rlm/facts/` (non-superseded), and `.rlm/contracts/`.

## Why

SDD-style development collapses after a few iterations when Specs accumulate without lifecycle distinction. By iteration 3, agents and humans alike cannot tell which Spec describes "what the system intends today" vs. "what we asked for nine months ago and have since changed." Architects reading old Specs as current-state references produce WorkPackages built on phantom assumptions; Workers execute those WorkPackages and produce code that diverges from production. The failure is invisible until catastrophic.

The cure has three parts, all enforced by the architecture:

1. **Lifecycle is explicit and machine-readable** — `status:` labels on Issues.
2. **Spec / WorkPackage bodies are immutable post-gate.** Changes happen by superseding Issues, never by editing.
3. **The source of truth for current state is not Specs.** Architect and Worker read code, facts, and contracts to learn what the system *is*. Specs and WorkPackages tell the system what was *requested then*.

## Lifecycle states

A `type:spec` or `type:workpackage` Issue carries exactly one `status:` label at a time:

| Label | Meaning | Applies to | Set by |
|---|---|---|---|
| `status:draft` | Being drafted; body may change | spec, workpackage | `rlm commit-spec` / `rlm commit-workpackage` |
| `status:confirmed` | Past IntakeConfirmation; body **immutable** | spec | `rlm confirm-spec` (Hermes, after human ack) |
| `status:approved` | Past DesignApproval; body **immutable**. CLI mechanically verifies all `adr_refs` exist in `main` before allowing the transition. | workpackage | `rlm approve-workpackage` (Hermes, after human ack + ADR-merge check) |
| `status:in_progress` | Worker has picked this up | workpackage | Dispatch via `rlm mark-in-progress` |
| `status:delivered` | PR merged with fact commit; CI check passed | workpackage | Dispatch via `rlm mark-delivered` |
| `status:cancelled` | **Terminal**. Abandoned before delivery; cannot return to `draft`. | spec, workpackage | Arbiter (cancel decision); Worker via self-decline path |
| `status:superseded` | **Terminal**. Replaced by a later Issue; new Issue carries `Supersedes #<old>` in its body. | spec, workpackage | `rlm mark-superseded` |

Transitions are **monotonic**. `status:cancelled` and `status:superseded` are terminal — no Issue ever returns to `draft`. Transitions are driven by `rlm` CLI subcommands; manual label edits by humans are discouraged but not technically prevented (the CLI is the discipline).

The two-step `draft` → `confirmed`/`approved` pattern enables **mechanical dependency enforcement**: `approve-workpackage` refuses to advance a WorkPackage until every ADR it references is merged into `main`. A WorkPackage cannot be approved against an ADR that might still be rejected.

## Source-of-truth discipline

Each agent has explicit reading rules. Violations are detectable via basis verification (per [ADR-0012](./0012-supervision-pure-observability.md)) — if an agent cites a `status:delivered` or `status:superseded` Issue as basis for a *current-state* claim, Supervision alerts.

| Agent | For *current state* it reads | For *historical context* it reads |
|---|---|---|
| Hermes (design-domain skills) | code (read-only), non-superseded `.rlm/facts/`, `.rlm/contracts/` | past Specs, past WorkPackages, ADRs |
| Worker | The WorkPackage assigned, code (R/W), non-superseded `.rlm/facts/`, `.rlm/contracts/` | parent Spec (AC reference only), referenced ADRs |
| WhiteBoxValidator | code, the WorkPackage being validated | parent Spec |
| BlackBoxValidator | running Artifact, the WorkPackage's AcceptanceCriteria | parent Spec AcceptanceCriteria only |

Hermes's design-mode reading rule is the most load-bearing: *Hermes (when running design-domain skills like `decompose-spec`) designs new WorkPackages by reading code and facts to know what is, not by reading past Specs to recover what was asked.* Past Specs describe decision provenance, not present reality.

## WorkPackage delivery requires a fact

A WorkPackage Issue transitions to `status:delivered` only when **all** of:

1. The PR closing the Issue is merged.
2. The merged PR includes at least one `rlm append-fact` (or `rlm supersede-fact`) commit reflecting the change to the system.
3. The ValidationPipeline (per [ADR-0006](./0006-validation-pipeline.md)) has fully passed for the merged Artifact.

Enforcement is via a CI check on the closing PR; `mark-delivered` cannot fire without it. This is what keeps `.rlm/facts/` synchronised with code reality, and what prevents the SDD collapse cycle.

## Superseding a Spec mid-flight

If a Spec is superseded while a WorkPackage derived from it is `status:in_progress`, the in-flight WorkPackage **continues to completion against its original Spec**. Its body is immutable; its AcceptanceCriteria are what the Worker is contracted to satisfy. The superseding Spec produces a new WorkPackage when Design re-runs.

Rationale: avoids wasting in-flight work; eliminates the ambiguous "which Spec is authoritative for this Worker right now?" question. The new Spec's claim on the system is honoured by the *next* WorkPackage, not by interrupting the current one.

## When AC ambiguity is detected mid-flight

If BlackBoxValidator returns the failure as **AC-ambiguity** (the AcceptanceCriterion itself is unclear, not the implementation), the in-flight rule above **does not apply** — the original Spec's AC cannot be satisfied because the AC itself is the defect. The DeliveryOrchestrator handles this differently:

1. **Cancels** the in-flight WorkPackage with `status:cancelled`, recording "parent Spec AC ambiguous" in a comment on the WorkPackage Issue.
2. **Enqueues** an `ac-ambiguity` message via `rlm enqueue-message` (per [ADR-0015](./0015-message-router-contract.md)) on the parent Spec Issue.
3. **Releases** the global Worker lock (per [ADR-0007](./0007-serial-worker-execution.md)).

Hermes, on its next cron invocation, processes the message: posts to Discord, optionally re-runs `BusinessModelProbe` to clarify the AC, and creates a new Spec that supersedes the original. Design produces a new WorkPackage from the new Spec; the Worker picks it up on its next cycle.

The distinction matters because the in-flight rule assumes the original AC is satisfiable. When the AC itself is the defect, continuing serves no one.

## Consequences

- **Hermes's design-domain basis citations are constrained at the observability layer.** Citing a `status:delivered` Spec as basis for "what the system does today" triggers a Supervision alert, catching the SDD anti-pattern automatically.
- **PR merge checks become load-bearing.** The CI check ensuring `delivered ⇒ fact-committed` is part of the architecture, not optional tooling.
- **GitHub Issue history is the canonical lifecycle audit.** Label transitions, comment threads, and supersede references form the system's record. Deleting Issues breaks the discipline; admins should not.
- **The system is robust to long iteration counts.** Iteration N can refer to iteration N-K's Spec for *historical context* but not for *current state*; the rolling fact ledger is what new agents read to know "where are we now."
