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

### Phase 2: Check Self-Test Record

Before reviewing code, check if the implementer left a self-test record on the PR:

```bash
gh pr view {PR_NUMBER} --repo {REPO_SLUG} --comments --json comments \
  --jq '.comments[] | select(.body | test("^# Self-Test")) | .body'
```

**If no self-test record found** (applies to FE and BE PRs, not OPS):

```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## QA Review by \`{AGENT_ID}\`

**NEEDS CHANGES**: No self-test record found.

Implementer must complete self-testing before QA review.
Expected: a PR comment starting with \`# Self-Test:\` including AC verification steps and results.

**Verdict: BLOCKED — missing self-test**"
```

Route back to ARCH. Do NOT proceed with code review.

**If self-test record found**, read it and note:
1. **What was verified** — which AC items were tested
2. **What was missed** — edge cases, error states, boundary values
3. **Quality of testing** — did they actually exercise the feature, or just check surface-level?
4. **Reported issues** — any console errors, network failures mentioned?

Carry this into your review — focus effort on gaps.

### Phase 3: Understand

For each unreviewed PR:
1. **Read the spec**: `gh issue view {ISSUE_N} --repo {REPO_SLUG}`
2. **Read the diff**: `gh pr diff {PR_NUMBER} --repo {REPO_SLUG}`
3. **Note the gap**: does the diff match the spec?

### Phase 4: Two-Pass Review

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

### Phase 5: Verdict

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

Self-test record was already checked in Mode A Phase 2. Use the findings from there to focus your functional testing on gaps.

Get the preview URL from the PR deployment:
```bash
gh pr view {PR_NUMBER} --repo {REPO_SLUG} --json comments,body \
  --jq '[.comments[].body, .body] | map(select(test("https://.*\\.vercel\\.app"))) | first'
```

QA does NOT build or run the app locally. All testing targets the preview environment.
If no preview URL → report BLOCKED.

### Phase 2: Smoke Test via Browser MCP

Use Browser MCP to navigate the preview URL and verify:
- [ ] Page loads without errors
- [ ] No broken layouts or missing elements
- [ ] Correct data/content shown
- [ ] Console has no errors
- [ ] Network requests return expected status codes

### Phase 4: Acceptance Criteria (focus on gaps)

Go through each acceptance criterion from the issue spec.

**If FE self-test covered an AC item**: spot-check rather than full re-test — verify FE's claim, don't redo the work.

**Focus your effort on**:
- AC items FE did NOT cover in their self-test
- Edge cases: empty state, error state, boundary values
- Cross-browser / responsive issues FE might have missed
- Keyboard navigation and accessibility
- State persistence after page refresh

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
