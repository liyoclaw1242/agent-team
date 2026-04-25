---
name: agent-arch
description: Architecture facade. Receives all issues labelled `agent:arch + status:ready` and routes them to the correct ARCH-family specialist (arch-shape, arch-audit, arch-feedback, arch-judgment) via the deterministic dispatcher. This skill itself contains no LLM logic — when invoked, run `dispatcher/dispatcher.sh` and exit. The dispatcher reads labels and HTML comment metadata, applies the LABEL_RULES.md decision table, and changes the issue's `agent:*` label so a specialist picks it up on its next poll.
version: 0.1.0
---

# ARCH Facade

This skill exists to give the team **one stable address** (`agent:arch`) while the actual work is split across multiple specialists internally. Non-arch agents always route to `arch`; what handles their delivery is an internal implementation detail.

## When you are invoked

If you (the LLM) are reading this, something has gone wrong. The dispatcher should have routed away to a specialist before you got here.

The intended invocation is:

```bash
bash dispatcher/dispatcher.sh
```

…run from cron, deterministically, no LLM. If that script is missing or failed, escalate to the human team. **Do not attempt to act as the dispatcher manually** — you do not have the deterministic guarantees the dispatcher provides, and acting in its place will create routing inconsistencies.

## What the dispatcher does

See `dispatcher/RUNBOOK.md` and `dispatcher/decision-table.md` for the full contract. Briefly:

1. Polls open issues with `agent:arch + status:ready`
2. For each, reads labels and the `<!-- intake-kind: ... -->` HTML comment
3. Matches against the rules in `LABEL_RULES.md` (the canonical table)
4. Calls `route.sh` to retag the issue's `agent:*` label
5. Exits — the named specialist (arch-shape, arch-audit, etc.) picks it up via its own poll

The dispatcher handles ~85% of routing decisions deterministically. Only the residual cases (Mode C feedback evaluation, complex audit decompositions, conflicts) actually consume LLM specialists.

## Sibling specialists

These are independent skills that share the `arch-*` namespace and are reachable only via the dispatcher:

| Skill | Handles |
|-------|---------|
| `arch-shape` | New requests (business + architecture intake) |
| `arch-audit` | QA / Design audit findings to fan out |
| `arch-feedback` | Mode C: specialist pushback on a spec |
| `arch-judgment` | Escape hatch: anything the dispatcher can't classify, or genuine conflicts |

Each has its own `SKILL.md`, workflow, and rules. They never call each other directly — they communicate via issue labels just like every other agent does.

## Escalation

If you ever find yourself in a state where you (LLM) need to decide what to do with an `agent:arch` issue, the answer is: re-route the issue to `agent:arch-judgment` and exit. Judgment is the only specialist whose contract includes "handle weird stuff".

## Rules referenced

| Rule | File |
|------|------|
| Git Hygiene | `../_shared/rules/git.md` |
| Label state machine | `../../LABEL_RULES.md` |

## Actions

This skill has no actions. The dispatcher under `dispatcher/` is invoked by cron, not by an action call from another agent.

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```
