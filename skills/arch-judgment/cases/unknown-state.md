# Case — Unknown State

The dispatcher's rule 5 fired because no other rule matched. Arrives here with no handoff comment (dispatcher doesn't write one for rule 5).

## Why this happens

Dispatcher rule 5 fires when:

- An issue has `agent:arch + status:ready` but no `<!-- intake-kind: -->` marker
- Multiple intake-kind values disagree (rare; intake-validator should catch)
- The issue body has been edited in a way that confuses dispatcher's parser
- The issue is in some other state nobody anticipated

Each of these is a different action.

## Phase 1 — Diagnose

Run a quick check on the issue's state:

```bash
labels=$(gh issue view $N --repo $REPO --json labels --jq '[.labels[].name] | join(", ")')
markers=$(REPO=$REPO bash _shared/actions/issue-meta.sh list $N)
body_has_feedback=$(gh issue view $N --json body --jq '.body' | grep -c "Technical Feedback from")
parent=$(REPO=$REPO bash _shared/actions/issue-meta.sh get $N parent 2>/dev/null || echo "")
```

This gives you a structured view of state. Look for:

- **Missing intake-kind**: the issue was filed without going through a template → action is "ask source to fix or close as malformed"
- **Multiple intake-kind values**: someone manually edited body and broke schema → action is "delete extras, keep one, route accordingly"
- **No labels at all besides agent:arch + status:ready**: someone created an issue manually without labels → action is "ask source to add labels"
- **bug-of marker but missing parent**: debug created a fix issue but didn't fill in `<!-- parent: -->` → action is "fix the marker, route back to debug for delivery"

## Phase 2 — Take canonical action

### Sub-case: missing intake-kind

If the issue was clearly intended as a request (has descriptive body) but lacks intake-kind:

```markdown
## arch-judgment: decision

**Category**: C (malformed input cycled)

**Hypothesis**: This issue was filed without using a GitHub Issue
template — it has no `<!-- intake-kind: -->` marker. Dispatcher's
escape hatch caught it.

**Action taken**: commenting on the issue asking the originator to
either close and re-file via the appropriate template, or add the
correct intake-kind marker. Routing to a human-review label so it's
not silently parked.

**Routing**: agent:human-review with reason "missing intake-kind marker; needs originator action"
```

### Sub-case: dispatcher state confused

If the issue is in a state that suggests automation went wrong (e.g., it has both `intake-kind: business` and `intake-kind: bug` — should never happen):

```markdown
## arch-judgment: decision

**Category**: E (system bug)

**Hypothesis**: Multiple intake-kind markers in body; suggests either
a manual edit gone wrong or a bug in issue-meta.sh's set logic.

**Action taken**: removing all but the most recent intake-kind marker
(business, based on commit history). Filing follow-up issue at #500 to
investigate how this state arose. Routing back to dispatcher for
re-classification with the cleaned state.

**Routing**: agent:arch with reason "cleaned state; re-classify"

**Open questions**: did issue-meta.sh's `set` operation preserve a
duplicate? See #500 for investigation.
```

### Sub-case: orphan child issue

If the issue has `<!-- parent: -->` but the parent doesn't exist:

```markdown
## arch-judgment: decision

**Category**: E (system bug)

**Hypothesis**: Parent #200 referenced in body, but #200 doesn't
exist in this repo (404 from gh). Likely a typo in the parent
marker, or the parent was hard-deleted (which shouldn't happen).

**Action taken**: closing this child as orphaned. Filing follow-up
to investigate how the orphan state was created.

**Routing**: status:done with closing comment; not routing further.
```

## Phase 3 — Filing follow-ups

For category E (system bug), you file a follow-up issue to track the underlying automation bug. The follow-up is a normal architecture intake (intake-kind: architecture is fine if it's significant; otherwise just a regular bug to debug).

Don't try to fix the automation here — that's a code change, not a routing decision. File it; let the team's normal flow address it.

## When to escalate to human-review

Categories C and E almost always go to human-review, because:

- Category C: only the originator can fix the malformed input
- Category E: someone needs to look at the automation; it's beyond what judgment can resolve via routing alone

Categories A, B, D should be resolvable by judgment without human escalation in 95% of cases.

## Anti-pattern: silently dropping the issue

Don't close an issue without comment because you can't figure out what to do. Future operators reading "issue closed by arch-judgment with no comment" have no audit trail.

If you're closing for legitimate reason (orphan, duplicate, malformed beyond repair), comment with the reason in the structured decision-log format. The closing comment IS the audit trail.
