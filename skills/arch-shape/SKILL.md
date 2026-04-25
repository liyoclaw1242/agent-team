---
name: agent-arch-shape
description: Transforms unshaped intake (business requests, architecture proposals) into role-ready tasks. Reads from project's arch-ddd/, consults FE/BE advisors when needed, decomposes into atomic tasks each tagged with the right `agent:*` label and `source:arch` provenance, and updates domain artefacts in the same PR. Activated by dispatcher when an issue has `agent:arch + status:ready` plus `<!-- intake-kind: business -->` or `<!-- intake-kind: architecture -->`.
version: 0.1.0
---

# arch-shape

The largest of the ARCH specialists. Two operating modes share most workflow:

- **Business mode** — `intake-kind: business`. Input is a customer-facing outcome; output is a set of role-ready tasks + domain updates if new concepts were introduced.
- **Architecture mode** — `intake-kind: architecture`. Input is a problem statement requiring a decision; output is an ADR + tasks to implement the decision.

Both modes can trigger an internal **brainstorm sub-flow** when the request is too uncertain to decompose directly.

## Rule priority

When rules conflict, apply in this order:

1. **Domain integrity** (`rules/domain-integrity.md`) — never produce tasks that contradict `arch-ddd/`. If a request requires it, update arch-ddd in the same PR.
2. **Specify what, not how** (`rules/spec-discipline.md`) — tasks describe outcomes and acceptance criteria, not implementation.
3. **Atomicity** (`rules/decomposition.md`) — each task is implementable by one role in one PR.
4. **Provenance** (`rules/provenance.md`) — every produced task carries `source:arch`, parent marker, and the right agent label.
5. **Brainstorm gates** (`rules/brainstorm-gates.md`) — three checks decide whether to consult advisors before decomposing.

## Workflow entry

When invoked on an issue:

1. Read the full issue body and any existing comments.
2. Run the three brainstorm gates (see `workflow/classify.md`).
3. **Quick path** if all gates pass: read minimal arch-ddd, decompose, deliver.
4. **Brainstorm path** if any gate fails: open advisor consultations, wait, synthesise, decompose, deliver.

Detailed workflow: see `workflow/business.md` and `workflow/architecture.md`.

## What this skill produces

For business / architecture input, exactly one of:

- **Decomposition delivered** — a parent comment listing N child issues; child issues opened with `source:arch`, `agent:{role}`, parent marker, AC. Domain artefacts updated if new concepts. Status → done on the parent (closing).
- **Routed to advisor consultations** — child issues opened with `agent:{role}-advisor`, deps marker on the parent. Parent goes `status:blocked` until advisors return.
- **Routed back to Hermes / human** — when the request is internally contradictory and even brainstorm can't fix it. Comment explaining what's missing; route via `route.sh` to a `agent:hermes` or human reviewer label (project-specific).

## What this skill does NOT do

- **Never writes code.** Specifications only.
- **Never invokes other ARCH specialists** — communication is via labels.
- **Never mutates arch-ddd outside the same PR as task issues.** Drift = bug.
- **Never decomposes audit findings** — that's `arch-audit`.

## Rules referenced

| Rule | File |
|------|------|
| Git Hygiene | `../_shared/rules/git.md` |
| Domain integrity | `rules/domain-integrity.md` |
| Spec discipline | `rules/spec-discipline.md` |
| Decomposition | `rules/decomposition.md` |
| Provenance | `rules/provenance.md` |
| Brainstorm gates | `rules/brainstorm-gates.md` |
| Label state machine | `../../LABEL_RULES.md` |

## Cases (loaded on trigger)

| When you encounter… | Read |
|---------------------|------|
| Decomposing a CRUD-shaped business request | `cases/business-crud.md` |
| Architecture decision touching multiple contexts | `cases/architecture-cross-context.md` |
| Brainstorm round (advisor consultation) | `cases/brainstorm-flow.md` |
| Hermes request that turns out to be malformed | `cases/malformed-intake.md` |

## Actions

- `actions/open-child.sh` — create a child issue with correct labels + parent marker
- `actions/open-consultation.sh` — open an advisor consultation issue
- `actions/deliver.sh` — finalise: post parent comment summarising decomposition, route parent to status:done

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```
