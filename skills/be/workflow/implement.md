# Implementation Workflow

Phases: Understand → Plan → Implement → Validate → Deliver → Journal

Each phase has a gate. Do not skip ahead.

## Phase 1: Understand

1. Read the issue spec (title + body + acceptance criteria). Read it twice.
2. Check for QA feedback on the issue (previous rejection comments).
3. Read related code — understand patterns, naming, architecture.
4. Read last 5 journal entries from `log/` for this repo.

**Gate**: Can you explain the change in one sentence?

## Phase 2: Plan

1. List files to change and why.
2. Determine test strategy — what exists, what's needed.
3. Check for blockers (missing deps, unclear spec).
4. Ambiguous spec → conservative interpretation + comment.
5. **Spec feasibility check** — does the spec conflict with:
   - Existing DB schema or API contracts?
   - Performance rules? (e.g. spec implies N+1 pattern)
   - Security rules? (e.g. spec exposes data without auth check)
   - An existing module that already does this? (extend vs create new)

### If spec has problems → feedback to ARCH

You know the codebase deeper than ARCH. If the spec's approach conflicts with what exists or violates your rules, feed back:

```bash
# 1. Comment with technical insight
gh issue comment {N} --repo {REPO_SLUG} \
  --body "## Technical Feedback from \`{AGENT_ID}\`

### Conflict
{what the spec asks} vs {what the codebase actually has/needs}.

### Suggestion
{your recommended approach}

### Affected
{which parts of the spec need revision}"

# 2. Hand back to ARCH (MUST use route.sh)
bash scripts/route.sh "{REPO_SLUG}" {N} arch "{AGENT_ID}"
```

Move on to next task. Don't wait.

**Gate**: Spec is feasible. If not, feed back and move on.

## Phase 3: Implement (TDD)

1. Create branch: `agent/{AGENT_ID}/issue-{N}`
2. For each behavior unit, follow **Red → Green → Refactor**:
   - **Red**: Write a single failing test that defines the expected behavior. Run it. Confirm it fails.
   - **Green**: Write the minimum code to make the test pass. Run it. Confirm it passes.
   - **Refactor**: Clean up implementation. Run tests. Confirm they still pass.
3. Repeat step 2 for each behavior: happy path → error paths → edge cases.
4. Do NOT batch — one cycle per behavior, not "write all tests then implement."

## Phase 4: Validate

Run `validate/check-all.sh` which executes all rule validations.
Max 3 rounds: validate → fix → re-validate.

## Phase 5: Deliver

1. Run full test suite.
2. Commit: `{commit_prefix} {title} (closes #{N})`
3. Push + open PR.
4. Update API status + release claim.

## Phase 6: Journal

Read `cases/` for any relevant patterns. Write entry to `log/` using the journal template.
