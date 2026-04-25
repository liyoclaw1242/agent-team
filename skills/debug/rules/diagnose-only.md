# Rule — Diagnose Only

Debug never writes the fix. The output is always a fix issue tagged for the appropriate role; the role's regular workflow handles implementation.

## Why split

Two reasons:

### 1. Specialisation

Debug is good at: reproducing, hypothesizing, narrowing, confirming. These are diagnostic skills.

Implementation is good at: writing tests, satisfying AC, integrating with adjacent code, refactoring, code review collaboration. These are construction skills.

Mixing the two in one specialist creates a generalist whose investigation is rushed (because they want to get to building) and whose implementation is shallow (because they cut corners on edge cases the original investigation didn't surface).

### 2. Audit trail

The bug → fix split makes both halves visible in their own issues:

- The bug issue keeps the investigation log, the repro, the root cause
- The fix issue tracks the implementation work, the QA, the merge

If a fix doesn't actually fix the bug (turns out the root cause was wrong, or the fix didn't address it correctly), the bug stays open and the next debug pickup has the previous investigation to consult. This is harder to do cleanly when one issue mixes both phases.

## What "diagnose only" looks like in the report

The root-cause report's "Suggested approach" section is **high-level only**:

GOOD:
> Suggested approach: add a null check for `currentPlan` in the `Cancel` component and disable the cancel button when null. The implementer should also consider whether other components on the same page have the same vulnerability.

BAD:
> Suggested approach: in `src/pages/billing/CancelDialog.tsx` line 42, change `onClick={handleCancel}` to `onClick={currentPlan ? handleCancel : undefined}` and add `disabled={!currentPlan}` to the button props. Also import the `useCurrentPlan` hook from `@/lib/billing` if it isn't already.

The bad version is implementation. The implementer (FE in this example) should write that code, with their judgment about hook patterns, prop shapes, and whether to refactor.

## When you're tempted to write the fix

If you find yourself wanting to write specific code in the report, ask:

- Is this needed to communicate the root cause? → leave it as a code reference (file:line citation), not a fix
- Is this needed to ensure the fixer doesn't pick the wrong approach? → the spec discipline rule applies (see `arch-shape/rules/spec-discipline.md`); state outcomes, not implementation
- Is this just because it would be faster than handing off? → don't. The handoff IS the system.

## What about trivial fixes?

Some bugs have one obvious one-line fix. Even then:

- Debug confirms root cause, files the fix issue
- Fix issue says "obvious one-line fix; AC: null check at the cited line, no regression in adjacent components"
- FE picks it up, makes the change, ships in minutes

The ceremony is small (filing one issue) and the audit trail is preserved. Don't shortcut.

## Exception: investigation tooling fixes

If the investigation revealed that the codebase needs better instrumentation (a missing log line, a missing trace, a missing metric), debug can file that as an OPS task. This isn't fixing the bug — it's improving the tools that future debug invocations use.

The tooling task is filed via `actions/file-fix.sh` with `--owning-role ops` and a `--report-file` that explains it's an investigation aid, not a bug fix. The bug stays open with deps on the tooling task.

## Co-existence: debug-recommended fixes vs implementer's choices

The fix issue's spec is a starting point for the implementer, not a contract. The implementer is free to:

- Choose a different approach if they see a better one
- Refactor adjacent code while they're in there (within reason)
- Push back via Mode C if the fix proposal is unimplementable

If the implementer's pushback is "this isn't actually the fix, the real fix is X", that's valuable. arch-feedback handles it; if it reveals debug got the diagnosis wrong, the bug routes back to debug for re-investigation (rare, but happens).

## Anti-pattern: "while I'm investigating, I'll just fix it"

Don't. Even if you're absolutely sure of the fix, file the fix issue. The system's invariants depend on the split.

If the bug is Sev 1 and immediate mitigation is needed, that's a separate OPS task for mitigation (e.g., feature flag), not a debug-implemented fix.
