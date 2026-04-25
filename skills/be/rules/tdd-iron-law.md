# Rule — TDD Iron Law

**Tests first. Implementation second. Always. No exceptions.**

## Statement

Every BE change is preceded by failing tests. The test commits land before the implementation commits in branch history. The deliver gate verifies this and refuses delivery without TDD evidence.

## Why this is named "iron law"

In real projects, "I'll write the test after I confirm this works" is a constant temptation. The temptation has three sources:

1. The implementation feels fast (a one-liner endpoint), so writing a test first feels like ceremony
2. The exact behaviour isn't pinned down, so writing a test first feels premature
3. Time pressure: the bug is on fire, ship the fix now, write the test later

Each of these is a false economy:

1. The "one-liner" is rarely actually a one-liner; tests-first reveals the edge cases
2. If behaviour isn't pinned, **that's exactly when tests-first helps**, because writing the test forces you to pin behaviour explicitly
3. Tests-after rarely happens. "Later" becomes "never". The bug recurs because the fix wasn't actually verified.

The rule is iron because the soft version of it doesn't survive contact with reality.

## What "tests first" means in commits

The commit graph for any BE feature work looks like:

```
* feat(billing): cancellation handler completes with effective date  (impl)
* test(billing): TestCancel_PublishesEvent for CargoCancelledEvent   (test)
* feat(billing): cancellation event publishing                       (impl)
* test(billing): TestCancel_409_WhenAlreadyCancelled                  (test)
* feat(billing): conflict handling on duplicate cancel               (impl)
* test(billing): TestCancel_404_WhenNotFound                          (test)
* feat(billing): not-found path for cancellation                     (impl)
* test(billing): TestCancel_Success_ReturnsEffectiveDate              (test)
* feat(billing): minimal endpoint scaffold                            (impl)
* test(billing): TestCancelEndpoint_Routes                            (test)
```

Read bottom to top: each `test(...)` commit precedes its corresponding `feat(...)` impl. Tests + impl interleaved per AC.

The deliver gate counts `test(...)` commits and refuses if zero. Stronger versions of the gate could verify each test was actually red before the impl commit (CI rerun on test commit; expect failure), but that's tooling beyond this rule's scope.

## What counts as a test

A test must:

1. **Compile and run** — not commented out, not `t.Skip()`, not in a build-excluded file
2. **Have a clear assertion** — `assert.Equal`, `assert.NoError`, `require.True`, etc. A test with no assertion isn't a test.
3. **Cover a specific AC item** — link it via test name. AC #2 maps to `TestCancel_Success_ReturnsEffectiveDate`.
4. **Initially fail** — before the implementation it tests, the test should be red. The "see red, then green" cycle is what TDD verifies.

Tests that pass on first run before any implementation are usually testing nothing — they tend to assert behaviour that's true vacuously (e.g., `assert.NoError(nil)`).

## What "implementation" means in commits

Implementation commits make currently-red tests green. They must:

1. Not modify other tests (changing tests to pass is anti-TDD; if you discover a test was wrong, that's a separate test commit)
2. Not introduce additional behaviour beyond what the test requires (gold-plating)
3. Pass the test that was previously red

The "minimal implementation" discipline is critical: write the simplest code that makes the test green. Refactor later, in green state.

## Race detector is mandatory

`go test -race ./...` (or equivalent in your language) is part of the test pass. BE work involves goroutines, async tasks, shared state — the race detector catches data races that hand-review misses.

If `-race` flags an issue, that's a real bug. Don't disable; fix.

## Coverage threshold

Project-tunable, but the convention is **80% line coverage on changed files**. Lower than this in a delivered PR triggers a Mode C-style flag (in self-test record, "coverage below threshold; here's why" with a specific exception rationale).

Coverage below 80% with no rationale = self-test gate failure.

## Exceptions to TDD

There are no exceptions to "tests first" for BE feature/bugfix work. There are some exceptions for adjacent activity:

- **Performance benchmarks** can be added after the implementation if the AC is non-functional ("should handle 1000 RPS"). The benchmark codifies the AC; "tests-first" in that context means writing the benchmark before optimising.
- **Migration scripts** for schema changes — the migration itself is run as part of test setup; don't write a "test for the migration" separately
- **Generated code** — e.g., protoc output, sqlc output. The generator's input file (proto, SQL) is what you write; the output is generated. Tests for what consumes the generated code still come first.

These are edge cases. If you're invoking an exception, you should be 90% sure; if uncertain, default to tests-first.

## What if the spec is so vague you can't write tests?

Then the spec is not implementable yet — switch to feedback path. Vague spec is a missing-AC concern; route to arch-feedback.

Don't try to TDD against vagueness; you'll write tests that drift from spec intent and end up with green tests for the wrong thing.

## Anti-patterns

- **"I'll TDD the public function but skip TDD for internal helpers"** — internal helpers benefit from TDD too. The public test catches integration; the internal test catches design errors.
- **Writing one big "happy path" test, getting all green, calling it done** — TDD is per-AC. One AC, one test pair.
- **"The CI will catch coverage; let me skip the coverage check locally"** — false economy. Local coverage takes seconds; CI takes minutes.
- **Writing tests AFTER the impl commit, then squashing** — defeats the auditability TDD provides. The TDD evidence in commit history matters for review.
