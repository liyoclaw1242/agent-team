# Plan Workflow — Produce Test Plan from Spec

This is the shift-left phase. You receive a spec (issue) and produce a test plan **before or in parallel with** implementation.

---

## Phase 1: Read the Spec

```bash
gh issue view {ISSUE_N} --repo {REPO_SLUG}
```

Extract:
- **Acceptance criteria** — what must be true when done
- **Affected surfaces** — UI pages, API endpoints, DB tables, background jobs
- **Edge cases** — mentioned or implied
- **Non-functional requirements** — performance, security, a11y

## Phase 2: Determine Dimensions

Based on the spec, decide which verification dimensions apply:

| Spec mentions... | Activate |
|-----------------|----------|
| Pages, components, user interaction, routes | UI (Chrome MCP) |
| Endpoints, services, REST/GraphQL | API (curl/httpie) |
| Models, migrations, schema, data | DB (psql/mysql/sqlite3/mongosh) |
| Performance, latency, throughput, scale | Load (k6/autocannon) |

Mark dimensions that don't apply as `N/A` in the plan.

## Phase 3: Write the Test Plan

Create the test plan as a markdown file. Structure:

```markdown
# Test Plan: {Issue Title}

- **Issue**: {REPO_SLUG}#{ISSUE_N}
- **Author**: {AGENT_ID}
- **Date**: {YYYY-MM-DD}
- **Dimensions**: UI / API / DB / Load (list applicable)

## Prerequisites

- [ ] Dev server running at {URL}
- [ ] DB accessible via {CLI}
- [ ] Test data seeded (describe what)

## UI Verification (Chrome MCP)

### U1: {Scenario name}
- **Action**: Navigate to {URL}, click {element}, fill {field} with {value}
- **Expected**: {what should appear/happen}

### U2: {Scenario name}
- **Action**: ...
- **Expected**: ...

## API Verification (curl)

### A1: {Endpoint description}
- **Request**: `curl -X POST {URL} -H "Content-Type: application/json" -d '{payload}'`
- **Expected**: Status {code}, body contains {key}: {value}

### A2: {Endpoint description}
- **Request**: ...
- **Expected**: ...

## DB Verification

### D1: {What to check}
- **Query**: `SELECT ... FROM ... WHERE ...`
- **Expected**: {row count}, {column values}

### D2: {What to check}
- **Query**: ...
- **Expected**: ...

## Load Verification

### L1: {Scenario}
- **Command**: `k6 run --vus {N} --duration {T} {script}`
- **Expected**: p95 < {ms}, error rate < {%}

## Edge Cases

### E1: {Edge case}
- **Action**: ...
- **Expected**: ...
```

## Phase 4: Coverage Check

Before finalizing, verify:

- [ ] Every acceptance criterion from the spec has at least one test step
- [ ] Happy path covered for each dimension
- [ ] At least one error/edge case per dimension
- [ ] Prerequisites are specific enough to reproduce

## Phase 5: Publish the Plan

Save the test plan to the repo:

```bash
mkdir -p test-plans
# filename: test-plans/{ISSUE_N}-{slug}.md
```

Post a comment on the issue with a link to the plan:

```bash
gh issue comment {ISSUE_N} --repo {REPO_SLUG} \
  --body "## Test Plan by \`{AGENT_ID}\`

Test plan ready: \`test-plans/{ISSUE_N}-{slug}.md\`

**Dimensions**: {list}
**Steps**: {count}

Implementation can proceed — I'll verify once delivered."
```

This signals to FE/BE agents that verification criteria exist before they finish.
