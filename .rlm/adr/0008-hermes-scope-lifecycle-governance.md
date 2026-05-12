# Hermes: cross-cutting conversation + design agent

Hermes is a **cross-cutting agent** running on the [hermes-agent runtime](https://github.com/nousresearch/hermes-agent) (a long-running event-driven daemon framework from Nous Research). It owns *every* human-facing dialogue in the system and *every* skill that translates human intent into Spec / WorkPackage / ADR / contract artifacts. Hermes spans the **Intake** and **Design** Bounded Contexts at the operational layer — the BCs remain distinct as *language boundaries*, but a single agent operates both.

## Why Hermes spans BCs

Earlier rounds of this architecture treated Intake (Hermes) and Design (Architect) as separate agents in separate BCs. Consolidating them was forced by two observations:

1. **Humans participate in both** — business-model formation (Intake) and architecture-decision discussion (Design) are both conversational. Splitting them across two agents creates cross-agent routing (Architect → message-router → Hermes → Discord → human → Hermes → message-router → Architect) for no benefit; the human sees one interface either way.
2. **The hermes-agent runtime is general-purpose** — its long-running daemon, built-in cron, skill abstraction, and multi-platform messaging cover *all* conversational and scheduled work. One instance with many skills is the framework's grain.

The price: Hermes is no longer Intake-only. Its scope is larger; **per-skill tool access** (see [ADR-0009](./0009-resource-access-boundaries.md) revision in this round) replaces per-agent access as the granularity for code-read permissions.

The **Architect agent does not exist** in this design — its responsibilities are skills owned by Hermes (a previously-drafted ADR-0018 was scrapped as part of this consolidation).

## Runtime: NousResearch hermes-agent

- **Long-running daemon** — single process listening on Discord (`#product`) and running a built-in cron scheduler. The daemon is *infrastructure*; the LLM invocations it spawns are *stateless* (per [ADR-0010](./0010-stateless-agent-invocation.md) revision in this round).
- **Event-driven** — Discord messages trigger fresh agent invocations.
- **Cron-driven** — periodic scans find Issue-state work to do (new `status:confirmed` Specs awaiting design; outbound queue; ProductionMonitor polls).
- **Stateless per invocation** — every cognitive turn reads the world fresh from Discord thread + RLM + Issues.
- **Framework features explicitly disabled for v1**: cross-session memory, autonomous skill creation (per K2 / CC decisions).

## Skill set (v1 outline; specific skill names finalised at implementation)

### Intake-domain skills
- `business-model-probe` — gstack `/office-hours`-style structured probe to extract business assumptions
- `deployment-constraints-probe` — extract budget / region / vendor / compliance constraints
- `production-monitor` — cron-triggered analytics poll, emits `Signal` Issues on anomaly
- `signal-to-spec` — translate confirmed Signal + conversation into draft Spec

### Design-domain skills
- `decompose-spec` — Spec → one or more WorkPackage drafts (requires code R)
- `compute-impact-scope` — analyse code to compute a WorkPackage's `ImpactScope` (requires code R)
- `select-deployment-strategy` — given `DeploymentConstraints` + RLM, decide cloud provider / runtime / scaling model
- `draft-adr` — author an ADR when warranted by the three-condition test
- `draft-contract` — author API / event schema entries for `.rlm/contracts/`

### Cross-domain skills
- `intake-confirmation` — gate dialogue before promoting Spec from `status:draft` → `status:confirmed`
- `design-approval` — gate dialogue before promoting WorkPackage from `status:draft` → `status:approved`
- `design-dialogue` — when Hermes (in design mode) needs human input mid-design, talks directly in Discord (no cross-agent routing — same agent; replaces the previously-planned `discussion-request` message kind)

## Tool access — per-skill, not per-agent

Hermes's tool access depends on which skill is currently active:

| Skill category | Code R | Code W | RLM W | Discord | Issue |
|---|:-:|:-:|:-:|:-:|:-:|
| Intake-domain | ❌ | ❌ | Signal / Spec / business | R/W | R/W |
| Design-domain | ✅ read-only | ❌ | ADR / contract / WorkPackage / CONTEXT (via PR-routed CLI) | R/W | R/W (incl. create `type:workpackage`) |
| Cross-domain (dialogue, confirmation, approval) | ❌ | ❌ | labels / comments only | R/W | R/W (labels, comments) |

The hermes-agent runtime gates tool access per skill invocation. A single Hermes invocation may invoke several skills in sequence, gaining and releasing access at skill boundaries.

## Triggers

Three sources, all spawning stateless invocations:

1. **Discord event** — user types in `#product`; daemon spawns an invocation that reads Discord thread + RLM and responds in Discord.
2. **Cron** — scheduled scans (new `status:confirmed` Specs needing decomposition; outbound `outbound:*` Issue labels; ProductionMonitor's polling cadence).
3. **GitHub label change** — (optional, via webhook) immediate trigger when downstream signalling demands attention.

## What Hermes does *not* do

- **Write code.** That is Worker's exclusive right (per [ADR-0009](./0009-resource-access-boundaries.md)).
- **Run the validation pipeline.** Dispatch's job (per [ADR-0014](./0014-delivery-orchestrator.md)).
- **Open PRs.** Worker's job (per [ADR-0016](./0016-worker-contract.md)).
- **Manipulate Delivery-stage labels** (`status:in_progress`, `agent:validator`, `agent:human-review`). Dispatch / Arbiter.

Hermes hands off to Delivery at WorkPackage `status:approved` and does not re-enter the picture until the next Signal arrives or Delivery escalates.

## Governance

- **Skill set is human-curated** (per K2 decision). hermes-agent's autonomous skill evolution is disabled.
- **Adding a skill** — write the skill's markdown spec, merge via PR; Hermes loads on daemon restart or hot-reload.
- **Hermes may *propose* new skills via Discord/Issue** when it detects repeated patterns; the proposal still terminates in a human writing and merging the skill. v2 work.

## Consequences

- **Architect as a separate agent does not exist.** Its responsibilities live as skills inside Hermes (with per-skill tool access).
- **Intake and Design BCs remain distinct as language boundaries** (Spec / WorkPackage / AcceptanceCriteria are distinct concepts). The same agent operating both BCs is fine in DDD — *BCs are vocabularies, not agents*.
- **Hermes is the heaviest agent in the system** by skill count and access scope. This is intentional: dialogue + design judgement is naturally the heaviest cognitive work.
- **The Delivery BC's agents (Worker, Dispatch, Validators, Arbiter) are unchanged.** Hermes's expansion stops at the WorkPackage handoff.
- **Cross-agent routing for design discussion is no longer needed** — no `discussion-request` outbound kind. See [ADR-0015](./0015-message-router-contract.md) revision in this round.
- **A future Worker domain (e.g., UE5) only requires new Worker skills**, not new dialogue/design skills (those are Hermes's job, and they generalise across Worker domains).

---

## Amendment 2026-05-12 — Hermes splits into Discord bridge + workflow-spawned skills (Path B / sweet-home runtime)

### What changed

The original ADR placed **all** Hermes responsibilities (Discord I/O **+** every intake / design skill invocation) inside one long-running `nousresearch/hermes-agent` daemon. After adopting [agent-sweet-home](https://github.com/liyoclaw1242/agent-sweet-home) as the project's declarative workflow runtime (see ADR-0014 amendment), Hermes splits into **two layers** with a clean Issue-label boundary between them:

1. **Hermes daemon (unchanged-ish, slimmer)** — the long-running `hermes-agent`-runtime process that owns Discord credentials. Its job shrinks to:
   - Listen on `#product`, capture user messages.
   - Create / update GitHub Issues (`kind:spec` / `kind:business-snapshot` / labels) based on user intent.
   - Drain the outbound queue (per ADR-0015 — `outbound:*`-labelled comments + `type:supervision-alert` issues) and post to Discord.
   - Flip `agent:hermes-intake` / `agent:hermes-design` / `agent:human-help` labels per Discord-side state transitions (user said "yes" → flip blocked → proposed; user typed a new question → keep on human-help; etc.).

2. **Hermes intake & design SKILLS (new home)** — every Hermes skill listed in the v1 outline (`business-model-probe`, `signal-to-spec`, `decompose-spec`, `compute-impact-scope`, `select-deployment-strategy`, `draft-adr`, `draft-contract`, `intake-confirmation`, `design-approval`, `design-dialogue`) is now spawned by **agent-sweet-home's workflow engine** as the `hermes-intake` and `hermes-design` roles defined in `D:/darfts/agent-team.workflow.yaml`. Each invocation is a separate `claude -p` subprocess gated by `agent:hermes-intake` / `agent:hermes-design` labels on the relevant Issue.

The two layers communicate **only through GitHub Issue state** (labels + body + comments) — there is no direct Hermes-daemon ↔ workflow IPC. This is deliberate: the daemon-side Discord work and the LLM-side design work proceed at very different cadences and need decoupling.

### Why split

| Pressure | Resolution |
|---|---|
| `claude -p` lifecycle (spawn, stream, cost tracking, kill, log) is already implemented in sweet-home. Re-implementing it inside hermes-agent would be duplicate work. | Let sweet-home own the spawn surface. Hermes daemon stops spawning `claude -p` for intake/design skills. |
| The hermes-agent daemon was carrying *both* event-loop concerns (Discord listening) and LLM-skill concerns (intake/design dispatch). Two cadences, two failure modes — hard to debug as one process. | Daemon becomes single-purpose: Discord I/O bridge. The label-state-machine on Issues is the system of record. |
| Cross-skill auditability — sweet-home's SQLite event log (per ADR-0011 amendment) captures every spawned skill's full stream. If skills ran inside a Hermes daemon, we'd need a second observability path. | Single observability stream: every Hermes-skill spawn appears in sweet-home's `one_shot_log_lines` like every other agent. |
| Adding a new skill required hot-reloading the Hermes daemon. | Adding a skill now means: write the SKILL.md, add the `hermes-*` `add_dirs` entry in `agent-team.workflow.yaml`, optionally add a new dispatch rule / on_result kind. No daemon restart. |

### What stays the same from the original ADR-0008

- **Hermes's *agent identity* is unchanged.** The five Hermes-class skills (intake-domain, design-domain, cross-domain) still belong to Hermes — they just *run* in sweet-home's runtime instead of hermes-agent's. From the human-facing perspective, "Hermes" is still the entity having the conversation; the implementation detail (which process spawns the LLM call) is invisible to the user.
- **Per-skill tool access** still applies. RoleConfig in `agent-team.workflow.yaml` carries `allowed_tools` / `disallowed_tools` / `add_dirs` per role, matching the per-skill scoping the original ADR specified.
- **No code write privilege** for Hermes-class skills — `disallowed_tools: ["Edit", "Write"]` in the workflow yaml's `hermes-intake` and `hermes-design` roles.
- **Discord credential-holder invariant** is preserved — only the Hermes daemon talks to Discord. Workflow-spawned skills emit structured-JSON `kind: intake-question` / `kind: clarification-needed` outputs that the workflow's `on_result` handler translates into `rlm enqueue-message` calls. The daemon drains that queue and posts to Discord.

### What no longer applies

- The "Triggers" section's items #1 (Discord event) and #2 (Cron) are now split:
  - Item #1 lives in the Hermes daemon (Discord listen → Issue update).
  - Item #2 lives in sweet-home's `entry.poll` loop (Issue scan → role dispatch).
- "Skill set is human-curated" governance — same intent, different mechanism: skills are checked in to `.claude/skills/` and referenced from `agent-team.workflow.yaml`. There is no daemon-level "load on restart" anymore.

### See

- `D:/darfts/agent-team.workflow.yaml` — roles `hermes-intake` and `hermes-design`, their `system_prompt_file` paths, `add_dirs`, `allowed_tools`, and the `on_result.hermes-*.kind:*` handlers
- ADR-0011 amendment (same date) — events store change
- ADR-0014 amendment (same date) — DeliveryOrchestrator now = sweet-home workflow runtime
