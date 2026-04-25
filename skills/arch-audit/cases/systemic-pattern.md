# Case — Findings reveal a systemic pattern

The most valuable case to handle correctly. Done well, one root-cause fix replaces N symptom fixes.

## Example

```markdown
## Audit scope
Design audit of all admin tooling pages for accessibility compliance.

## Findings

1. **[Critical]** Disabled "Save" button on /admin/users — contrast 2.1
2. **[Critical]** Disabled "Delete" button on /admin/orgs — contrast 2.1
3. **[Critical]** Disabled "Suspend" button on /admin/billing — contrast 2.0
... (11 more Critical findings, all disabled buttons across admin pages)

14. **[Major]** Inconsistent spacing in /admin/users form — 16px row gap
15. **[Major]** Inconsistent spacing in /admin/billing form — 16px row gap
... (4 more, all about 16px vs 24px form row gap)

## Pattern observed
Findings 1–13 all relate to disabled-button contrast. Likely caused
by `--button-disabled-color` token not meeting WCAG AA. Findings 14–18
related: forms use literal `gap: 16px` instead of the design token
`--form-row-gap` which is 24px.
```

## Decomposition

Two systemic fixes plus zero independent fixes:

### Fix 1: design token for disabled button contrast

```markdown
[Design] Update --button-disabled-color token to meet WCAG AA contrast

## Findings addressed
1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13 from audit #NNN

## Root cause
The `--button-disabled-color` design token currently produces 2.0–2.1
contrast against background. WCAG AA requires 4.5:1 for text, 3:1 for
non-text UI components.

## Acceptance criteria

- [ ] Token updated to value meeting 4.5:1 contrast
- [ ] Visual diff snapshot reviewed for unintended brightness changes
  to non-disabled-button uses (the token is also used elsewhere)
- [ ] All 13 reported pages re-checked: contrast measurement >=4.5:1

## Severity

Critical (highest among grouped findings).

<!-- parent: #NNN -->
<!-- audit-findings: 1,2,3,4,5,6,7,8,9,10,11,12,13 -->
<!-- severity: 1 -->
```

### Fix 2: replace literal spacing with design token

```markdown
[FE] Replace literal `gap: 16px` with `--form-row-gap` token in admin forms

## Findings addressed
14, 15, 16, 17, 18 from audit #NNN

## Root cause
Five admin forms use `gap: 16px` directly instead of the design token
`--form-row-gap` (currently 24px).

## Acceptance criteria

- [ ] grep src/admin/ for `gap: 16` returns no results
- [ ] All 5 affected forms use `var(--form-row-gap)` or its CSS-in-JS equivalent
- [ ] Visual diff: forms now display with 24px row gap consistently

## Severity

Major.

<!-- parent: #NNN -->
<!-- audit-findings: 14,15,16,17,18 -->
<!-- severity: 2 -->
```

## What we did NOT produce

- 18 separate fix tasks (one per finding) — too much ceremony
- One fix bundling all 18 — couples Critical and Major work, hard to review

## Why two fixes, not one

Findings 1–13 are a Design fix (token change). Findings 14–18 are an FE fix (replace literal with token reference). Different roles, different review focus. Splitting respects role boundaries.

## What if findings 14–18 were also blocked on Fix 1?

In this case they aren't — `--form-row-gap` already exists, the form code just doesn't use it. If Fix 2 had needed Fix 1 first, you'd add a deps marker to Fix 2:

```markdown
<!-- deps: #220 -->
```

…and Fix 2 starts as `status:blocked`. arch-audit's `actions/open-fix.sh` handles deps the same way arch-shape's does.
