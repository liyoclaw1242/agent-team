# Workflow — Verify (post-impl mode)

Activated when issue body has `<!-- intake-kind: verify -->`. There's a PR open; your job is to verify it against AC and post a verdict.

## Phase 1 — Read

Required:

1. The QA issue body
2. Parent issue body (the AC live there)
3. Linked PR (`gh pr view {N}` — code, description, CI status, current verdicts)
4. The implementer's self-test record (in PR body or `/tmp/self-test-issue-{N}.md` if shared)
5. Sibling shift-left QA issue (if exists) — its test plan tells you what to expect to be covered

Conditional:

6. arch-ddd files for the affected bounded context if the change is non-trivial
7. Other in-flight PRs that touch the same surface (regression risk)

## Phase 2 — Run validators

Run the implementer's role validators (they should already pass since the implementer's deliver gate ran them; verify they still pass on the PR's HEAD):

```bash
git checkout pr/$PR_N    # or: gh pr checkout $PR_N
bash skills/{role}/validate/check-all.sh    # whichever role's PR
```

If validators fail on PR HEAD: that's a FAIL outcome before AC walk-through. Don't continue; post FAIL with `triage: {role}` referring it back.

## Phase 3 — Walk the AC

For each AC item, verify the PR delivers it. Match each AC to one of these outcomes:

### Outcome: ✓ verified

You have concrete evidence the AC is met. Record:

- AC text
- Evidence (test name that covers it, manual click-through that demonstrated it, log line, screenshot, etc.)

```markdown
- AC #1: Cancel button shows loading state during request
  - Evidence: TestCancelButton_LoadingDuringRequest passes; manual: clicked button on PR's preview deploy, observed disabled+spinner ~400ms
```

### Outcome: ✗ failed

The AC is not met. Be specific about how it's not met:

```markdown
- AC #2: Confirmation modal opens on click
  - FAIL: clicking the button opens nothing; console error "useModal is not a function".
    Test TestCancelModal_OpensOnButtonClick is missing from the PR.
  - Triage: fe (this is a frontend implementation gap)
```

### Outcome: ? cannot verify

You can't tell either way. Common reasons: AC requires production data, integration with external service, manual workflow that's blocked.

```markdown
- AC #5: Cancellation event emits to analytics
  - Cannot verify locally: requires staging env with analytics consumer
  - Implementer's self-test claims local verification of emit code path; trust trade-off
```

If a "cannot verify" item is critical, escalate before posting verdict (Mode C feedback or arch-judgment route).

## Phase 4 — Compose the verdict

The verdict format is **system contract** — `pre-triage.sh` and `arch-judgment` parse it. Use `actions/post-verdict.sh` which validates format before posting.

### PASS verdict

```markdown
## QA Verdict: PASS

- AC #1: Cancel button shows loading state — ✓
  Evidence: TestCancelButton_LoadingDuringRequest passes; manual click-through on staging
- AC #2: Modal opens on click — ✓
  Evidence: TestCancelModal_OpensOnButtonClick passes; observed in staging
- AC #3: Successful cancel returns 200 + effectiveDate — ✓
  Evidence: Integration test TestCancel_Success_ReturnsEffectiveDate passes; manual call returns expected shape
- AC #4: 404 when not found — ✓
  Evidence: TestCancel_404_WhenNotFound passes
- AC #5: 409 when already cancelled — ✓
  Evidence: TestCancel_409_WhenAlreadyCancelled passes; manual: called twice, got 409 second time

triage: none

Verified-on: PR commit abc1234
```

### FAIL verdict

```markdown
## QA Verdict: FAIL

- AC #1: Cancel button shows loading state — ✓
- AC #2: Modal opens on click — ✗
  FAIL: Clicking the button does not open the modal. Console shows
  "useModal is not a function" — likely a missing import in CancelButton.tsx:42.
  Test for this AC (TestCancelModal_OpensOnButtonClick) is missing.
- AC #3: Successful cancel returns 200 + effectiveDate — ✓
- AC #4: 404 when not found — ✓
- AC #5: 409 when already cancelled — not reached due to AC #2 failure

triage: fe

Verified-on: PR commit abc1234
```

### Critical fields

- **First line**: exactly `## QA Verdict: PASS` or `## QA Verdict: FAIL` (no extra punctuation; pre-triage parses with strict regex)
- **AC list**: every AC item from the parent appears, with verdict per item
- **`triage:` line**: required even on PASS (use `triage: none`); on FAIL, names the role to route to (`fe`, `be`, `ops`, `design`)
- **`Verified-on:` line**: the PR commit SHA you verified against (so reviewers know the PR may have moved since)

## Phase 5 — Post and route

```bash
bash actions/post-verdict.sh \
  --issue $ISSUE_N \
  --pr $PR_N \
  --verdict-file /tmp/verdict-$ISSUE_N.md
```

The action:
1. Validates the verdict file format (regex on first line, presence of `triage:` and `Verified-on:` lines)
2. Posts the verdict as a comment on the PR
3. Posts a summary on the QA issue
4. Routes the QA issue forward:
   - PASS: routes to `status:done` (close the QA issue; the PR's merge will close the implementer's issue separately)
   - FAIL: routes to `agent:arch` (dispatcher → pre-triage will read the verdict and route per `triage:` field)

## Phase 6 — Self-test

```markdown
# Self-test record — issue #146

## Acceptance criteria for this QA task
- [x] Walked all AC items from parent #142
  - Verified: 5 AC items; each has a verdict line
- [x] Validators run on PR HEAD
  - Verified: lint, typecheck, test, a11y all pass on commit abc1234
- [x] Verdict comment posted on PR
  - Verified: comment URL (link)
- [x] Triage field set correctly (FAIL only)
  - N/A this issue (PASS)

## Verdict
PASS

## Ready for review: yes
```

## Anti-patterns

- **Skipping AC items in the verdict** — every AC must appear with a verdict. Missing items produce silent passes that arch-judgment will catch later.
- **PASS with hedging** ("mostly works", "good enough") — there is no "mostly". Either every AC is ✓ → PASS, or at least one is ✗ → FAIL.
- **Triage to "everyone"** — `triage:` takes one role. If multiple roles are at fault, pick the most-affected and explain in the verdict.
- **Lying about evidence** — "Evidence: I verified manually" when you didn't. The downstream cost (production bug) lands on the team. Cite specific tests / logs / screenshots.
- **Verifying against stale commits** — if the PR has new pushes after your verification, your verdict may be wrong. The `Verified-on:` line documents the SHA; if the PR moves, request re-verification.

## When to switch to feedback path

If you cannot verify (PR has unresolvable issues unrelated to AC, e.g., test infrastructure broken, environment unavailable), don't post a misleading verdict. Switch to `workflow/feedback.md`. Examples:

- The PR doesn't actually link to the issue (Refs: missing)
- The implementer's self-test record is missing or inconsistent
- The PR's CI is red on infrastructure issues you can't diagnose
- Multiple PRs claim to address the same issue

Mode C with category `cannot-verify` and let arch decide.
