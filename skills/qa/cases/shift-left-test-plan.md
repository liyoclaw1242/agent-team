# Case — Shift-Left Test Plan

The most distinctive QA workflow. arch-shape decomposed a parent into multiple tasks, including this `agent:qa` task tagged `<!-- intake-kind: test-plan -->`. The implementer tasks (FE / BE) have `<!-- deps: #THIS_QA_ISSUE -->`, so they wait until the plan is published.

## Worked example

Parent #142 is a customer cancellation flow. arch-shape decomposed:

```
#142 (parent)
├─ #143 [BE]    Cancellation endpoint with effective-date computation
├─ #144 [FE]    Cancellation confirmation modal      (deps: #143, #145)
├─ #145 [QA]    Shift-left test plan                  (intake-kind: test-plan)
└─ #146 [QA]    Post-impl verification                (intake-kind: verify, deps: PR from #143 + #144)
```

You claim #145.

## Phase 1 — Read

Required reads:

```bash
# Parent
gh issue view 142

# Sibling implementer tasks
gh issue view 143
gh issue view 144

# Glossary + relevant context
cat arch-ddd/glossary.md | grep -i "cancel\|cargo"
cat arch-ddd/bounded-contexts/booking.md
cat arch-ddd/domain-stories/book-and-ship.md
```

Notes from reading:
- Parent's AC mention: cancel button, confirmation modal, effective date, success/failure UX
- BE #143 hasn't published its contract yet (typical at this stage; #143's QA task is your dep blocker if anything)
- FE #144 has 6 AC items
- Glossary uses "Cancellation" (capital C); test names should use this term

## Phase 2 — Compose the plan

Create `/tmp/test-plan-145.md`:

```markdown
## Test plan (defined by QA, used by implementers)

### AC-to-test mapping

| AC | From issue | Test name | Test type |
|----|-----------|-----------|-----------|
| Cancel button visible on subscription card | #144 | TestCancelButton_Renders_OnPaidSubscription | component |
| Cancel button hidden for free plans | #144 | TestCancelButton_Hidden_OnFreePlan | component |
| Click opens confirmation modal | #144 | TestCancelModal_Opens_OnButtonClick | component |
| Modal shows effective date from API | #144 | TestCancelModal_DisplaysEffectiveDate | component |
| Confirm calls API with correct payload | #144 | TestCancelModal_PostsToCorrectEndpoint | integration |
| Successful cancel closes modal + refreshes parent | #142 | TestCancellation_E2E_HappyPath | e2e |
| 404 path: subscription not found | #143 | TestCancel_404_NotFound | integration (BE) |
| 409 path: already cancelled | #143 | TestCancel_409_AlreadyCancelled | integration (BE) |
| Effective date matches plan billing cycle | #143 | TestCancel_ComputesEffectiveDate | unit (BE) |
| Side effect: CargoCancelledEvent published | #143 | TestCancel_PublishesEvent | integration (BE) |
| Loading state during request | #144 | TestCancelModal_LoadingState | component |
| ESC dismisses without action | #144 | TestCancelModal_ESC_DismissesWithoutAction | component |

### Edge cases beyond AC

- **Concurrency**: two browser tabs cancelling the same subscription. First should succeed (200), second should get 409. Test name: `TestCancellation_Concurrent_OneSucceedsOneConflicts`.
- **Network failure during request**: connection drops mid-POST. Modal should re-enable, error should be shown, no partial state. Test name: `TestCancelModal_NetworkFailure_ReEnables`.
- **Refresh during action**: user navigates away mid-modal. No half-completed state. (Mostly a manual check; no automated test feasible.)
- **Authorization**: user A trying to cancel user B's subscription. Should get 404 (not 403). Test name: `TestCancel_404_WhenNotOwner`.

### Out of scope

- **Refund handling**: parent #142 explicitly excluded refunds. Test plan does not cover refund computation, refund display, or refund processing.
- **Mobile cancellation**: separate mobile flow not in this parent. Mobile-specific test plan would be filed separately.
- **Bulk cancellation**: not in this parent; tracked separately at #200.
- **Performance**: single-cancel performance is not stress-tested; we'll watch metrics post-launch.

### Verification approach

- **Unit + component**: implementers add per their TDD cycle; CI runs them
- **Integration**: BE integration tests run in CI; FE integration tests run via Playwright on PR preview deployment
- **E2E**: TestCancellation_E2E_HappyPath runs against the PR's preview environment
- **Contract**: BE's contract block (in #143's body) is cross-checked against actual handler routes via `validate/contract.sh`
- **Manual (post-impl, by QA)**: 
  - Click cancellation flow on staging with paid subscription — happy path
  - Trigger 409 by attempting to cancel an already-cancelled subscription
  - Trigger 404 by trying to cancel another user's subscription (use admin tooling)
  - Verify on Datadog: `cargo.cancellation.completed` metric increments
- **A11y**: axe scan on staging; tab order verified manually; screen reader smoke test

### Notes for implementers

- The 12 mapped tests above are the minimum viable coverage. Implementers may add more (e.g., for internal helper functions); these named tests are what QA verify-mode will look for explicitly.
- Test names should be exactly as listed (or document deviations in PR description). The post-impl QA task (#146) will look for these names.
- Test data: use the existing test fixture for paid subscriptions (`fixtures.PaidSubscription`); for the 409 case, set up via `fixtures.AlreadyCancelledSubscription` (may need to be added).
```

## Phase 3 — Publish

```bash
bash actions/publish-test-plan.sh \
  --issue 145 \
  --plan-file /tmp/test-plan-145.md
```

The plan goes into the issue body, between markers. FE and BE can read it.

## Phase 4 — Self-test

```markdown
# Self-test record — issue #145

## Acceptance criteria
- [x] Plan covers all 12 AC from #142 + siblings #143/#144
  - Verified: 12 rows in the AC-to-test table; each AC has at least one test name
- [x] Edge cases listed (4 added beyond AC)
  - Verified: concurrency, network failure, refresh, authz
- [x] Out-of-scope explicit (4 items)
  - Verified: refunds, mobile, bulk, performance
- [x] Verification approach covers all relevant tooling
  - Verified: unit, component, integration, e2e, contract, manual, a11y
- [x] Glossary alignment (test names use Cancellation, EffectiveDate)
  - Verified: grepped the plan; no off-glossary terms

## Plan published in issue body
URL: ...

## Ready for review: yes
```

## Phase 5 — Deliver

```bash
bash actions/deliver.sh \
  --issue 145 \
  --self-test /tmp/self-test-issue-145.md \
  --mode test-plan
```

The action:
- Verifies the gate
- Closes #145 (status:done)
- Sibling tasks #143/#144 had `<!-- deps: #145 -->`; `scan-unblock.sh` will move them to `status:ready`

## Anti-patterns specific to shift-left

- **Plan that mirrors AC verbatim** — no value added. The plan must add: test names, edge cases, out-of-scope, verification approach.
- **"Implementers will figure out the tests"** — that's not shift-left. The whole point is that you remove the burden of test design from implementers.
- **Test names invented by you that don't match codebase conventions** — names should follow the project's test naming style. Check existing tests for the pattern.
- **Including timing estimates ("E2E test should run in <30s")** — performance constraints belong in AC, not test plans. The plan describes WHAT to test, not how fast.

## When you'd do this differently

- **Greenfield feature with no parallel implementer tasks**: there's no implementer to wait. Just deliver the plan; the next pickup (which will be by an implementer) will read it as part of their reading phase.
- **Bug fix with single AC**: shift-left for a one-AC bug is overkill. Usually arch-shape doesn't decompose bug fixes with a separate QA task; the implementer's TDD covers the bug's regression test.
- **Design-heavy task**: the plan should reference Design's spec heavily; some AC ("matches Design spec") are inherently visual and verified manually rather than via automated tests.
