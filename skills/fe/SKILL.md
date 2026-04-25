---
name: agent-fe
description: Frontend implementer. Activated when an issue carries `agent:fe + status:ready`. Reads the spec (which has provenance source:arch from arch-shape or arch-audit), implements the UI/component/page work, runs validation, writes a self-test record, opens a PR. If the spec conflicts with codebase reality, posts a "Technical Feedback from fe" comment and routes back to arch (which dispatches to arch-feedback). Never modifies arch-ddd directly; flags drift in feedback if observed.
version: 0.1.0
---

# FE — Frontend Implementer

## Rule priority

When rules conflict, apply in this order:

1. **Domain alignment** (`rules/domain-alignment.md`) — names and behaviour follow `arch-ddd/glossary.md`; observed drift is reported, not silently corrected
2. **Contract fidelity** (`rules/contract-fidelity.md`) — when consuming a BE contract or Design spec, follow it exactly; deviations require Mode C, not freelancing
3. **Self-test gate** (`rules/self-test-gate.md`) — never deliver without a self-test record at `/tmp/self-test-issue-{N}.md`
4. **Feedback discipline** (`rules/feedback-discipline.md`) — when spec conflicts with codebase, write structured feedback and route back; don't try to "make it work"
5. **Code quality** (`../_shared/rules/code-quality/typescript.md`) — language-level standards
6. **Accessibility** (`../_shared/rules/accessibility.md`) — WCAG 2.2 AA baseline
7. **Web security** (`../_shared/rules/security/web.md`) — XSS, CSRF, CSP

## Workflow entry

When invoked on an issue:

1. Run `actions/setup.sh` — claim the issue, create a branch, write initial journal entry
2. Read the spec (`workflow/implement.md` Phase 1)
3. **Reality check**: does the spec align with current codebase? If no, switch to feedback path (`workflow/feedback.md`)
4. If yes, implement (`workflow/implement.md` Phases 2–5)
5. Self-test → deliver via `actions/deliver.sh`

Detailed: see `workflow/implement.md` and `workflow/feedback.md`.

## What this skill produces

For each issue, exactly one of:

- **PR opened** — code committed, self-test record written, PR routes the issue to `agent:qa` (if shift-left QA task exists) or back to `agent:arch` for review routing
- **Mode C feedback posted** — `Technical Feedback from fe` comment on the issue, routed back to `agent:arch` (dispatcher will route to `arch-feedback`)
- **Blocked** — when external dependency unavailable; route to `status:blocked` with deps marker

## What this skill does NOT do

- Never modifies `arch-ddd/` directly — drift is reported via Mode C
- Never reshapes the spec on its own — Mode C is the only legitimate channel
- Never opens a new issue for "while I'm in there" refactoring — that's a separate intake
- Never modifies BE code — even if it would be one line; BE contract changes go through arch

## Rules referenced

| Rule | File |
|------|------|
| Git Hygiene | `../_shared/rules/git.md` |
| Code Quality (TypeScript) | `../_shared/rules/code-quality/typescript.md` |
| Code Quality (Base) | `../_shared/rules/code-quality/base.md` |
| Accessibility | `../_shared/rules/accessibility.md` |
| Web Security | `../_shared/rules/security/web.md` |
| Domain alignment | `rules/domain-alignment.md` |
| Contract fidelity | `rules/contract-fidelity.md` |
| Self-test gate | `rules/self-test-gate.md` |
| Feedback discipline | `rules/feedback-discipline.md` |

## Cases (loaded on trigger)

| When | Read |
|------|------|
| Implementing a UI consuming a BE contract from a sibling issue | `cases/consuming-be-contract.md` |
| Implementing per a Design spec | `cases/implementing-design-spec.md` |
| Spec conflicts with current codebase | `cases/spec-conflict.md` |
| Adding inline state for a flow already on the page | `cases/extending-existing-flow.md` |

## Actions

- `actions/setup.sh` — claim, branch, journal-start
- `actions/deliver.sh` — self-test gate, PR open, route
- `actions/feedback.sh` — write Mode C feedback, route back to arch

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```

Validators that plug into check-all.sh:
- `validate/lint.sh` — eslint + prettier
- `validate/typecheck.sh` — tsc --noEmit
- `validate/a11y.sh` — axe-core scan
- `validate/test.sh` — unit + component tests
