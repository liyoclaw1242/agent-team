# Intake

Translates external signals — business metrics, product observations, user
feedback, GitHub Issues filed by humans — into structured Specs that Design
can act on. Hosts the human conversation interface.

## Language

**Signal**:
Any external input that may warrant work: a metric trend, a user complaint, a stakeholder request, an Issue.
_Avoid_: Ticket, request, ask

**Issue**:
A GitHub Issue. The physical form for every workflow item in this system: Signals (this BC), Specs (this BC), and WorkPackages (Design BC). Kind via `type:` label; lifecycle via `status:` label. See [ADR-0004](../../adr/0004-rlm-knowledge-base.md) and [ADR-0013](../../adr/0013-spec-workpackage-lifecycle.md).
_Avoid_: Ticket, story, card

**Spec**:
The structured, technology-agnostic description of what should be built or changed, derived from one or more Signals. Physically a GitHub Issue with `type:spec`; lifecycle `draft → confirmed → superseded / cancelled`. Body **immutable** once `status:confirmed`. The published output of this BC.
_Avoid_: Requirement, story, PRD

**AcceptanceCriteria**:
The verifiable, behaviour-level conditions a Spec must satisfy. Carried with the Spec into Design and Delivery. Used by `BlackBoxValidator` to judge success.
_Avoid_: Definition of done, acceptance test

**IntakeConfirmation**:
The human acknowledgement (via Hermes in Discord) that an Intake-drafted Spec correctly captures intent. Auto-approves after a configured timeout.
_Avoid_: Sign-off, approval (reserve "approval" for `DesignApproval`)

**Hermes**:
The cross-cutting agent that operates this BC (and the Design BC) at the operational layer. Runs on the [hermes-agent](https://github.com/nousresearch/hermes-agent) framework as a long-running daemon listening on Discord and a built-in cron. Skills invoked in this BC: `business-model-probe`, `deployment-constraints-probe`, `production-monitor`, `signal-to-spec`, `intake-confirmation`. Full contract: [ADR-0008](../../adr/0008-hermes-scope-lifecycle-governance.md).

**BusinessModelProbe**:
A structured-conversation skill Hermes uses to surface implicit business assumptions from humans — pricing, target segment, wedge, status quo, demand reality. Inspired by gstack `/office-hours`. Output becomes part of the originating `Signal`'s context.
_Avoid_: Discovery interview, requirements gathering

**DeploymentConstraintsProbe**:
A structured-conversation skill Hermes uses to extract deployment-relevant constraints (budget, region, vendor preferences, compliance, team skills). Writes them as the `DeploymentConstraints` field on the resulting `Spec`. *Does not decide* deployment strategy — that is Hermes's `select-deployment-strategy` skill (design-domain, see [ADR-0008](../../adr/0008-hermes-scope-lifecycle-governance.md)). Per-skill access boundary: this skill has no code access; `select-deployment-strategy` does.
_Avoid_: Infrastructure design, deployment planning

**ProductionMonitor**:
A Hermes skill that polls external analytics providers (e.g., Google Analytics, PostHog) for live product metrics (conversion rate, error rate, latency, etc.) and emits a `Signal` when a tracked metric crosses an alert threshold. Auto-creates an `Issue` and posts a notification to Discord; the human retains veto. State (watched metrics, thresholds) lives in configuration / RLM — the skill itself is invoked per poll, not continuously resident.
_Avoid_: Observability, monitoring (those are operations concerns; ProductionMonitor is a Signal source, not infrastructure)

## Relationships

- A **Signal** is recorded as an **Issue** (or multiple Issues if scope is split). Signals originate either from human input (Issue filed manually, or surfaced via Hermes office-hours) or from **ProductionMonitor** detecting a metric anomaly.
- One or more **Issues** are translated into one **Spec**.
- A **Spec** carries its **AcceptanceCriteria** as a required field, and may carry `DeploymentConstraints` populated by **DeploymentConstraintsProbe**.
- A **Spec** is published to Design only after **IntakeConfirmation**.
- **DeploymentConstraints** are *inputs* to Architect's deployment decision, never the decision itself.

## Example dialogue

> **Hermes (in Discord):** "I read three Signals this week — checkout drop-off (Issue #142), the cart-abandonment metric, and user feedback in #product. Drafted Spec: 'Reduce checkout friction by collapsing the address step into the payment step.' AcceptanceCriteria: checkout completion rate +5% on the test cohort, no regression in fraud-block rate. Confirm and I'll commit it as a Spec Issue. Auto-confirms in 30 min."
> **Human:** "No — address is regulated separately, it has to stay its own step. Redraft with that constraint."
> **Hermes:** "Updated. Re-drafted: 'Reduce checkout friction without altering address-step boundaries.' AcceptanceCriteria adjusted. Same timeout."
> **Human:** "Approved."
> **Hermes:** "Committed as Spec Issue #214, `status:confirmed`. Body is now immutable; Design will pick it up."

## Flagged ambiguities

- **"Spec" vs "Requirement"** — resolved: we use **Spec**. A Spec describes the outcome and AcceptanceCriteria, never the implementation.
- **"Confirmation" vs "Approval"** — resolved: **IntakeConfirmation** is for Specs (Intake); **DesignApproval** is for WorkPackages (Design). Different gates, different vocabulary.
