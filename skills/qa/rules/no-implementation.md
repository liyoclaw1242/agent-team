# Rule — No Implementation

QA writes test plans and verifies PRs. QA does not write production code, even when QA can clearly see what the fix should be.

## Why

Same reason debug doesn't write fixes: separation of concerns produces clearer audit trails and better outcomes.

If QA writes the fix:
- The fix is filed as a "QA fix" but really it's an FE/BE change shipped under QA's identity
- Future readers can't tell who actually authored what
- The implementer who *would* have done the fix loses the chance to address it (and may make a similar mistake again)
- QA's verdict becomes self-serving — they verified their own fix

The discipline keeps QA neutral. QA verifies what others built; QA doesn't compete with the implementer roles.

## What QA writes

In **shift-left** mode:
- Test plans (in issue body via `publish-test-plan.sh`)
- Test names and descriptions to guide implementers
- Edge case lists
- Out-of-scope statements

In **verify** mode:
- Verdict comments on PRs
- Mode C feedback when verification is blocked

Neither produces production code. The shift-left plan is a *spec for tests*; implementers write the tests as part of their TDD work.

## What about QA-owned test infrastructure?

There's a legitimate exception: QA-specific tooling that's not part of the production code path:

- E2E test harness (Playwright setup, CI E2E job configuration)
- Synthetic monitoring scripts
- Test data fixtures

These are infrastructure improvements, often filed as separate `agent:ops` or `agent:qa` infra tasks (not as part of a feature verification). They're committed to the repo, but they're outside the production code surface.

Even then, the discipline holds: QA infra changes go through their own task lifecycle, not snuck into a verify-mode QA's work.

## What if QA notices a fix mid-verification?

You're verifying a PR, you find a bug, you can clearly see the one-line fix.

The right move:
1. FAIL the verdict (the AC isn't met)
2. In the verdict's evidence, explain what's wrong specifically
3. (Optional) In the `Notes:` section, suggest a possible approach: "I noticed `useModal` is missing the import from `@/lib`; that's likely the fix"
4. Triage to the implementer role
5. Don't write the fix yourself

The implementer reads your verdict, sees your suggested approach, and decides whether your suggestion is right. They have more context than you do on the codebase's full picture; sometimes the obvious fix is wrong because of an adjacent constraint.

## What if QA disagrees with how the implementer fixed it after FAIL→fix→re-verify?

Round-trip:
- QA round 1: FAIL with finding F
- Implementer fixes (their judgment of how to address F)
- QA round 2: re-verify the AC

If round 2 still fails (the implementer's fix didn't address F adequately, or addressed it in a way that breaks something else), FAIL again with the new finding.

Don't write the fix to "save time". The cycle exists for a reason.

If the disagreement persists across multiple rounds, that's eventually arch-judgment territory (similar to how round-3 feedback escalates).

## What if QA spots a critical bug outside scope?

You're verifying cancellation flow; while clicking around, you notice a totally unrelated security issue.

Don't expand the verdict's scope. The verdict is about THIS issue's AC.

File the unrelated bug as a separate `intake-kind: bug` issue. It enters the bug pipeline cleanly. Note it in the verdict's `Notes:`:

```
Notes:
- Unrelated to this AC: I noticed during testing that GET /admin/users returns user emails to non-admin authenticated users. Filed as #200. Not blocking this verdict.
```

This keeps the verdict focused while ensuring the bug doesn't get lost.

## Anti-patterns

- **"It's just a one-line change, let me fix it"** — discipline. File the FAIL.
- **Submitting a PR alongside the verdict** — confusing for reviewers; QA's identity now competes with implementer's. The verdict is the work product.
- **Adding tests to the implementer's PR while verifying** — even tests are out of scope mid-verify. If the implementer's tests are insufficient, FAIL with that finding; they add the tests.
- **Coaching the implementer on implementation details in the verdict** — the verdict's job is "PASS or FAIL with what's wrong". Implementation guidance is rarely useful and often condescending.

## Tests added in shift-left vs verify mode

In **shift-left mode**, QA writes the test plan; implementers write the tests as part of their TDD cycle. QA doesn't author the test code.

In **verify mode**, no new tests are added by QA. If the implementer's tests are inadequate (missing coverage, weak assertions), that's a FAIL finding triaged to the implementer.

Some teams have a hybrid pattern where QA agents do write E2E tests post-implementation, separate from unit/integration tests by implementers. That's a project-specific choice; if your team works that way, the rule generalises to "QA doesn't write production code", not "QA writes no code". E2E test code is testing infrastructure, not production.
