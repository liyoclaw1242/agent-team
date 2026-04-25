# Rule — Self-Test Gate

QA's self-test gate is mode-dependent.

## Shift-left mode

Before delivering the test plan, the self-test record verifies:

- The plan covers every AC item from the parent (matrix mapping shows ≥1 test per AC)
- Edge cases are listed (the plan adds value beyond rephrasing AC)
- Out-of-scope is explicit
- Verification approach documents what tooling will run

`actions/deliver.sh --mode test-plan` checks:
1. `/tmp/self-test-issue-{N}.md` exists
2. The issue body has the test plan block (between `<!-- qa-test-plan-begin -->` and `<!-- qa-test-plan-end -->`)
3. The plan's test name table is non-empty
4. Self-test contains "## Ready for review: yes"

## Verify mode

Before posting the verdict, the self-test record verifies:

- All validators ran on the PR's HEAD commit and pass (or the verdict is FAIL on validator failure)
- Every AC was walked
- Verdict is composed and matches format
- Triage is set if FAIL

`actions/post-verdict.sh` checks:
1. `/tmp/self-test-issue-{N}.md` exists
2. The verdict file's first line matches the format regex
3. `triage:` line is present and valid
4. `Verified-on:` SHA is present
5. Self-test contains "## Ready for review: yes"

## Both modes share

- Self-test record is at `/tmp/self-test-issue-{N}.md`
- Lying about verification fails the spirit (and downstream consumers will catch it)
- "## Ready for review: yes" line is the explicit commitment

## What the self-test record looks like

### Shift-left mode

```markdown
# Self-test record — issue #145 (test plan for #142)

## Acceptance criteria for this QA task
- [x] Test plan covers all 12 AC from parent #142 plus siblings #143/#144
  - Verified: walked the AC list; each maps to ≥1 test name in the published plan
- [x] Edge cases listed (4 added beyond AC: concurrency, network failure, refresh-during-action, ESC dismissal)
- [x] Out-of-scope clear (3 items)
- [x] Verification approach: covers unit + component + e2e + manual + contract checks
- [x] Plan is glossary-aligned (test names use cancellation, effectiveDate, etc. per arch-ddd)

## Plan published
The plan is now in this issue's body (see <!-- qa-test-plan-begin --> block).
URL: ...

## Ready for review: yes
```

### Verify mode

```markdown
# Self-test record — issue #146 (verify of PR #501)

## Acceptance criteria for this QA task
- [x] Validators ran on PR HEAD (commit abc1234)
  - Verified: lint, typecheck, test, a11y all pass
- [x] All AC from parent #142 walked
  - Verified: 5 AC, all marked ✓ in verdict
- [x] Verdict composed correctly
  - Verified: format check passed; triage: none (PASS)
- [x] Manual verification on staging
  - Verified: clicked through happy path + 409 path; both observed correctly

## Verdict
PASS — see verdict comment on PR #501

## Ready for review: yes
```

## When the gate refuses

If self-test gate fails:

- The deliver / post-verdict action exits with a clear error
- No comment / verdict is posted
- The issue stays at `agent:qa + status:in-progress` (you've claimed but not delivered)

You either fix the gap or escalate (Mode C feedback if the gap is structural; arch-judgment if it's a system bug).

## Anti-patterns

(All of fe/be's apply, plus QA-specific:)

- **Posting verdict before self-test is complete** — the gate prevents this. Don't try.
- **Self-test that just paraphrases the verdict** — adds no value. The self-test should describe HOW you verified (steps, environments, evidence), not WHAT the verdict says.
- **"## Ready for review: yes" without actually being ready** — if you've found yourself wanting to add this line while doubts remain, those doubts are signal, not noise.
