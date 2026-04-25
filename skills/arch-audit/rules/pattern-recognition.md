# Rule — Pattern Recognition

The decision "are these findings independent or one underlying problem?" determines whether you produce 1 fix or N fixes. Get this wrong in either direction and the team loses.

## Why this matters

**Treating systemic findings as independent**: produces N PRs that all do the same thing in 14 places. Reviewers see the same pattern repeatedly; merge friction climbs; if the underlying root is wrong, you ship 14 wrong fixes.

**Treating independent findings as systemic**: produces one fix task that bundles unrelated work. The PR becomes hard to review, hard to roll back, and may unintentionally couple unrelated areas.

## Tests for "systemic"

Apply these in order. If any one is true, the findings are likely systemic.

### Test 1: Common location

Do multiple findings reference the same file, component, or shared utility? If yes, almost certainly one root cause.

### Test 2: Common pattern

Do multiple findings describe the same kind of mistake in different places? Examples:

- "Missing disabled state" appearing on multiple buttons
- "Doesn't respect user locale" on multiple date displays
- "Missing aria-label" on multiple icons

If yes, look upstream: is there a missing component / token / convention that, if fixed, eliminates the pattern?

### Test 3: Shared dependency

Do findings touch code paths that all import or call into the same thing? E.g., 5 endpoints all returning the wrong shape because they share a serialiser. One fix at the serialiser; not 5 endpoint fixes.

### Test 4: Auditor's hypothesis

The audit template asks "Pattern observed?" — the auditor was just looking at this. Take their hypothesis seriously even if you didn't see it yourself.

## Tests for "independent"

If all of these hold, treat them as separate fixes:

- Different surfaces, different bounded contexts, different roles
- No shared utility / token / pattern
- No "if I fix X, Y is automatically fixed" relationship
- Different severities (suggests they aren't symptoms of one cause)

## When in doubt

Default to **independent**. It's the safer mistake:
- N small PRs are reviewable; one giant PR isn't
- If the small PRs reveal a pattern after the fact, you can file a follow-up architectural fix
- If you bundle them and one needs to be reverted, you revert all the unrelated work too

## Documenting your decision

When you produce one fix task that addresses multiple findings, the fix issue body must say:

```markdown
This fix addresses findings 1, 5, 7, and 12 from the audit (#NNN).
They share root cause: the `Button` component's `disabled` state
doesn't apply the design token for disabled-text-colour.

Fixing the component eliminates all four findings.
```

This makes the grouping decision auditable. Future readers can see the reasoning even if the original audit issue closes.

## Re-grouping

If during decomposition you change your mind (e.g., realise findings you grouped together actually have different roots), it's fine to re-group. Just make sure:
- No finding is left orphaned (every finding is in some fix's audit-findings marker)
- No finding is double-counted across fixes
