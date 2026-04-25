# Workflow — Implement (TDD)

BE workflow is shaped around TDD. The phases enforce the discipline structurally — you can't skip ahead because the deliver gate looks for the test commits.

## Phase 1 — Read spec

Required:
1. The issue body in full
2. The parent issue body (via `<!-- parent: #N -->`)
3. Any `<!-- deps: -->` issues' AC
4. The relevant `arch-ddd/bounded-contexts/{ctx}.md` — BE work always happens within a context
5. `arch-ddd/service-chain.mermaid` — verify any cross-service interaction the spec implies is documented; if not, that's drift to flag
6. AC checklist

Conditional:
7. `arch-ddd/domain-stories/{flow}.md` if a specific flow is touched
8. ADRs (under `docs/adr/`) referenced in the spec

After reading: state in one sentence what the change is, in domain language. "I will add the cancellation endpoint to the Booking context, which subscribes to current cargo state and emits CargoCancelledEvent on success." If you can't, switch to `workflow/feedback.md`.

## Phase 2 — Author the contract (if FE-facing)

If FE has a sibling task with `<!-- deps: #THIS_ISSUE -->`, FE is waiting on you to define the API contract. Write it now, BEFORE writing any code.

The contract goes into the **issue body** via `actions/publish-contract.sh`:

```bash
bash actions/publish-contract.sh \
  --issue $ISSUE_N \
  --contract-file /tmp/contract-$ISSUE_N.md
```

Where `contract-$ISSUE_N.md` is:

```markdown
## Contract (defined by BE, consumed by FE)

POST /billing/subscriptions/{id}/cancel
- Auth: required (subscription must belong to authenticated user)
- Request body: empty
- Success: 200 {effectiveDate: ISO8601}
- Errors:
  - 404 if subscription not found or doesn't belong to user
  - 409 if already cancelled
- Side effects: publishes CargoCancelledEvent (per service-chain)
```

The action appends this section to the issue body in a designated block (idempotent — re-running updates rather than duplicating). Once published, **FE can start work**. The contract is now binding for you.

**Why now, not after implementation?** Because FE is waiting. Publishing the contract upfront unblocks them; they can mock and stub their UI against it while you write tests + impl. This is the parallelism the system is designed for.

If you're tempted to "design as I code" and publish the contract after, you've inverted the dependency: FE will be late starting, and changes you make to the contract during implementation will be silent (nobody sees them) until FE breaks.

## Phase 3 — Tests first

Per the TDD iron law:

1. Write one failing test per AC item, mapping each to a test name
2. Confirm tests fail (compile, run, see red) — this proves they're real tests
3. Commit: `test(billing): add tests for cancellation endpoint\n\nRefs: #N`

Test scope:
- Unit tests for new functions / methods
- Integration tests (with a real DB or a recorded in-memory DB) for endpoint flows
- Contract tests: the published contract from Phase 2 should map 1:1 to integration tests

Don't skip the "see red" step. Tests that pass on the first run before any implementation are usually testing nothing.

## Phase 4 — Implement to green

Make tests pass, one at a time. Refactor as needed but only against green:

1. Write minimal implementation to make one test pass
2. Run tests — that one passes, others remain red
3. Commit: `feat(billing): cancellation endpoint persists effective date\n\nRefs: #N`
4. Move to the next test

Resist the temptation to "implement everything then run tests". The TDD rhythm is **red → green → refactor**, repeated per test.

## Phase 5 — Refactor + non-functional

Once all tests are green:

- Refactor for clarity. Tests guard against regression.
- Add benchmarks for any AC mentioning performance characteristics
- Verify race conditions: `go test -race` (or equivalent)
- Verify concurrency safety if any goroutines / threads / async tasks introduced

Never refactor against red. If a refactor introduces a failure, you've introduced a bug; fix before moving on.

## Phase 6 — Self-test

Write `/tmp/self-test-issue-{N}.md`:

```markdown
# Self-test record — issue #143

## Acceptance criteria
- [x] AC #1: POST /billing/subscriptions/{id}/cancel exists and routes correctly
  - Verified: integration test `TestCancelEndpoint_Routes` passes
- [x] AC #2: returns 200 with effectiveDate on success
  - Verified: `TestCancel_Success_ReturnsEffectiveDate`
- [x] AC #3: returns 404 if subscription not found
  - Verified: `TestCancel_404_WhenNotFound`
- [x] AC #4: returns 409 if already cancelled
  - Verified: `TestCancel_409_WhenAlreadyCancelled`
- [x] AC #5: publishes CargoCancelledEvent
  - Verified: `TestCancel_PublishesEvent` checks event bus

## Contract conformance
The published contract on this issue body matches:
- Path: POST /billing/subscriptions/{id}/cancel ✓
- Auth required ✓
- Request body empty ✓
- 200 + {effectiveDate} ✓
- 404 / 409 cases match ✓

## Validators
- lint (go vet, staticcheck): pass
- test (go test -race -cover): pass; coverage 87%
- security (sqlc-aware grep + govulncheck): pass
- contract (handler-vs-doc diff): pass

## Manual verification
- Tested locally with `curl -X POST localhost:8080/billing/subscriptions/test-id/cancel`
  with a valid auth token; got 200 + effectiveDate
- Tested 404 path with non-existent ID; got 404 with sensible body
- Tested 409 path by calling twice in a row; second call returned 409

## Ready for review: yes
```

## Phase 7 — Deliver

```bash
bash actions/deliver.sh \
  --issue $ISSUE_N \
  --self-test /tmp/self-test-issue-$ISSUE_N.md \
  --pr-title "feat(billing): cancellation endpoint" \
  --pr-body-file /tmp/pr-body.md
```

The deliver action's gate also checks:

- The branch has at least one commit with message starting with `test(`. (TDD evidence)
- The contract block in the issue body, if present, matches what the handler exposes (basic sanity)

If TDD evidence is missing, the gate refuses. You can't open a PR without a test commit.

## Anti-patterns

- **Implementing first, tests later** — TDD iron law violation. The gate catches it; don't try.
- **Publishing the contract after implementation** — defeats Phase 2's parallelism point. FE is sitting blocked while you code.
- **Committing tests + implementation in the same commit** — loses the TDD rhythm visibility. Reviewers want to see "tests added, then implementation makes them pass".
- **Skipping `-race`** — Go's race detector catches data races that elude code review. Cheap; always run.
- **"Refactoring" while still red** — that's not refactor, that's continued debugging in disguise.
