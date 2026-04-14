# Verify Workflow — Execute Test Plan

You have a test plan. Now execute it step by step and produce a verify report.

---

## Phase 0: Check Self-Test Declaration

Before setting up the environment, check if FE/BE completed their self-test:

```bash
gh pr view {PR_NUMBER} --repo {REPO_SLUG} --json body -q '.body'
```

Look for a `## Self-Test` section with checked items. If missing or incomplete:

```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Pre-check by \`{AGENT_ID}\`

**BLOCKED**: PR is missing the self-test declaration.

Please add a \`## Self-Test\` section to the PR body with checked items confirming you verified your own work before QA review.

Returning to ARCH."
bash scripts/route.sh "{REPO_SLUG}" {ISSUE_N} arch "{AGENT_ID}"
```

Do NOT proceed with verification if self-test is missing. Move on to next task.

**Gate**: PR body contains a `## Self-Test` section with all items checked.

---

## Phase 1: Setup Environment

1. **Checkout the branch**:
   ```bash
   gh pr checkout {PR_NUMBER} --repo {REPO_SLUG}
   ```

2. **Install + build**:
   ```bash
   # Detect package manager from lockfile
   pnpm install && pnpm build   # or npm/yarn equivalent
   ```
   If build fails → **FAIL** immediately. Report build error.

3. **Start services**:
   - Dev server (if UI dimension applies)
   - Database (verify connection with a simple query)
   - Any dependent services mentioned in prerequisites

4. **Read the test plan**:
   ```bash
   cat test-plans/{ISSUE_N}-{slug}.md
   ```
   This is your script. Execute it top to bottom.

## Phase 2: Execute — UI Verification (Chrome MCP)

For each `U{N}` step in the test plan:

1. Use Chrome MCP to perform the action:
   - `navigate` to URL
   - `click` on elements (use CSS selectors or text content)
   - `type` into input fields
   - `screenshot` for evidence

2. After each action, verify the expected outcome:
   - Read page content via Chrome MCP
   - Check element visibility, text, state
   - Take a screenshot as proof

3. Record result: `PASS` or `FAIL` with details.

### Chrome MCP Tips

- Wait for navigation/loading after clicks before checking results
- Use descriptive selectors: `button:has-text("Submit")` over `#btn-1`
- For SPAs, wait for content changes after route navigation
- Screenshot both before and after for state-changing actions

## Phase 3: Execute — API Verification (curl)

For each `A{N}` step in the test plan:

1. Run the exact curl command from the plan
2. Check:
   - HTTP status code matches expected
   - Response body contains expected fields/values
   - Response headers are correct (Content-Type, CORS, etc.)
   - Error responses have proper structure

3. Record result with the actual response.

### API Tips

- Use `-s -o /dev/null -w "%{http_code}"` for status-only checks
- Use `jq` to extract and compare specific fields
- Test auth: include and exclude tokens to verify both paths
- Test invalid input: malformed JSON, missing required fields

## Phase 4: Execute — DB Verification

For each `D{N}` step in the test plan:

1. **Detect DB type** (if not already known):
   ```bash
   # Check for connection string
   grep -r "DATABASE_URL" .env* 2>/dev/null
   # Check ORM config
   cat prisma/schema.prisma 2>/dev/null | grep provider
   cat docker-compose.yml 2>/dev/null | grep -A5 "image:.*postgres\|mysql\|mongo"
   ```

2. **Run the query** with the appropriate CLI:

   | DB | CLI | Example |
   |----|-----|---------|
   | PostgreSQL | `psql "$DATABASE_URL" -c "{QUERY}"` | `psql -c "SELECT count(*) FROM users"` |
   | MySQL | `mysql -e "{QUERY}" {DB_NAME}` | `mysql -e "SELECT count(*) FROM users" mydb` |
   | SQLite | `sqlite3 {DB_FILE} "{QUERY}"` | `sqlite3 dev.db "SELECT count(*) FROM users"` |
   | MongoDB | `mongosh --eval "{QUERY}"` | `mongosh --eval "db.users.countDocuments()"` |

3. Compare actual result with expected. Record any discrepancies.

### DB Tips

- Always check row counts AND specific field values
- After write operations (POST/PUT/DELETE), query immediately to verify side effects
- Check for orphaned records, broken foreign keys
- Verify timestamps are reasonable (not null, not year 1970)

## Phase 5: Execute — Load Verification

For each `L{N}` step in the test plan:

1. Run the load test command from the plan
2. Collect metrics:
   - **Throughput**: requests/second
   - **Latency**: p50, p95, p99
   - **Error rate**: percentage of non-2xx responses
3. Compare against thresholds in the plan.

Use `actions/run-load-test.sh` for quick setup if no custom script exists.

## Phase 6: Produce Verify Report

Create the report:

```markdown
# Verify Report: {Issue Title}

- **Issue**: {REPO_SLUG}#{ISSUE_N}
- **PR**: #{PR_NUMBER}
- **Verifier**: {AGENT_ID}
- **Date**: {YYYY-MM-DD}
- **Test Plan**: test-plans/{ISSUE_N}-{slug}.md
- **Verdict**: PASS / FAIL → {FE|BE|DEBUG} / BLOCKED

## Results

| Step | Description | Result | Notes |
|------|-------------|--------|-------|
| U1 | {scenario} | PASS | — |
| U2 | {scenario} | FAIL | Expected X, got Y |
| A1 | {endpoint} | PASS | — |
| D1 | {check} | PASS | — |
| L1 | {scenario} | PASS | p95=120ms |

## Failures (if any)

### U2: {Scenario name}
- **Expected**: {from plan}
- **Actual**: {what happened}
- **Evidence**: screenshot / response / query output
- **Severity**: blocker / major / minor
- **Triage**: → {FE|BE|DEBUG} (reason: {what console/network showed})

## Summary

{1-2 sentences on overall quality}
```

## Phase 7: Verdict + Action

### PASS — All steps green

```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Verify Report by \`{AGENT_ID}\`

All verification steps passed.

**Verdict: PASS**

Full report: \`test-plans/{ISSUE_N}-verify-report.md\`"
```

### FAIL — Any step red

**Surface triage** (see `rules/test-plan.md` → "Failure Triage")

For each failure, spend ≤10 seconds checking Chrome MCP console + network tab to classify:
- No request / API 200 but UI broken → likely **FE**
- API 5xx / wrong response → likely **BE**
- Can't tell → likely **DEBUG**

Include your triage assessment in the report so ARCH can make the routing decision.

```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Verify Report by \`{AGENT_ID}\`

**Verdict: FAIL**

{count} of {total} steps failed.

### Failure Details
{for each failure: step, expected, actual, evidence}

### Triage Assessment
{for each failure: likely owner (FE/BE/DEBUG) and reasoning}

Full report: \`test-plans/{ISSUE_N}-verify-report.md\`"
```

### BLOCKED — Cannot verify

Report the blocker clearly. Do NOT approve or reject.

### Post-verdict: Route back to ARCH

**QA does NOT merge, reject, or reassign.** All verdicts route back to ARCH for decision.

**MUST use `route.sh`** — do NOT use raw `gh issue edit` for label changes (causes label race conditions).

```bash
bash scripts/route.sh "{REPO_SLUG}" {ISSUE_N} arch "{AGENT_ID}"
```

> **Why**: ARCH is the sole merge authority and dispatcher. QA provides the verdict and evidence; ARCH decides the action (merge, route to Design for visual review, reject back to FE/BE, or escalate to DEBUG).

## Phase 8: Journal

Write to `log/` via `actions/write-journal.sh`:
- What verification approaches worked
- What was hard to verify and why
- Patterns noticed across this repo's PRs
