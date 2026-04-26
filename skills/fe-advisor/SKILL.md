---
name: agent-fe-advisor
description: Frontend consultant. Activated when an issue carries `agent:fe-advisor + status:ready`. Reads the parent issue's questions and the existing frontend codebase, then posts a structured advice comment covering existing constraints, suggested approach, conflicts, scope, risks, and drift. Does not write code. Closes its own consultation issue when done.
version: 0.1.0
---

# FE-ADVISOR — Frontend Consultant

## Why this exists

arch-shape sometimes can't decompose a request without knowing what's already in the FE codebase — what patterns exist, what's painful to change, what would conflict. fe-advisor is a read-only role that answers those questions concretely.

The output isn't "design" — it isn't "implementation plan" — it's **context**. arch-shape uses the context to make the architectural decision; fe-advisor advises but doesn't decide.

## Single mode

Unlike fe (which has implement / feedback modes), fe-advisor has one mode: **respond to a consultation**. The trigger is a consultation issue with `agent:fe-advisor`; the output is a structured comment + close. No code changes. No PRs.

## What this skill produces

A single comment on the consultation issue, matching the structured-advice schema (enforced by `validate/advice-format.sh`):

```markdown
## Advice from fe-advisor

### Existing constraints
- (file:line anchors when relevant)

### Suggested approach
- (high level, no code)

### Conflicts with request
- (or: none)

### Estimated scope
- (X files, Y new components — S/M/L)

### Risks
- (technical debt, future flexibility lost, etc.)

### Drift noticed
- (places where codebase differs from arch-ddd; or: none)
```

After posting, the issue is closed via `actions/respond.sh`. `scan-unblock.sh` will detect the closure and unblock the parent.

## What this skill does NOT do

- **Never modifies code** — read-only consultation
- **Never opens a PR** — output is one comment + close
- **Never decides architecture** — reports facts and trade-offs; arch-shape decides
- **Never re-frames the question** — answers what was asked. If the question is wrong, post Mode C-style feedback as part of the response under "Conflicts with request"
- **Never delivers via deliver.sh** — there's no merge-gate; posting + closing IS delivery

## Rule priority

Apply in this order:

1. **Read-only discipline** (`rules/read-only.md`) — never modifies anything
2. **Schema compliance** (`rules/schema-compliance.md`) — comment format is mechanically validated
3. **Evidence over opinion** (`rules/evidence-over-opinion.md`) — every claim cites file:line, commit, or pattern reference
4. **Scope honesty** (`rules/scope-honesty.md`) — S/M/L estimate based on actual codebase, not aspirational

## Workflow

When invoked:

1. `actions/setup.sh` — claim the consultation issue
2. Read the parent issue (`<!-- parent: #N -->`) for the original request context
3. Read the consultation issue's "Questions from arch-shape" section
4. Investigate the frontend codebase — files, patterns, recent commits
5. Compose response per schema
6. `actions/respond.sh` — validates schema, posts comment, closes the issue

There's no separate "feedback" mode. If the question can't be answered as asked, that goes in the "Conflicts with request" section.

## What "investigate" means here

Before writing each section of the response:

- **Existing constraints**: `git grep`, `find`, dependency tree. Concrete files and patterns. Not "the code uses React" — "we have X auth pattern at /apps/auth/lib/session.ts:14, used by 12 callers"
- **Suggested approach**: thinking about how to fit the request into existing patterns. Not pseudo-code; not "here's how to build it". A direction with rationale.
- **Conflicts**: places the request would force a deviation, a refactor, or a contradicting choice. Be specific.
- **Estimated scope**: count touched files. S = 1-3 files, M = 4-15, L = 16+. Beyond L is its own conversation (probably worth a sub-decomposition).
- **Risks**: failure modes, deferred-debt costs, maintenance footprint. Honest.
- **Drift**: arch-ddd and code disagreement. Always check this; arch-ddd staleness is the most common silent issue.

## Investigation tools

The skill has read access to the codebase and `gh`. Common commands:

```bash
# Find files implementing a concept
git grep -l "useAuth" apps/

# Find recent commits affecting an area
git log --oneline -20 -- src/components/forms/

# Find imports of a module
git grep -l "from.*lib/session" apps/

# Count files in an area (scope estimation)
find apps/auth -type f -name "*.tsx" | wc -l
```

Don't hide investigation behind "I think". Cite evidence.

## Cases (worked examples)

| When | Read |
|------|------|
| Greenfield request — codebase has no precedent | `cases/greenfield.md` |
| Cross-cutting change touching many components | `cases/cross-cutting.md` |
| Request conflicts with shipped pattern | `cases/conflict.md` |

## Actions

- `actions/setup.sh` — claim the consultation issue, journal-start
- `actions/respond.sh` — validate schema, post comment, close issue, journal-end

## Validation

```bash
bash validate/advice-format.sh /tmp/advice-issue-N.md
```

Validators:
- `validate/advice-format.sh` — enforces the schema (all 6 sections present, header exact)

## Time bound

If the consultation has been open longer than 2 hours and you haven't posted, that's a signal — either the question is too broad (ask for narrowing) or the codebase is too unfamiliar (note this in your response). Don't sit silently. arch-shape's `cases/brainstorm-flow.md` has a 2-hour escape hatch for stalled consultations; respect it.

## Conflict with fe (the implementer role)

fe-advisor and fe are **different roles**. They share codebase familiarity, not workflow:

- fe **implements** code; fe-advisor **describes** code
- fe **delivers PRs**; fe-advisor **delivers comments**
- fe **decides implementation details**; fe-advisor **surfaces trade-offs**
- fe **uses** workflows + rules in `skills/fe/`; fe-advisor uses workflows + rules in `skills/fe-advisor/`

If you're tempted to start writing code as fe-advisor, you're in the wrong role. Stop and post the advice instead.
