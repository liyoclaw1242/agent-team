# Case — Single-finding audit

Sometimes an audit issue has just one finding. This is unusual (single findings should be PR-comments, not separate audits) but it does happen.

## Example

```markdown
## Audit scope
Reviewed billing flow after recent refactor (PR #501).

## Findings
1. **[Sev 2]** Cancel button on /billing has no loading state — user can double-submit
   - Location: src/pages/billing/CancelDialog.tsx:42
   - Expected: button disabled while request in flight
   - Actual: stays clickable, multiple submits land

## Pattern observed
None — drive-by find while reviewing the refactor.
```

## Decomposition

One fix task. No grouping decision needed. The body of the fix issue can be near-verbatim from the finding:

```markdown
[FE] Add loading state to Cancel button on /billing

## Finding (from audit #NNN)

The cancel button doesn't disable during request flight. Multiple clicks
result in multiple POST attempts.

## Acceptance criteria

- [ ] Button enters disabled state on click
- [ ] Spinner / pending indicator is visible
- [ ] If the request fails, button re-enables and error is shown
- [ ] If the request succeeds, modal closes and parent refreshes
- [ ] Idempotency at the server is unchanged (BE not in scope)

## Severity

Sev 2.

## Reference

Original location: src/pages/billing/CancelDialog.tsx:42

<!-- parent: #NNN -->
<!-- audit-findings: 1 -->
<!-- severity: 2 -->
```

## Why this is still useful as an audit issue

Even single-finding audits go through arch-audit because:

1. The audit template enforces structure that PR comments don't
2. The resulting fix task gets `source:arch` provenance, dispatcher fast-paths it
3. Audit history is searchable as a separate type of issue

If single-finding audits become routine, that's a process smell to flag — usually a sign that PR-comment workflow isn't being used. Talk to QA / Design.
