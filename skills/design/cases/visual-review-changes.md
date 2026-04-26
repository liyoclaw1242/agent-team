# Case — Visual Review (NEEDS_CHANGES)

Mode B worked example. Scenario: a different fe submission for the dashboard spec from `cases/pencil-spec-dashboard.md`. Several issues found.

## The PR

```
PR #430 — feat(billing): admin dashboard
Refs: #402

Implements the billing admin dashboard with metrics, transactions, and pending actions.
```

## Phase 1 — Read

Spec: extract from #402 issue body.
Diff: `src/admin/Dashboard.tsx` and supporting files.

## Phase 2 — Reality check

PR implements all the major regions. AC appear addressed. But:

- Auto-refresh is hard-coded to 30s, not 60s
- Metric tiles show 4 across at all viewport widths (no 2x2 at <1280px)
- Pending actions list has no empty state implemented

Initial impression: implementation diverges from spec in several places.

## Phase 3 — Inspect

### Layer 1: Foundation compliance

`validate/token-usage.sh`:

```
src/admin/Dashboard.module.css: 2 findings
  Line 23: hardcoded #fafafa instead of var(--bg-secondary)
  Line 56: padding 14px (off-scale; nearest scale value is 16px / space-4)
src/admin/MetricTile.tsx: 1 finding
  Line 12: text color "#525252" (use text-secondary)
```

Three foundation violations.

### Layer 2: Spec adherence

Walking through:

#### Visual spec

- Container max-width 1280px ✓
- Metric tiles row: gap space-4 ✓
- BUT: 4 columns at all widths (spec said 4 across at 1280+, 2x2 at <1280) ✗
- Page heading text-3xl ✓
- Section headings text-xl ✓
- Recent transactions table: status badges use icon ✓ but pending status uses an arrow icon, not the clock icon spec'd
- Hover state on row: implemented but uses bg-secondary instead of bg-tertiary
- Pending actions list: list items implemented; empty state not implemented (just shows nothing if list is empty)

#### Interaction spec

- Auto-refresh: 30s actual, 60s spec'd ✗
- Manual refresh button: works ✓
- Stale data state: not implemented (no banner appears even when refresh fails)
- Tab focus revisit: auto-refresh fires immediately ✓

#### Accessibility verification

- Region headings present ✓
- Table semantics ✓
- aria-live on last-updated ✓
- Status badges have aria-label ✗ (implementation uses only icon + text; works for sighted but icon-only stripped of context for screen readers)

### Layer 3: Accessibility

`validate/contrast.sh`:

```
brand-600 link color on bg-secondary: 5.9:1 (PASS AA)
text-tertiary on bg-secondary: 4.6:1 (PASS AA)
status badge text contrasts: 7.2:1+ all pass
```

Color contrast all passes.

But:
- Status badge `aria-label` issue (above)
- Pending action items: no semantic list (`<div>` siblings); should be `<ul><li>`

## Phase 4 — Compile findings

1. **[Critical]** Status badges lack screen-reader accessible names
   - Location: src/admin/StatusBadge.tsx:18
   - Spec said: badges have icon + text combo readable to screen readers; `aria-label="Paid"` etc. as fallback
   - Actual: icon is decorative-rendered; visible text "Paid" but no aria-label on the badge itself
   - Reference: spec "Accessibility spec → ARIA"

2. **[Critical]** Pending actions list lacks list semantics
   - Location: src/admin/PendingActions.tsx:24
   - Spec said: `<ul>` with `<li>` per item
   - Actual: `<div>` siblings; screen readers don't announce as a list
   - Reference: spec "Accessibility spec → Semantic HTML"; WCAG 1.3.1

3. **[Major]** Metric tiles don't respond to viewport at <1280px
   - Location: src/admin/MetricsRow.tsx:8 (no media query for grid columns)
   - Spec said: 4 across at 1280+; 2x2 at <1280px
   - Actual: 4 across at all sizes; results in cramped tiles at 1024px
   - Reference: spec "Visual spec → Metrics row"

4. **[Major]** Auto-refresh interval is 30s, spec'd 60s
   - Location: src/admin/Dashboard.tsx:42 (`setInterval(refresh, 30000)`)
   - Spec said: 60s auto-refresh
   - Actual: 30s
   - Reference: spec "Interaction spec → Auto-refresh"

5. **[Major]** Stale data state not implemented
   - Location: missing from Dashboard.tsx
   - Spec said: when refresh fails > 90s, "Last updated" becomes warning-prominent + banner appears
   - Actual: silent failure; user has no indication data may be stale
   - Reference: spec "Visual spec → States → Stale data"

6. **[Major]** Hardcoded color in CSS
   - Location: src/admin/Dashboard.module.css:23 (`background: #fafafa`)
   - Reference: rules/design-token-discipline.md; should use `var(--bg-secondary)`

7. **[Major]** Off-scale padding value
   - Location: src/admin/Dashboard.module.css:56 (`padding: 14px`)
   - Reference: foundations/space-and-rhythm.md; nearest scale value is 16px (space-4)

8. **[Minor]** Hardcoded text color
   - Location: src/admin/MetricTile.tsx:12 (`color: '#525252'`)
   - Reference: design-token-discipline.md; use `text-secondary`

9. **[Minor]** Wrong icon for pending status badge
   - Location: src/admin/StatusBadge.tsx:34 (uses arrow-right icon)
   - Spec said: clock icon for "pending"
   - Reference: spec "Visual spec → Status cell"

10. **[Minor]** Hover state uses wrong bg color
    - Location: src/admin/TransactionRow.tsx:17 (uses bg-secondary)
    - Spec said: bg-tertiary
    - Reference: spec "Visual spec → Recent transactions table → Hover state"

11. **[Minor]** Empty state for pending actions missing
    - Location: src/admin/PendingActions.tsx (no empty case)
    - Spec said: "All caught up." message when empty
    - Reference: spec "Visual spec → Empty state"

## Phase 5 — Decide verdict

- 2 Critical findings (a11y violations)
- 5 Major findings
- 4 Minor findings

→ **NEEDS_CHANGES**

The Critical a11y issues alone are enough; the Majors compound the case.

## Phase 6 — Compose verdict

```markdown
## Design Verdict: NEEDS_CHANGES

Implementation diverges from spec in multiple dimensions including two a11y critical issues.
Several foundation-level issues (hardcoded values, off-scale padding) also flagged.

### Findings

- **[Critical]** Status badges lack screen-reader accessible names
  - Location: src/admin/StatusBadge.tsx:18
  - Spec said: icon + text + aria-label fallback
  - Actual: only visible text; icons are decorative; no aria-label
  - Reference: spec "Accessibility spec → ARIA"; WCAG 1.1.1

- **[Critical]** Pending actions list lacks `<ul>`/`<li>` semantics
  - Location: src/admin/PendingActions.tsx:24
  - Spec said: list semantics required
  - Actual: `<div>` siblings; screen readers don't announce as a list
  - Reference: spec "Accessibility spec → Semantic HTML"; WCAG 1.3.1

- **[Major]** Metric tiles don't reflow at <1280px
  - Location: src/admin/MetricsRow.tsx:8
  - Spec said: 4 across at 1280+; 2x2 at <1280
  - Actual: 4 across at all viewport widths; cramped at 1024px
  - Reference: spec "Visual spec → Metrics row"

- **[Major]** Auto-refresh interval wrong
  - Location: src/admin/Dashboard.tsx:42
  - Spec said: 60s
  - Actual: 30s
  - Reference: spec "Interaction spec → Auto-refresh"

- **[Major]** Stale data state not implemented
  - Location: missing from Dashboard.tsx
  - Spec said: warning banner + prominent timestamp when refresh fails
  - Actual: silent failure
  - Reference: spec "Visual spec → States → Stale data"

- **[Major]** Hardcoded background color
  - Location: src/admin/Dashboard.module.css:23
  - Actual: `background: #fafafa`
  - Should be: `var(--bg-secondary)`
  - Reference: rules/design-token-discipline.md

- **[Major]** Off-scale padding
  - Location: src/admin/Dashboard.module.css:56
  - Actual: `padding: 14px`
  - Should be: `space-4` (16px); nearest scale value
  - Reference: _shared/design-foundations/space-and-rhythm.md

- **[Minor]** Hardcoded text color
  - Location: src/admin/MetricTile.tsx:12
  - Actual: `color: '#525252'`
  - Should be: `text-secondary`
  - Reference: design-token-discipline.md

- **[Minor]** Wrong icon for pending status
  - Location: src/admin/StatusBadge.tsx:34
  - Spec said: clock icon
  - Actual: arrow-right icon
  - Reference: spec "Visual spec → Status cell"

- **[Minor]** Hover bg color
  - Location: src/admin/TransactionRow.tsx:17
  - Spec said: `bg-tertiary`
  - Actual: `bg-secondary`
  - Reference: spec "Visual spec → Recent transactions table → Hover state"

- **[Minor]** Empty state for pending actions missing
  - Location: src/admin/PendingActions.tsx
  - Spec said: "All caught up." message
  - Actual: list area renders empty when no items
  - Reference: spec "Visual spec → Empty state"

### What's needed

Address the two Critical a11y issues (status badges and list semantics) before re-review.
The Major findings should also be fixed; the most impactful are auto-refresh interval,
stale-data state, and the responsive metric layout. Minor findings can land in the same
fix or as follow-up.

After fix, push and re-request review.

triage: fe
Reviewed-on: a7b9c1d
```

## Phase 7 — Post + route

```bash
bash actions/post-verdict.sh \
  --issue 402 \
  --pr 430 \
  --verdict-file /tmp/verdict-402.md
```

Verdict format check passes (first line, triage, reviewed-on all valid).

Routes #402 to `agent:arch`.

## Phase 8 — pre-triage handles

`pre-triage.sh` reads the verdict:
- `## Design Verdict: NEEDS_CHANGES`
- triage: fe

→ Routes #402 to `agent:fe + status:ready`. fe will pick this up, address findings, push new commits, and re-request review.

## Phase 9 — Self-test

```markdown
# Self-test record — issue #402 (design visual-review)

## Acceptance criteria
- [x] AC #1: review completed against spec — all three layers verified
- [x] AC #2: verdict posted with strict format — accepted
- [x] AC #3: triage field correct — triage: fe (impl issues, not spec issues)

## Foundations consulted
- color.md (contrast verification — all pass)
- space-and-rhythm.md (off-scale padding caught)
- patterns/data-display.md (table & list pattern checks)

## Verdict reference
PR comment: https://github.com/owner/repo/pull/430#issuecomment-{ID}
Verdict: NEEDS_CHANGES (2 Critical, 5 Major, 4 Minor)
SHA reviewed: a7b9c1d

## Validators
- token-usage: 3 findings (in verdict)
- contrast: clean

## Ready for review: yes
```

## What this case demonstrates

- **Many findings ≠ pile-on**: each finding is specific and actionable; total count reflects actual divergence
- **Severity calibration**: a11y issues are Critical; spec divergences mostly Major; cosmetic stuff Minor
- **Foundation-level + spec-level both flagged**: hardcoded color is foundation; wrong icon is spec
- **Reference cited per finding**: easier for fe to find the relevant doc
- **Suggested fix where actionable**: e.g., the suggested token replacement for hardcoded color
- **Triage = fe is the right call**: findings are about implementation matching spec, not the spec being wrong
