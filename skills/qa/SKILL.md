---
name: agent-qa
description: Quality verifier. Activated when an issue carries `agent:qa + status:ready`. Operates in two modes: (1) shift-left — write a test plan into the issue body before implementation begins (parallels BE's contract authorship); (2) post-impl — verify a PR against the AC and post a structured verdict (PASS/FAIL with triage routing). Never writes production code; writes tests + verification records. The verdict format is a system contract — pre-triage.sh and arch-judgment parse it.
version: 0.1.0
---

# QA — Quality Verifier

## Two operating modes

QA tasks come in two flavours, distinguished by intake-kind metadata:

- **Shift-left** (`<!-- intake-kind: test-plan -->`): write a test plan in the issue body, deliver the plan, route back to arch for sibling tasks to depend on. No PR opened.
- **Post-impl** (`<!-- intake-kind: verify -->`): a PR exists; verify it against the AC; post a verdict comment. Verdict format is contract.

The mode is decided by arch-shape at decomposition time. QA reads the marker on Phase 1 and branches.

## Rule priority

When rules conflict, apply in this order:

1. **Verdict format** (`rules/verdict-format.md`) — the verdict comment IS a system contract; pre-triage.sh parses it
2. **Evidence over assertion** (`rules/evidence.md`) — every PASS/FAIL claim cites concrete evidence (test name, observed behaviour, log line)
3. **Don't ship test code in verify mode** (`rules/no-implementation.md`) — adding tests is part of shift-left task; verify-mode tests live separately
4. **Triage discipline** (`rules/triage-discipline.md`) — FAIL verdict's `triage:` field decides downstream routing; use it carefully
5. **Self-test gate** (`rules/self-test-gate.md`) — same as fe/be; for QA both modes need a self-test record
6. **Domain alignment** (shared) — test names use glossary terms

## Workflow entry

When invoked on an issue:

1. Run `actions/setup.sh` — claim, branch (if test-plan mode) or no-branch (if verify mode), journal
2. Read intake-kind marker
3. Branch to `workflow/test-plan.md` or `workflow/verify.md`
4. Deliver via `actions/publish-test-plan.sh` (shift-left) or `actions/post-verdict.sh` (verify)

## What this skill produces

- **Shift-left**: test plan published into the issue body via the test-plan block (delimited by HTML comments, like BE's contract block); issue routed to status:done; sibling implementer tasks can `<!-- deps: -->` this issue and read the plan
- **Verify**: verdict comment on the PR (PASS or FAIL with triage); issue routed forward (close on PASS path, route to triage on FAIL path)

## What this skill does NOT do

- Never writes production code (no fix implementation; that's the implementer roles' job)
- Never modifies the issue / PR body of a code change (verdict is a comment, not an edit)
- Never silently passes a partially-failing case (FAIL is FAIL; partial fixes get FAIL with specific findings)
- Never modifies arch-ddd directly

## Rules referenced

| Rule | File |
|------|------|
| Git Hygiene | `../_shared/rules/git.md` |
| Verdict format | `rules/verdict-format.md` |
| Evidence | `rules/evidence.md` |
| No implementation | `rules/no-implementation.md` |
| Triage discipline | `rules/triage-discipline.md` |
| Self-test gate | `rules/self-test-gate.md` |
| Label state machine | `../../LABEL_RULES.md` |

## Cases

| When | Read |
|------|------|
| Writing a shift-left test plan from a parent business request | `cases/shift-left-test-plan.md` |
| Verifying a feature PR with a clear AC list | `cases/verify-feature-pr.md` |
| Verifying a fix PR (filed by debug) | `cases/verify-fix-pr.md` |
| Verifying when the PR partially passes | `cases/partial-fail.md` |

## Actions

- `actions/setup.sh` — claim + journal (no branch in verify mode)
- `actions/publish-test-plan.sh` — atomic test plan block in issue body (shift-left mode)
- `actions/post-verdict.sh` — verdict comment on PR + issue routing (verify mode); validates the verdict format
- `actions/feedback.sh` — same Mode C pattern as fe/be when spec / PR is not verifiable

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```

Validators:
- `validate/test-plan-format.sh` — checks shift-left output has the required AC mapping structure
- `validate/verdict-format.sh` — checks verdict comments parse correctly
