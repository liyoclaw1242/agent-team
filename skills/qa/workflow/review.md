# Review Workflow

Three modes: **Code Review** (read diff) → **Functional Test** (run the app) → **Hands-on Verification** (acceptance criteria).

## Review Pipeline

In a real team, a PR goes through:
```
FE completes → QA code review → QA functional test → Design visual review → merge
```

QA handles the first two. Design handles the visual review separately. QA coordinates by tagging Design when a frontend PR needs visual sign-off.

---

## Mode A: Code Review (read the diff)

### Phase 1: Discover

List open agent PRs for YOUR repo:
```bash
gh pr list --repo {REPO_SLUG} --state open \
  --json number,title,headRefName,url --limit 10
```
Filter: only PRs where `headRefName` starts with `agent/`.
Skip PRs already reviewed (check for "QA Review by" comment with no new commits since).

### Phase 2: Understand

For each unreviewed PR:
1. **Read the spec**: `gh issue view {ISSUE_N} --repo {REPO_SLUG}`
2. **Read the diff**: `gh pr diff {PR_NUMBER} --repo {REPO_SLUG}`
3. **Note the gap**: does the diff match the spec?

### Phase 3: Two-Pass Review

**Pass 1 — Correctness**:
- Does it implement what the spec asked?
- Missing edge cases?
- Tests cover acceptance criteria?
- Scope creep (changes not in spec)?

**Pass 2 — Quality + Security**:
- Security: OWASP top 10 (injection, XSS, auth bypass, secrets)
- Code quality: naming, structure, dead code
- Tests: meaningful assertions
- Standards: check against the agent's role standards

### Phase 4: Verdict

**APPROVED** (code level) → proceed to Mode B if it's a frontend PR. Otherwise merge:
```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Review by \`{AGENT_ID}\`\n\nCode review passed.\n\n**Verdict: APPROVED**"
gh pr merge {PR_NUMBER} --repo {REPO_SLUG} --squash --delete-branch
```

**APPROVED but needs visual review** (frontend PRs):
```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Review by \`{AGENT_ID}\`\n\nCode review passed. Frontend PR — needs Design visual review before merge.\n\n**Code: APPROVED** | **Visual: PENDING**"
```
Do NOT merge yet. The Design agent will do visual review.

**NEEDS CHANGES** → close PR, post feedback, reset issue to `ready`.

---

## Mode B: Functional Test (run the app)

For frontend PRs, after code review passes:

### Phase 1: Setup

```bash
gh pr checkout {PR_NUMBER} --repo {REPO_SLUG}
pnpm install && pnpm build
```
If build fails → reject immediately.

### Phase 2: Run Tests

```bash
pnpm test
```
If tests fail → reject with test output.

### Phase 3: Smoke Test with Screenshots

Start dev server and verify the app works:
```bash
pnpm dev &
sleep 5

# Capture screenshots of affected routes
bash skills/qa/actions/capture-screenshots.sh \
  http://localhost:3000 \
  /tmp/qa-screenshots \
  / /affected-route
```

Read the screenshots to verify:
- [ ] Page loads without errors
- [ ] No broken layouts or missing elements
- [ ] Correct data/content shown

### Phase 4: Acceptance Criteria

Go through each acceptance criterion from the issue spec:
- [ ] Criterion 1: {verify}
- [ ] Criterion 2: {verify}
- ...

### Phase 5: Report

If all pass and it's a frontend PR → leave it for Design visual review.
If all pass and it's NOT a frontend PR → merge.
If any fail → reject with specific findings.

---

## Mode C: Hands-on Verification (post-merge)

For QA-specific bounties (e.g., "verify the full scaffold works"):

1. **Checkout main**: `git fetch origin main && git checkout main && git pull`
2. **Install + build + test**: `pnpm install && pnpm build && pnpm test`
3. **Run through acceptance criteria** from the issue
4. **Post findings** as issue comment with pass/fail checklist
5. **PASS** → close issue. **FAIL** → reset to ready.

---

## Journal

After every review, write to `log/`:
- What patterns you noticed (good and bad)
- Common mistakes by this repo's agents
- Test gaps you identified
