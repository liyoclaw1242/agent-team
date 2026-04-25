# Workflow — Test Plan (shift-left mode)

Activated when issue body has `<!-- intake-kind: test-plan -->`. The QA task exists alongside FE/BE/Design tasks under the same parent. Goal: write a test plan in the issue body BEFORE implementation begins, so implementers know exactly what "done" looks like.

This is the parallel of BE's `publish-contract.sh` Phase 2 — both are pre-implementation artefacts that travel with the issue.

## Phase 1 — Read the parent

Required:

1. The QA issue body in full
2. The parent issue body (`<!-- parent: #N -->`) — this is the source of truth for what's being built
3. Sibling implementer tasks: their AC, their (possibly-not-yet-published) contracts
4. `arch-ddd/glossary.md` — test names will use these terms
5. `arch-ddd/domain-stories/{flow}.md` — if a specific flow is in scope, its happy path is the spine of the test plan

After reading, you should be able to state in one sentence: "to verify this feature, the test plan must demonstrate X, Y, Z."

## Phase 2 — Compose the test plan

The test plan has four parts:

### Part A: AC-to-test mapping

For each AC item in the parent / sibling tasks, write the test name and brief description. This is the spine.

```markdown
| AC item | Test name | Test type |
|---------|-----------|-----------|
| Cancel button shows loading state | TestCancelButton_LoadingDuringRequest | component |
| Modal opens on click | TestCancelModal_OpensOnButtonClick | component |
| Confirmation calls API and refreshes parent | TestCancel_E2E_HappyPath | e2e |
| Cancel can fail with 409 | TestCancel_E2E_AlreadyCancelled | e2e |
```

Test types:
- `unit` — single function / pure logic
- `component` — UI component in isolation
- `integration` — multiple modules together (BE: handler+DB; FE: page+routing)
- `e2e` — full user flow through the system
- `contract` — API shape/behaviour vs published contract
- `manual` — explicit human verification step

Every AC must map to at least one test. Multiple ACs can map to one test if the test naturally exercises them together.

### Part B: Edge cases not in AC

Things AC didn't list explicitly but the flow obviously requires:

```markdown
- Cancel button is disabled when subscription is already cancelled (state precondition)
- Cancel modal handles network failure gracefully (no AC mentions this; UX standard)
- Concurrent cancellations from two tabs result in one success and one 409 (concurrency)
```

These are signals to implementers about hidden requirements. They're also test names in the plan.

### Part C: Out of scope

What the test plan explicitly does NOT cover, to prevent scope creep:

```markdown
- Refund handling (separate flow; per parent's "out of scope" section)
- Cancellation via mobile app (mobile-specific test plan filed separately at #150)
- Performance under load >1000 concurrent cancellations (performance test plan #151)
```

This protects you from QA-side scope creep ("while I'm verifying I'll just check X too") and clarifies for arch.

### Part D: Verification approach

How verification will happen post-implementation:

```markdown
- Unit + component + integration tests run in CI
- E2E tests run on PR's preview deployment via Playwright
- Manual verification: I'll manually click through happy + 409 paths on staging
- Contract verification: BE's OpenAPI spec compared to actual handler routes
```

This sets expectations: implementers know what tooling will run, what manual steps you'll take, what coverage you'll measure.

## Phase 3 — Publish

Use `actions/publish-test-plan.sh` to write the plan into the issue body atomically:

```bash
bash actions/publish-test-plan.sh \
  --issue $ISSUE_N \
  --plan-file /tmp/test-plan-$ISSUE_N.md
```

The plan goes between `<!-- qa-test-plan-begin -->` and `<!-- qa-test-plan-end -->` markers, like BE's contract block. Re-running replaces the existing plan rather than duplicating.

## Phase 4 — Self-test

Even shift-left mode produces a self-test record:

```markdown
# Self-test record — issue #145

## Acceptance criteria
- [x] Test plan covers every AC item from parent #142 and siblings #143, #144
  - Verified: walked through all 12 AC items; each maps to ≥1 test name
- [x] Edge cases identified
  - Verified: 4 listed including concurrency case
- [x] Out-of-scope explicitly stated
  - Verified: 3 items excluded with rationale
- [x] Verification approach documented
  - Verified: covers unit + component + e2e + manual + contract checks

## Test plan content
The plan is now in this issue's body via publish-test-plan.sh.
Parent issue can verify the plan satisfies the AC coverage requirement.

## Ready for review: yes
```

## Phase 5 — Deliver

In shift-left mode, "deliver" means routing the issue to status:done — the plan is published and ready for sibling implementers to consume:

```bash
bash actions/deliver.sh \
  --issue $ISSUE_N \
  --self-test /tmp/self-test-issue-$ISSUE_N.md \
  --mode test-plan
```

This action:
1. Verifies self-test record (gate as usual)
2. Verifies the issue body has the test plan block (sanity check)
3. Routes the issue to `status:done` (no PR involved)
4. The implementing siblings (`<!-- deps: #THIS_ISSUE -->`) automatically unblock when this closes

After this, the QA issue is closed. A separate post-impl QA task (different issue) will be created when the implementer PRs are open.

## Anti-patterns

- **Writing the plan after implementation** — defeats the parallelism. Implementers can't depend on a plan that doesn't exist yet.
- **Plan that just lists AC verbatim** — adds zero value. The plan must add: test names, edge cases, out-of-scope, verification approach.
- **Including "TBD" in the plan** — anything TBD means the plan isn't ready. Either you can specify it or you need Mode C feedback to clarify the AC.
- **Plan that prescribes test framework / library choices** — same spec discipline as arch-shape; outcome over implementation. "covered by component test" not "covered by Jest with React Testing Library".
- **Plan with no edge cases** — if every test is happy-path, you've under-thought it. Cancel cases, concurrency, network failures, partial state.

## When to switch to feedback path

If after Phase 1 reading you cannot write the plan because:
- AC are too vague to derive test names from
- Sibling tasks haven't published their contracts (so you don't know what to test against)
- The parent's outcome is internally contradictory

Switch to `workflow/feedback.md`. Don't write a plan against ambiguity; the result will be a plan implementers can't trust.
