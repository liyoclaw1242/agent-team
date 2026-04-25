# Case — Internal Refactor (preserving public contract)

Sometimes the task is to refactor BE internals while keeping the external contract identical. Different shape from feature work — TDD still applies but the assertion is "behaviour unchanged".

## Worked example

Task #220:

```markdown
[BE] Refactor: extract payment-cycle logic from BillingService

## Acceptance criteria
- Move the cycle-end computation out of BillingService into a dedicated
  PaymentCycle module
- BillingService delegates to PaymentCycle for the relevant computations
- All existing endpoints remain functionally identical (same behaviour, same shapes)
- Test coverage of cycle logic does not decrease
- Performance characteristics within 5% of baseline
```

## Phase 1 — Read

The task is mechanical: extract code, preserve behaviour. AC explicitly say "functionally identical".

This is the kind of task where Mode C is rare — there's no spec/codebase conflict; you're moving code around.

## Phase 2 — No new contract to publish

This task doesn't add or change endpoints. No `## Contract` block needed.

If the refactor would inadvertently change a contract (e.g., the new module rounds differently due to different float handling), that's a violation of the AC; the contract must stay identical.

## Phase 3 — Tests first (with twist)

The refactor's TDD shape is different from feature work:

1. Verify existing tests run green on current main (before any change)
2. If existing test coverage is weak, **add tests first** to capture current behaviour
3. Refactor: move code; ensure tests still green
4. Add tests for the new module's interface (the dedicated PaymentCycle module's public methods)

The "add tests for current behaviour first" step is critical for refactors. Without it:

- You refactor; tests pass; you ship
- Later, a behaviour change is introduced; tests pass because the regression isn't covered
- Bug ships

The refactor PR is your chance to lock down current behaviour with tests before moving things around.

## Phase 4 — Implement carefully

Refactor in the smallest steps your test suite can validate:

1. Create the new PaymentCycle module with the lifted-out logic
2. BillingService imports and delegates
3. Verify all tests still green
4. Remove the duplicate logic from BillingService

Each step is a commit. The first step doesn't break anything (PaymentCycle just exists, BillingService still has its own logic). The second commits the delegation. The third removes the duplicate. Reviewers can follow.

## Phase 5 — Performance verification

The AC mentions "within 5% of baseline" performance. Before/after benchmarks:

```go
// Before refactor (from main)
go test -bench=BenchmarkComputeCycleEnd -benchmem ./billing/...
// Save output

// After refactor
go test -bench=BenchmarkComputeCycleEnd -benchmem ./billing/...
// Compare
```

If performance regresses >5%, that's a bug. Investigate before delivering.

## Phase 6 — Self-test

The self-test record looks different from feature work:

```markdown
# Self-test record — issue #220

## Acceptance criteria
- [x] AC #1: cycle-end computation extracted to PaymentCycle module
  - Verified: src/billing/cycle.go (new file) contains the logic; BillingService imports it
- [x] AC #2: BillingService delegates correctly
  - Verified: BillingService.computeCycleEnd is now a thin wrapper calling PaymentCycle.End
- [x] AC #3: existing endpoints functionally identical
  - Verified: full integration test suite passes (132 tests, all green); no behavioural changes observed in manual test of /billing endpoints
- [x] AC #4: cycle-logic test coverage not decreased
  - Verified: pre-refactor cycle logic was tested by 8 tests, indirectly through BillingService. Post-refactor, the same 8 tests still pass + 4 new direct tests of PaymentCycle. Coverage of cycle.go: 92%.
- [x] AC #5: performance within 5%
  - Verified: BenchmarkComputeCycleEnd before: 1430 ns/op; after: 1485 ns/op (+3.8%). Within tolerance.

## Validators
- lint: pass
- test (with -race -cover): pass; total coverage 88% (was 87%)
- security: pass
- contract: N/A (no contract change)

## Refactor-specific verification
- All callers of BillingService.computeCycleEnd updated: yes (only one caller)
- No public API of BillingService changed: confirmed by inspecting the diff
- New module's API: PaymentCycle.End(plan, asOf) — clean, no leaked internals

## Ready for review: yes
```

Note the explicit refactor section at the bottom. Refactor PRs benefit from explicit "what didn't change" notes — reviewers focus on the delta but need confidence about preservation.

## Common refactor pitfalls

### Pitfall: subtle behaviour change

You move code; in the process, you "clean up" a weird-looking line that was actually load-bearing. Behaviour now differs.

This is why "tests first" is critical for refactors. The tests should catch it. If tests don't catch it but you suspect, expand tests until they do (then refactor against the broader test net).

### Pitfall: changed timezone / time handling

Cycle computation often involves time. Refactoring time-handling code is risky:

- `time.Now()` in tests vs explicit clock injection
- UTC vs local time
- Daylight saving transitions

Be especially cautious; add tests for the edge cases (e.g., DST transitions, timezone changes).

### Pitfall: changed concurrency semantics

If the original code held a lock that the new code doesn't (or vice versa), behaviour can differ under load. `go test -race` catches some of this; load testing catches more. For pure refactors, lock semantics should be identical.

### Pitfall: lost error handling nuance

The original code might have had `if err != nil { ... } else if x { ... }` and the new code has `if err != nil { return err }`. If `else if x` was load-bearing, that's a behaviour change.

## Anti-patterns

- **Refactor + feature in same PR** — they should be separate. The refactor establishes new structure; the feature adds new behaviour. Mixed PRs are hard to review and roll back.
- **Refactor without strengthening tests first** — tests-locked-down baseline is what makes refactor safe. Skipping it = silently shipping behaviour changes.
- **"Cleaning up" while you're in there** — small adjacent cleanups inflate the diff. File a separate refactor task for them.
- **Performance regression accepted "because the new code is cleaner"** — clean code that's slower than dirty code that worked is a sideways move. The AC said within 5%; honor it.
