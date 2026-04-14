# Verify Workflow — Execute Test Plan

You have a test plan. Now execute it step by step and produce a verify report.

---

## Phase 0: Check Self-Test Record

Before setting up the environment, check if FE/BE completed their self-test:

```bash
gh pr view {PR_NUMBER} --repo {REPO_SLUG} --comments --json comments \
  --jq '.comments[] | select(.body | test("^# Self-Test")) | .body'
```

**If no self-test record found** (applies to FE and BE PRs, not OPS):

```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Pre-check by \`{AGENT_ID}\`

**BLOCKED**: PR is missing the self-test record.

Implementer must complete self-testing before QA verification.
Expected: a PR comment starting with \`# Self-Test:\` including AC verification steps and results.

Returning to ARCH."
bash scripts/route.sh "{REPO_SLUG}" {ISSUE_N} arch "{AGENT_ID}"
```

Do NOT proceed with verification if self-test is missing. Move on to next task.

If self-test record found, note what was already verified. Focus your execution on:
- Steps the self-test did NOT cover
- Steps where the self-test result looks suspicious
- Edge cases and error paths beyond the AC

**Gate**: Self-test record exists on the PR.

---

## Phase 1: Setup Environment

1. **Checkout the branch** (for reading test plan and code):
   ```bash
   gh pr checkout {PR_NUMBER} --repo {REPO_SLUG}
   ```

2. **Get preview URL** (platform-agnostic):
   ```bash
   # Extract deployment URL from PR comments (Vercel, Fly.io, Netlify, etc.)
   gh pr view {PR_NUMBER} --repo {REPO_SLUG} --json comments \
     --jq '[.comments[].body] | map(select(test("https://.*\\.(vercel\\.app|fly\\.dev|netlify\\.app|onrender\\.com)"))) | last' \
     | grep -oE 'https://[a-zA-Z0-9._-]+\.(vercel\.app|fly\.dev|netlify\.app|onrender\.com)'
   ```
   If no preview URL available → report **BLOCKED**.

   QA does NOT build or run the app locally. All verification targets the preview environment.

3. **Read the test plan**:
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

1. Run the exact curl command from the plan (targeting preview URL)
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

## Phase 8: Codify (PASS verdict only)

When all steps pass, convert the verified test plan into persistent, executable tests. This is how manual verification becomes automated regression protection.

### Principles

1. **Black-box only** — QA tests against a deployed URL, not local services. UI and API are the same from the outside.
2. **Preview environment** — all tests target the PR's preview URL (e.g., Vercel Preview), never `localhost`
3. **QA only touches `e2e/` and `test-plans/`** — never modify app source code (`src/`, `apps/`, `packages/`)
4. **One feature, one file** — UI interactions + API calls for the same feature live together

### Test Environment

Tests run against the PR's preview deployment. The base URL comes from environment:

```typescript
// playwright.config.ts (already set up by OPS/ARCH)
export default defineConfig({
  use: {
    baseURL: process.env.PREVIEW_URL || 'http://localhost:3000',
  },
});
```

QA does NOT start local servers. If preview URL is not available, report BLOCKED to ARCH.

### File Structure (monorepo)

```
repo-root/
  apps/
    web/          ← FE code (QA does NOT touch)
    api/          ← BE code (QA does NOT touch)
  e2e/            ← QA's territory
    {feature}.spec.ts     ← UI + API tests for one feature
    playwright.config.ts  ← shared config
  test-plans/     ← QA's territory
    {N}-{slug}.md
```

### What to Codify

| Plan Step Type | Codify? | Goes into |
|---------------|---------|-----------|
| `U{N}` (UI) | Yes | `e2e/{feature}.spec.ts` |
| `A{N}` (API) | Yes | same file — `request` fixture in Playwright |
| `E{N}` (Edge) | Yes | same file |
| `D{N}` (DB) | No — verification-only, schema covered by migrations | — |
| `L{N}` (Load) | No — periodic, not per-PR | — |

### Example: One Feature, One File

```typescript
// e2e/user-management.spec.ts
import { test, expect } from '@playwright/test';

test.describe('User Management', () => {

  // === UI Tests (from U steps) ===

  // U1: Page loads with user list
  test('dashboard shows user list', async ({ page }) => {
    await page.goto('/dashboard');
    await expect(page.getByRole('heading', { name: 'Users' })).toBeVisible();
    await expect(page.getByRole('table')).toBeVisible();
  });

  // U2: Create user via modal
  test('create user modal flow', async ({ page }) => {
    await page.goto('/dashboard');
    await page.getByRole('button', { name: 'Create' }).click();
    await expect(page.getByRole('dialog')).toBeVisible();

    await page.getByLabel('Name').fill('Test User');
    await page.getByRole('button', { name: 'Submit' }).click();

    await expect(page.getByRole('dialog')).not.toBeVisible();
    await expect(page.getByText('Test User')).toBeVisible();
  });

  // E1: Empty form validation
  test('shows validation error on empty submit', async ({ page }) => {
    await page.goto('/dashboard');
    await page.getByRole('button', { name: 'Create' }).click();
    await page.getByRole('button', { name: 'Submit' }).click();
    await expect(page.getByText('Name is required')).toBeVisible();
  });

  // === API Tests (from A steps) ===

  // A1: Create user endpoint
  test('POST /api/users creates user', async ({ request }) => {
    const res = await request.post('/api/users', {
      data: { name: 'Test User', email: 'test@example.com' }
    });
    expect(res.status()).toBe(201);
    const body = await res.json();
    expect(body).toHaveProperty('id');
    expect(body.name).toBe('Test User');
  });

  // A2: Reject invalid payload
  test('POST /api/users rejects missing name', async ({ request }) => {
    const res = await request.post('/api/users', {
      data: { email: 'test@example.com' }
    });
    expect(res.status()).toBe(400);
  });
});
```

### Rules

1. **Only codify verified steps** — if you didn't manually verify it passed, don't automate it
2. **Test names reference the plan step** (U1, A2, E1) — traceability back to test plan
3. **Follow the project's existing test setup** — if they use Cypress instead of Playwright, use Cypress
4. **Commit tests on the QA branch** before delivering back to ARCH
5. **Never import app internals** — no `import { db } from '../../apps/api/src/db'`, tests are pure black-box

### Scope Guard

QA may only create or modify files in:
- `e2e/**`
- `test-plans/**`

If you need changes outside these directories (e.g., `playwright.config.ts` at root, CI config), create a follow-up issue for ARCH/OPS instead.

### Deliver Codified Tests

After writing the E2E tests, commit and push on the existing PR branch:

```bash
# Stage only e2e/ and test-plans/ (QA Scope Guard)
git add e2e/ test-plans/
git commit -m "test: codify E2E tests from test plan #{ISSUE_N}"
git push origin HEAD
```

Then post a comment on the PR and route back to ARCH:

```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Codify by \`{AGENT_ID}\`

Added E2E tests from verified test plan:
- \`e2e/{feature}.spec.ts\` ({count} tests)

Ready for merge."

bash scripts/route.sh "{REPO_SLUG}" {ISSUE_N} arch "{AGENT_ID}"
```

### When NOT to Codify

- **No E2E infrastructure** — no `playwright.config.ts`, no `e2e/` directory
  → Create follow-up issue for ARCH: "Set up E2E test infrastructure"
- **One-off feature** — admin script, migration helper, won't be iterated
- **ARCH spec says `testing: self-test-only`**

## Phase 9: Journal

Write to `log/` via `actions/write-journal.sh`:
- What verification approaches worked
- What was hard to verify and why
- Patterns noticed across this repo's PRs
