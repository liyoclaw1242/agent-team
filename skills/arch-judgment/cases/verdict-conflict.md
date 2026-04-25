# Case — QA PASS + Design NEEDS_CHANGES

Both verdicts on the same PR. pre-triage cannot deterministically resolve and routes here.

## Tie-breaking principle

**Design wins for visual / UX issues. QA wins for functional issues.**

Read each verdict's specific finding to determine which kind it is.

## Reading the verdicts

### QA verdict structure

QA verdicts say:

```markdown
## QA Verdict: PASS

- AC #1: ✓
- AC #2: ✓
- ...

triage: (none)
```

If they all check out and triage is empty, QA found no functional issues.

### Design verdict structure

Design verdicts on NEEDS_CHANGES:

```markdown
## Design Verdict: NEEDS_CHANGES

Issues:
1. **[Critical]** Cancel button colour doesn't match design system
2. **[Major]** Confirmation modal missing the project's dialog padding token
```

The findings here are visual / UX. Design wins.

## Decision

For the example above:

```markdown
## arch-judgment: decision

**Category**: A (verdict conflict)

**Read context**: This issue, the linked PR's verdict comments,
arch-ddd/bounded-contexts/billing.md.

**Hypothesis**: QA verified the functional behaviour (AC pass), Design
flagged visual fidelity issues. Both are correct in their domain. The
conflict is procedural, not substantive — Design's findings need to be
addressed before merge.

**Action taken**: routing to FE for the visual fixes Design flagged.
QA's PASS is preserved; once FE addresses the design findings, the PR
re-enters review and Design re-evaluates.

**Routing**: agent:fe with reason "Design verdict NEEDS_CHANGES on visual fidelity; QA PASS preserved"

**Open questions**: none for this issue. (Pattern note: Design
findings being visual-only is the common case. If we ever see Design
flagging a functional issue and QA missing it, the routing logic above
should be re-examined.)
```

## Variants

### Variant: QA FAIL + Design APPROVED

QA caught a functional bug; Design didn't notice (Design isn't usually testing functional flows).

Action: route to whichever role QA's `triage:` field identifies (or back to the implementer if no triage). Design's APPROVED stands; once the QA failure is fixed, the PR re-enters review.

### Variant: QA FAIL on functional + Design NEEDS_CHANGES on UX

Both have legitimate fails. The PR is just not ready. Route to the role who owns the surface (usually FE for UI flows, BE for API flows), with a comment noting both verdicts need to be addressed.

```markdown
## arch-judgment: decision

**Category**: A (compound failure, not really a conflict)

**Action taken**: routing to FE for both the functional fix QA flagged
and the visual fixes Design flagged. They're related — the date field
bug fix may also resolve the alignment issue Design noted.

**Routing**: agent:fe with reason "PR has both functional and visual fails; address both before re-review"
```

### Variant: contradictory verdicts on the same finding

Rare but possible: QA says "the cancel button works correctly", Design says "the cancel button is in the wrong position and likely fails accessibility". If you read closely they aren't contradicting — they're observing different aspects.

The decision: route to the role responsible for the surface, with a comment that lays out both observations clearly so the implementer can address what each said.

## Anti-pattern: trying to merge anyway

"QA passed, Design's concerns are minor, let's merge and follow up" — don't. The merge gates exist for a reason; bypassing them in judgment becomes a slippery slope.

If Design's finding is genuinely minor enough to follow up, Design should have used APPROVED with a comment, not NEEDS_CHANGES. The verdict structure is the contract.
