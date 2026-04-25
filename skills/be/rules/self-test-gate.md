# Rule — Self-Test Gate

Mostly identical to FE's self-test-gate rule, with one BE-specific addition: the gate also verifies TDD evidence.

## What the gate checks

`actions/deliver.sh` runs these checks before pushing:

1. File exists: `/tmp/self-test-issue-{N}.md`
2. File contains a `## Acceptance criteria` section
3. Every line starting with `- [` in that section is `- [x]`
4. File contains a `## Ready for review: yes` line
5. **BE-specific**: the branch has at least one commit whose message starts with `test(`

Any failure → no PR opened.

## Why TDD evidence in the gate

The TDD iron law is impossible to enforce purely by inspecting the agent's reasoning. The agent could lie about doing TDD. But:

- If TDD was done, there's at least one `test(...)` commit in the branch
- If only `feat(...)` commits exist, no test commit landed before implementation
- The gate's check is mechanical and unforgeable: `git log --grep "^test(" | wc -l > 0`

A determined liar could write a fake `test(...)` commit with no actual test in it. That's caught downstream by:

- `validate/test.sh` runs the test suite; empty test bodies cause failures or coverage gaps
- QA verifies tests cover the AC

The gate is a commitment ceremony like FE's, plus this mechanical TDD evidence check.

## What "test commit" means

A commit qualifies as a test commit if:

- Commit message starts with `test(scope): ...` (per `_shared/rules/git.md`)
- The commit's diff includes at least one new test file or new test case in an existing file

The deliver action's gate checks the message. The "actually contains a test" check is downstream (validate/test.sh refuses if test count didn't go up).

## Conformance checklist in self-test

The BE self-test record has a `## Contract conformance` section in addition to AC:

```markdown
## Contract conformance
The published contract on this issue body matches:
- Path: POST /billing/subscriptions/{id}/cancel ✓
- Auth: Bearer JWT, validated in middleware ✓
- 200 + {effectiveDate: ISO8601} ✓
- 404 / 409 cases per spec ✓
```

This section is required when the issue's body has a `## Contract` block. The deliver gate does NOT enforce this section's presence (would require parsing the issue body); QA does at review time.

## Coverage line

The self-test record includes a coverage line:

```markdown
- test (go test -race -cover): pass; coverage 87%
```

Coverage below the project's threshold (default 80%) requires explicit rationale in self-test, in the same section:

```markdown
- test (go test -race -cover): pass; coverage 72%
  Coverage rationale: this PR is mostly wiring (route registration + middleware
  attachment); business logic is fully covered. The lower number reflects
  uncovered route table entries that don't have meaningful logic to test.
```

If coverage is below threshold AND no rationale appears in self-test, QA returns FAIL.

## Common AC verification methods (BE)

| AC type | How to verify |
|---------|---------------|
| Endpoint exists | Integration test for routing |
| Returns specific shape | Integration test asserts response body |
| Returns specific status | Integration test asserts status code |
| Side effect (event published) | Test inspects event bus / mock |
| Database state changed | Test asserts DB state after call |
| Authorization enforced | Test calls with wrong user; expects 404 |
| Idempotency | Test calls twice; asserts second is no-op or idempotent |
| Performance | Benchmark + assertion against a threshold |

For each AC line, the self-test "Verified:" line cites the test name(s) that cover it.

## Anti-patterns

(All of FE's apply, plus BE-specific:)

- **Fake test commits** — committing an empty test file just to satisfy the gate. Caught downstream when validators run.
- **Coverage manipulation** — adding tests for getters/setters to inflate numbers. Coverage is a signal, not a goal; gaming it is dishonest.
- **Skipping `-race`** — `go test ./...` without `-race` is faster but misses concurrency bugs. The self-test mentions race because the gate doesn't check.
- **Marking contract conformance ✓ when it isn't** — `effectiveDate` in contract but `effectiveAt` in handler. QA catches; FAIL.
