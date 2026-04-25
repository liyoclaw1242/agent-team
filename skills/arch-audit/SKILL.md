---
name: agent-arch-audit
description: Decomposes QA / Design audit findings into role-ready fix tasks. Activated by dispatcher when an issue has `agent:arch + status:ready` plus `<!-- intake-kind: qa-audit -->` or `<!-- intake-kind: design-audit -->`. Reads the structured findings list, groups related issues if they're symptoms of the same root cause, and produces fix tasks each tagged with `source:arch` and the appropriate role.
version: 0.1.0
---

# arch-audit

Sibling of arch-shape, narrower scope. The job is mechanical compared to shaping new business requests: the audit issue already lists discrete findings; arch-audit's job is to (1) decide whether multiple findings are really one underlying problem, and (2) produce well-formed fix tasks.

## Rule priority

1. **Pattern recognition before decomposition** — if multiple findings are symptoms of one underlying issue, file one fix task that addresses the root, not N fixes for the symptoms.
2. **Severity preservation** — each fix task carries the severity tagged in the audit.
3. **Provenance** (same as arch-shape) — every fix task has `source:arch`, parent marker, and right agent label.
4. **Domain integrity** — if findings reveal arch-ddd drift, fix the artefact in the same PR as filing the fix tasks.

## Workflow entry

When invoked:

1. Read the audit issue body — it should follow the `qa-audit.yml` or `design-audit.yml` template
2. For each finding, determine: is this its own fix, or part of a pattern?
3. Group findings into 1–N fix tasks
4. Open each fix task via `actions/open-fix.sh`
5. Deliver via `actions/deliver.sh` (similar shape to arch-shape's)

Detailed: see `workflow/decompose.md`.

## What this skill produces

Per audit issue, exactly one of:
- **Fix decomposition delivered** — N fix issues opened with `source:arch`, `agent:{role}`, severity tag, parent marker; audit issue closes
- **Routed to arch-judgment** — when findings are too vague to decompose without further investigation (rare; audit templates require findings to be specific)

## What this skill does NOT do

- **Never investigates** — the audit issue lists what's wrong; investigation is debug's job
- **Never writes fixes** — only files them as tasks
- **Never modifies the original audit issue** other than to close it

## Rules referenced

| Rule | File |
|------|------|
| Git Hygiene | `../_shared/rules/git.md` |
| Pattern recognition | `rules/pattern-recognition.md` |
| Severity handling | `rules/severity.md` |
| Provenance | `../arch-shape/rules/provenance.md` (shared with arch-shape) |
| Label state machine | `../../LABEL_RULES.md` |

## Cases

| When | Read |
|------|------|
| Single-finding audit | `cases/single-finding.md` |
| Findings reveal a systemic pattern | `cases/systemic-pattern.md` |
| Findings span multiple roles | `cases/multi-role.md` |

## Actions

- `actions/open-fix.sh` — create a fix issue with audit provenance
- `actions/deliver.sh` — finalise and close the audit parent

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```
