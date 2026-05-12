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

---

## Amendment 2026-05-12 — DeliveryOrchestrator implementation = agent-sweet-home workflow engine (Path B)

### What changed

The original ADR specified DeliveryOrchestrator as **a cron-triggered Python orchestration script** that, within one cron tick, holds the global Worker lock and chains `claude -p` invocations sequentially (Worker → Validators → Arbiter as needed). Under Path B, that script is **replaced wholesale** by [agent-sweet-home](https://github.com/liyoclaw1242/agent-sweet-home)'s declarative workflow engine, configured by `agent-team/agent-team.workflow.yaml`.

The orchestration **responsibilities** specified in the original ADR are preserved — they're just executed by sweet-home's runtime instead of bespoke Python. The mapping:

| Original responsibility (ADR-0014 v1) | sweet-home equivalent (Path B) |
|---|---|
| Cron-triggered every N min | `entry.poll.interval_sec` in workflow YAML (v1: 30s) |
| Consumes `type:workpackage`, `status:approved` | `dispatch.rules` matching `has_label: kind:workpackage` + `has_label: agent:worker` + `has_label: status:approved` → `directive: spawn_fresh role: worker` |
| Acquires global Worker lock | `entry.poll.max_in_flight: 1` (v1: serializes ALL roles globally, not just Worker — see "v1 simplifications" below) |
| `rlm mark-in-progress` before Worker activation | `pre_spawn: [{ if: { role: worker }, do: [ transition_status: { from: approved, to: in-progress } ] }]` |
| Hands the WorkPackage to the Worker | `roles.worker.system_prompt_file` + `needs_worktree: true` (sweet-home auto-carves `spawn-<issue>-<ts>` worktree and prepends `BRANCH:`/`WORKTREE:` lines to the prompt header) |
| Sequences the 5-stage ValidationPipeline | One dispatch rule per stage's `(agent:*, status:*)` combination. The "sequence" emerges from the label state machine: Worker sets `agent:validator + status:delivered` → next tick matches whitebox rule → WhiteBox sets `agent:blackbox-validator` → next tick matches blackbox rule → BlackBox sets `status:validated` → terminal until human merge |
| Stage-1 automated tools (lint/typecheck/unit) | GitHub Actions CI on the Worker's PR — unchanged. CI failure does not gate `agent:validator` dispatch in v1; the WhiteBox validator role reads CI status as part of its review. |
| Stage-3 sandbox deploy | Deferred to Phase 2. v1 BlackBoxValidator role runs against `wrangler dev` / `next dev` / `dotnet run` locally inside the worker's worktree (or against a manually-deployed preview URL). |
| Post-condition checks after each agent exit | Replaced by **JSON envelope discipline**: each role emits `{"kind": "..."}` as its final assistant message; `on_result.<role>.<kind>` handler does the label transitions. Spawns that fail to emit parseable JSON fall through to `on_no_structured_output`, which auto-routes to `agent:arbiter`. The original ADR's exhaustive per-agent post-conditions (branch ✓, PR ✓, fact commits ✓, summary comment ✓, label flip ✓) become **convention enforced by the agent's JSON contract**, not separate verification steps. |
| Retry budget counting + escalation | Arbiter role owns retry counter bumps via `set_body_marker: { retry-<stage>: N }`. Escalation = Arbiter emits `kind: escalate` → `on_result.arbiter.escalate` calls `rlm enqueue-message --kind=retry-exhausted` → daemon posts to Discord. |
| Releases Worker lock at terminal state | Implicit — sweet-home's `max_in_flight` semaphore is held by the in-flight spawn's tokio task; releasing happens when the spawn future drops, automatically. |
| `mark-delivered` after merge + CI pass | A separate poll-tick concern: a future dispatch rule (or a manual `rlm mark-delivered` from a human) handles the merged-PR → `status:done` transition. Not auto-wired in the v1 workflow yaml because PR merges happen outside the workflow's polling cadence; the human's merge is the trigger. |

### Why this is a strict improvement over hand-rolled Python

1. **Declarative > imperative** — the label state machine is one YAML file, not a Python state machine. New stages are 1-3 YAML lines, not new Python code with new tests.
2. **Free infrastructure** — sweet-home already provides `claude -p` spawn, NDJSON log streaming, SQLite persistence, cost tracking, kill, HTTP API for observability, automatic worktree allocation, and `on_no_structured_output` degrade fallback. Our hand-rolled Python would have to build all of this.
3. **Pre-existing UI** — sweet-home's One-Shot tab is a built-in Mission Control: every spawn appears with live log, total cost, kill button. We don't build a separate dashboard.
4. **Single observability stream** — `one_shot_log_lines` SQLite captures every spawn end-to-end (see ADR-0011 amendment); no second event store.
5. **Schema-validated config** — `cargo run --example check_yaml` catches YAML errors before runtime. Hand-rolled Python wouldn't have the same compile-time guarantee.

### v1 simplifications (deliberate)

These are called out in `agent-team.workflow.yaml` comments and should not be mistaken for missing features:

1. **`max_in_flight: 1` is global, not per-role.** The original ADR's "global Worker lock" (ADR-0007 / ADR-0015) was Worker-specific — Validators could run in parallel against different WPs. Sweet-home's v0.1 semaphore is shared across all roles. v1 accepts this (single-user, low-volume dogfood); Phase 2 patches sweet-home to add per-role concurrency limits (~50-80 LOC Rust).
2. **In-cycle chaining replaced by per-tick advancement.** The original ADR held the lock through Worker → Validators → Arbiter inside one cron run. Sweet-home does one dispatch per `(issue × tick)`, advancing the label state and letting the next tick pick up the next stage. Wallclock latency goes up (each transition = one tick interval = 30s); correctness is preserved.
3. **Post-condition trust.** Original ADR specified Dispatch verifies branch exists, fact commits present, PR opened, etc., AFTER Worker exits — and invokes Arbiter on any failure. Path B trusts the agent's structured JSON: Worker says `kind: delivered` with a `branch`, we trust it. The Validators (which run next) catch lies — they're the real verification. Spawns that fail to emit JSON fall to Arbiter via `on_no_structured_output`. This is a real reduction in defensive verification, accepted for simplicity.
4. **Stage 3 (sandbox deploy) is manual / local in v1.** Vercel preview deploys + Cloudflare wrangler dev are run by the agent itself in its worktree; the BlackBoxValidator role reads against `localhost:3000` / `:8787` rather than a separate deployed sandbox URL. Phase 2 can add `run_command: ["vercel", "deploy", "--prebuilt"]` to a pre-blackbox `on_result` step.
5. **`mark-delivered` is not auto-wired.** The human merges the PR; then runs `rlm mark-delivered <wp-num>` manually (or wires GitHub Actions to call it on merge). The workflow doesn't watch PR merges. Phase 2 can add a webhook entry mode for this.

### Access boundaries — unchanged in spirit

The original ADR's access table for DeliveryOrchestrator (Code R: ❌, Code W: ❌, RLM W: WorkPackage labels only, ...) still holds. **Sweet-home as the runtime has no LLM identity** — it's pure infrastructure (Rust + tokio + axum + SQLite). It executes the YAML's `add_labels` / `remove_labels` / `transition_status` / `create_issue` / `run_command` actions, all of which shell out to `gh` and `git` — exactly what the original Python Dispatch would have done. The runtime itself does not have an LLM agent identity to grant code-read or code-write access to.

### Migration cost from the original ADR-0014

- **Python Dispatch scaffolding** — not built yet (we paused implementation before this amendment). No code to delete.
- **`rlm` CLI** — 17 subcommands implemented, all still useful. The `mark-in-progress` subcommand is now called by sweet-home's `pre_spawn` `transition_status` action (which is internally `gh issue edit --add-label status:in-progress --remove-label status:approved`), so the CLI subcommand is effectively shadowed by inline `gh` calls — but it remains valid for manual / one-shot operations.
- **Worker SKILL.md (`tdd-loop`)** — already amended in the same round (Path B step A) to drop "push branch / open PR / post summary comment / flip label" responsibilities (those moved to `on_result.worker.delivered`).

### See

- `agent-team/agent-team.workflow.yaml` — full v1 dispatcher configuration; ~530 lines
- `agent-sweet-home/src-tauri/src/workflow/` — Rust source for the runtime
- ADR-0008 amendment (same date) — Hermes split into daemon + workflow-spawned skills
- ADR-0011 amendment (same date) — events store now sweet-home SQLite
- ADR-0017 (unchanged) — Arbiter contract still applies, just runs as a workflow role

---

## Dogfood validation — 2026-05-12 (Mac, end-to-end happy path)

**Verdict: Path B confirmed working end-to-end on Mac.**

Test repo: `liyoclaw1242/todo-20260512`, WP Issue #1 — `[WP] Add GET /todos endpoint returning {todos: []}`.

### Observed sequence

| Stage | Outcome | Cost | Duration | Notes |
|---|---|---|---|---|
| Worker | ✅ delivered | $0.33 | ~110s | Branch `spawn-1-1778577551`, commit `e3b376b` `[ac1] add GET /todos endpoint returning empty array`. RGR cycle: failing test → green → fact commit → JSON envelope emitted. |
| WhiteBox | ✅ approved | $0.27 | ~101s | `code-review` sub-skill. One note (url exact-match `/todos?foo` → 404) flagged as out-of-scope for this WP. |
| BlackBox | ⚠️ rejected (v1 known limit) | $0.27 | ~101s | `api-contract-test`. Rejected because no sandbox server running on localhost. v1 BlackBox does not auto-start the server before probing. |
| PR #2 | ✅ merged manually | — | — | Merged after WhiteBox approval per §9(d) workaround. Commit `ed4b06bd`. |

**Total cost: ~$0.87. Total wallclock: ~15 min** (including Rust incremental recompile).

### Bugs observed during Mac run

| # | Symptom | Root cause | Status |
|---|---|---|---|
| 1 | `on_result.whitebox-validator.approved` dispatch error: `agent:hermes-intake` not found | `on_no_structured_output.remove_labels` tries to remove all `agent:*` labels atomically; fires as a fallback even after a successful `on_result` handler when the quarantine path is triggered | Known v1 limitation — does not block happy path; `on_result` transitions still applied correctly |
| 2 | `quarantine failed: 'human-review' not found` | quarantine tries to add `human-review` label which doesn't exist on the repo | Non-blocking; quarantine path is the error-degrade path, not the happy path |
| 3 | BlackBox `rejected-implementation-defect` (false negative) | v1 BlackBox SKILL.md expects a running sandbox server at localhost; no server auto-started | Documented in §9(d). Phase 2 fix: add `run_command: [...]` pre-blackbox step to start the server, or deploy to preview URL |
| 4 | BlackBox first attempt hit `on_no_structured_output` before a successful second attempt | Prose-before-fence parsing issue intermittent | `strip_json_fence` patch (`dd5407f`) mostly resolves this; occasional miss still occurs |

### What this validates

- **Worker → WhiteBox full cycle works.** The declarative label state machine advances correctly through the happy path without human intervention.
- **JSON envelope discipline works.** Worker emitted the exact `{kind: "delivered", branch: "...", fact_commits: [...]}` shape; `on_result.worker.delivered` parsed and acted on it correctly.
- **Worktree isolation works.** Sweet-home carved `spawn-1-1778577551`, Worker committed inside it, PR was opened against `main`, worktree was torn down.
- **`strip_json_fence` patch is effective.** Worker output (prose + fence) was parsed correctly on this run.
- **Mac `claude` shim works without `CLAUDE_BINARY` override.** No Windows-specific workaround needed.

### Phase 2 items surfaced by this run

1. **BlackBox sandbox auto-start** — add a `pre_spawn` `run_command` step for `whitebox-validator → blackbox-validator` transition that starts `pnpm dev` (or `wrangler dev`) in the worktree and writes the localhost URL to the issue body for BlackBox to read.
2. **`on_no_structured_output` atomic label removal** — replace the 5-label atomic `gh issue edit` with individual `--remove-label` calls (or filter to only labels currently present on the issue).
3. **`mark-delivered` auto-wiring** — GitHub Actions webhook on PR merge to call `rlm mark-delivered <wp-num>` automatically.
4. **Next milestone: connect Hermes** — wire the full signal → spec → WP → dispatch → deliver cycle so intake flows from Discord rather than manually-created issues.
