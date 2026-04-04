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
   - Existing CI/CD pipeline structure or deployment config?
   - Security rules? (e.g. spec exposes secrets, uses root containers)
   - Infrastructure constraints? (e.g. spec assumes resources that don't exist)
   - An existing setup that already handles this?

### If spec has problems → feedback to ARCH

You know the infra deeper than ARCH. If the spec conflicts with reality, feed back:

```bash
# 1. Comment with technical insight
gh issue comment {N} --repo {REPO_SLUG} \
  --body "## Technical Feedback from \`{AGENT_ID}\`

### Conflict
{what the spec asks} vs {what the infrastructure actually has/needs}.

### Suggestion
{your recommended approach}

### Affected
{which parts of the spec need revision}"

# 2. Hand back to ARCH
CURRENT_AGENT=$(gh issue view {N} --repo {REPO_SLUG} --json labels \
  --jq '[.labels[].name | select(startswith("agent:"))] | .[0] // empty')
[ -n "$CURRENT_AGENT" ] && gh issue edit {N} --repo {REPO_SLUG} --remove-label "$CURRENT_AGENT"
gh issue edit {N} --repo {REPO_SLUG} \
  --remove-label "status:in-progress" \
  --add-label "agent:arch" --add-label "status:ready"
```

Move on to next task. Don't wait.

**Gate**: Spec is feasible. If not, feed back and move on.

## Phase 3: Implement

1. Create branch: `agent/{AGENT_ID}/issue-{N}`
2. Code following existing patterns.
3. Write tests alongside code, not after.

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
