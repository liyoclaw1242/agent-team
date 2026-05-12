# Design

Translates Specs from Intake into technical work that Delivery can execute,
capturing architectural decisions that outlive any single change.

**Operational owner: Hermes** — this BC has no dedicated agent. Hermes spans both Intake and Design at the operational layer, invoking design-domain skills (`decompose-spec`, `compute-impact-scope`, `select-deployment-strategy`, `draft-adr`, `draft-contract`) when working in this BC's vocabulary. See [ADR-0008](../../adr/0008-hermes-scope-lifecycle-governance.md).

## Language

**WorkPackage**:
A single unit of technical work, scoped small enough for one Worker iteration. Physically a GitHub Issue with `type:workpackage`; lifecycle `draft → approved → in_progress → delivered → superseded / cancelled`. Body **immutable** once `status:approved`. The published output of this BC. See [ADR-0013](../../adr/0013-spec-workpackage-lifecycle.md).
_Avoid_: Task, ticket, story

**ImpactScope**:
The set of files, modules, contracts, or external systems a WorkPackage may touch. Computed by Hermes via the `compute-impact-scope` skill before publication. Carried as a required field on every WorkPackage — Delivery refuses packages without it.
_Avoid_: Blast radius, affected area

**ADR**:
A durable record of an architectural decision: what was decided, what was rejected, why. Lives in `.rlm/adr/`. Authored only when a decision is (1) hard to reverse, (2) surprising without context, and (3) the result of a real trade-off.
_Avoid_: Design doc, RFC

**DeploymentStrategy**:
The architectural decision about where and how a system runs — cloud provider, runtime, region, scaling model, vendor bindings. Authored via Hermes's `select-deployment-strategy` skill, taking the Spec's `DeploymentConstraints` (extracted earlier by Hermes via `deployment-constraints-probe`) as input. Captured as one or more WorkPackages plus an ADR when the decision introduces lock-in or would surprise a future reader.
_Avoid_: Infrastructure plan, deploy spec

**DesignApproval**:
The human gate (via Hermes in Discord) before any WorkPackage leaves this BC. The most important gate in the system — the place where the cost of misunderstanding is still cheap to correct.
_Avoid_: Sign-off, confirmation (reserve "confirmation" for Intake)

## Relationships

- One **Spec** produces one or more **WorkPackages**.
- A **Spec** carrying `DeploymentConstraints` is translated by **Hermes** (via the `select-deployment-strategy` skill) into a **DeploymentStrategy**, which materialises as WorkPackages (and an ADR when warranted).
- A **WorkPackage** may produce zero or more **ADRs** (only when warranted by the three-condition test).
- A **WorkPackage** carries its **ImpactScope** as a required field.
- **DesignApproval** is required before any WorkPackage is released to Delivery.

## Example dialogue

> **Hermes** *(Discord thread, `design-approval` skill)*: "Spec #143 ('collapse checkout steps without altering address boundaries') → three WorkPackages drafted:
>   ▸ **#144** — inline address summary into payment step (no ADR; ImpactScope: `src/checkout/payment/*`)
>   ▸ **#145** — update analytics event schema (additive only)
>   ▸ **#146** — add A/B exposure logging
> Reply `approve <n>` to approve specific, `hold <n>` to keep in draft, or `approve all`. Auto-approves all in 30 min."
> **Human**: "approve 144. hold 145 and 146 — data team owns analytics, I'll loop them in separately."
> **Hermes**: "Got it. #144 → `status:approved` (Delivery picks up next cron). #145 and #146 stay `status:draft`. Say `new spec for data-team analytics` and I'll open a fresh thread to scope that conversation."

## Flagged ambiguities

- **"WorkPackage" vs "Task"** — resolved: **WorkPackage**. A "Task" carries no contract; a WorkPackage requires an ImpactScope and traces back to a Spec.
