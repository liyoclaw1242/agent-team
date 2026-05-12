# Resource access boundaries per agent

Each agent has a strictly defined access scope to four resource classes — source code, the RLM, Discord, and GitHub (Issues + PRs). Boundaries are enforced by infrastructure, not by convention.

| Agent | Code R | Code W | RLM R | RLM W | Discord | Issue | PR |
|---|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| Hermes (cross-cutting; Intake + Design) | ✅ read-only (design-domain skills only) | ❌ | ✅ | ✅ Signal/Spec/WP/ADR/contract/business | R/W | R/W (incl. create `type:workpackage`, labels, comments) | ❌ (CLI mediates) |
| DeliveryOrchestrator (Dispatch) | ❌ | ❌ | ✅ | ✅ WorkPackage labels only | via Hermes | R + flip `status:`, `agent:*`, and `retry:*` on assigned WorkPackage | ❌ |
| Worker (Delivery) | ✅ | ✅ | ✅ | ✅ facts | ❌ | R + comment + relabel `agent:*` on own WorkPackage | ✅ via `rlm open-pr` only |
| WhiteBoxValidator | ✅ read-only | ❌ | ✅ | ❌ | ❌ | R + comment on assigned WorkPackage | ❌ |
| BlackBoxValidator | ❌ | ❌ | ✅ Spec only | ❌ | ❌ | R + comment on assigned WorkPackage | ❌ |
| Arbiter (Delivery) | ❌ | ❌ | ✅ | ❌ | via Hermes (on escalate) | R + label changes + comment on assigned WorkPackage | ❌ |
| Supervision | metadata only | ❌ | ✅ audit | ✅ event log | via Hermes | R + create `type:supervision-alert` Issues via `enqueue-message` | ❌ |

**All Issue writes are CLI-mediated** (per [ADR-0004](./0004-rlm-knowledge-base.md)) — no agent edits Issue bodies directly. "R/W" for Hermes means "may invoke any `rlm` subcommand that creates / labels / comments on Issues"; the subcommand set is the actual constraint.

**All PR creation flows through `rlm open-pr` (CLI-mediated).** Agents do not invoke `gh pr create` or push PRs directly. Hermes's PR-routed CLI subcommands (`propose-adr`, `propose-context-change`, `add-contract`) are CLI-mediated PRs: the CLI holds the GitHub token, the agent does not. This is why Hermes shows `❌` for PR in the matrix — Hermes cannot create PRs on its own authority; the CLI does so on its behalf when those subcommands are invoked.

**Hermes's Code R is per-skill.** Only Hermes's design-domain skills (`decompose-spec`, `compute-impact-scope`, `select-deployment-strategy`, etc., per [ADR-0008](./0008-hermes-scope-lifecycle-governance.md)) may invoke code-read tools. Intake-domain skills (probes, monitors) and cross-domain dialogue skills have no code access. The hermes-agent runtime enforces this at the skill invocation boundary.

## Why

Three load-bearing decisions, each surprising on its own:

- **Intake has no code access — including Hermes.** Letting Hermes read code would let it design implementations bottom-up from current state, defeating Intake's purpose (which is to capture human intent independent of how the code currently looks). It would also pollute office-hours-style probing — Hermes would steer conversations toward what is easy to build, not what the user actually wants.
- **Hermes's design-domain skills have read-only code access — never write code.** Reading is needed to compute ImpactScope, verify RLM staleness, and write accurate ADRs. Writing is Worker's exclusive right; granting code-write to any non-Worker would collapse the Design/Delivery boundary. Hermes-in-design-mode is "the senior engineer who reads code to write design docs," not "the engineer who writes code." Per-skill access (per [ADR-0008](./0008-hermes-scope-lifecycle-governance.md)) keeps code-read isolated to design-domain skills only.
- **BlackBoxValidator has no code access — by design.** Black-box validation has value only if uncontaminated by implementation. The constraint is structural, not advisory: BlackBoxValidator and WhiteBoxValidator must be distinct agents on distinct context windows.

## Consequences

- **Deployment strategy decisions belong to Hermes's design-domain skills**, specifically `select-deployment-strategy`. Hermes's intake-domain skill `deployment-constraints-probe` extracts *constraints* (no code access); `select-deployment-strategy` (design-domain) makes the *decision* (with code-read access). Per-skill access boundaries enforce that only design-domain skills can read code — even though it's the same Hermes agent.
- **RLM staleness directly degrades Intake quality.** Intake has no fallback to verify against current code; RLM is its only source of system knowledge. This elevates ADR-0004 (RLM details) from "important" to "load-bearing."
- **Future Worker specialists inherit Worker's access profile.** A new Worker domain (e.g., UE5, Blender) adds a Worker, not a new agent class with different rules. The matrix expansion is per-instance, not per-class.
- **Only Hermes holds Discord credentials.** All other agents (DeliveryOrchestrator, Worker, Validators, Arbiter, Supervision) hand structured payloads to Hermes via `rlm enqueue-message` (per [ADR-0015](./0015-message-router-contract.md)). This keeps the human-facing voice consistent and the credential surface minimal.
