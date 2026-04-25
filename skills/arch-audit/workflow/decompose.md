# Workflow — Decompose Audit Findings

## Phase 1 — Read intake

The audit issue follows a structured template. Required fields:

- **Audit scope** — what was audited (which surfaces, flows, PRs)
- **Findings** — numbered, each with severity tag, location, expected vs actual
- **Pattern observed** — auditor's hypothesis about underlying cause (may be empty)
- **Audit date**

Read all of these. Pay special attention to "Pattern observed" — the auditor often has the right read on whether findings are independent or systemic.

## Phase 2 — Group findings

For each finding, decide which group it belongs to:

- **Independent**: a one-off bug, no relationship to other findings → its own fix task
- **Systemic**: shares an underlying cause with other findings → group with them, file one architectural fix task

Heuristics for "systemic":

- Same code location appears in multiple findings (e.g., 14 buttons missing the same disabled state)
- Same component type / pattern is wrong everywhere (e.g., all date inputs ignore locale)
- Findings reference a shared dependency (e.g., a util function that returns wrong values)

Heuristics for "independent":

- Different surfaces, different code paths, no shared root
- Different severities AND different locations
- Auditor explicitly notes "found while investigating X" — these are usually drive-by, independent

## Phase 3 — Decide one fix or N fixes per group

For systemic groups, the choice is:

- **One fix at the root** — e.g., "fix the design token for disabled button contrast → all 14 buttons fixed by reload"
- **N fixes following one architectural change** — e.g., "introduce the design token (1 fix), then update each button to use it (N fixes)" if the changes are mechanical but big enough to warrant separate review

Default to **one fix at the root**. Only split if:
- The architectural change is significant enough to warrant its own review (>200 LoC)
- The mechanical migration is large enough that a single PR would be unreviewable
- Different roles handle architecture vs migration

## Phase 4 — Open fix issues

For each fix decision, call `actions/open-fix.sh`:

```bash
bash actions/open-fix.sh \
  --audit-issue "$AUDIT_N" \
  --agent fe \
  --severity 2 \
  --title "Fix: cancel button missing loading state" \
  --findings "1" \
  --body-file /tmp/fix-body.md
```

The action handles:
- `source:arch`, `agent:{role}`, `status:ready`
- `<!-- parent: #AUDIT -->`
- `<!-- audit-findings: 1,2 -->` (which findings from the audit this fix covers)
- `<!-- severity: N -->` (highest severity among grouped findings)

## Phase 5 — Deliver

Same as arch-shape — post a summary comment on the audit issue, route audit to status:done.

```bash
bash actions/deliver.sh \
  --audit-issue "$AUDIT_N" \
  --fixes "#220,#221,#222" \
  --reason "decomposed audit into 3 fixes"
```

The action verifies all fix issues have correct labels and parent markers, posts the summary, then closes the audit.

## Self-test before deliver

- [ ] Every fix issue has `source:arch`, `agent:{role}`, `status:ready`, `<!-- parent: -->`
- [ ] Every finding from the audit is referenced by at least one fix issue's `audit-findings` marker
- [ ] No finding is referenced by more than one fix issue (no double-fixes)
- [ ] Severity in the fix matches the highest severity among grouped findings

If any check fails: don't deliver. Either fix the inconsistency or escalate to arch-judgment.

## Anti-patterns

- **One fix per finding always** — turns audits into ceremony. Use pattern recognition.
- **One fix for everything** — if the audit listed 10 findings and you produced one giant fix, you've made a coupled PR that's hard to review.
- **Inventing fixes for things not in the audit** — stay scoped. If the audit reveals a related concern, file a follow-up audit issue, don't expand this one.
