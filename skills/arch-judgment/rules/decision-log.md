# Rule — Decision Log

Every judgment invocation produces a decision-log comment, even if the outcome is "no change, route back unchanged". The decision log is for future operators (human or LLM) reading this issue.

## Required structure

```markdown
## arch-judgment: decision

**Category**: A | B | C | D | E

**Read context**: (brief; what you looked at)
- This issue body and N comments
- Parent issue #N (if applicable)
- arch-ddd/{file}
- ...

**Hypothesis**: (your read of the underlying problem)

**Action taken**: (what you decided and why)

**Routing**: agent:X with reason "..."

**Open questions**: (what remained uncertain after this decision; for future readers)
```

## Why structured

Because future readers — including the next time judgment runs on a related issue — need to quickly understand:

- Was this a known pattern?
- What was tried?
- Did the action resolve the underlying issue?

Without structure, decision rationale gets buried in prose and lost. The structure forces concise capture of the parts that matter.

## Why an Open Questions section

Many judgment decisions are "best guess given current info" — they may turn out wrong. The Open Questions section is where you log:

- What you couldn't determine confidently
- What signal would prove your decision right or wrong
- Hypotheses you considered but rejected without strong evidence

When the same issue (or a related one) surfaces again, future judgment can read these notes and avoid repeating the same wrong call.

## Don't:

- **Self-aggrandise** — the comment is for the issue's evolution, not for showcasing reasoning
- **Hedge in the action** — the action should be definite. Hedging belongs in Open Questions
- **Over-explain category** — assume readers know what categories A–E are; just name yours

## When the action is "no action"

Sometimes after reading, you decide the issue should stay where it was — perhaps the previous specialist routed prematurely. Even then, write a decision log:

```markdown
## arch-judgment: decision

**Category**: A
**Read context**: This issue, parent #142, the QA-PASS comment.

**Hypothesis**: pre-triage routed here on a false-positive verdict
conflict — Design didn't actually post NEEDS_CHANGES, it posted "NEEDS_CHANGES on a sibling PR" which the regex matched incorrectly.

**Action taken**: routing back to pre-triage's expected handler (PR
merge), filing a follow-up issue to fix the regex.

**Routing**: agent:arch with reason "false-positive conflict; PR can merge"

**Open questions**: the regex bug should be tracked at #200 (filed
follow-up). If similar false-positives recur before #200 ships, escalate.
```

This kind of entry is gold: it teaches future judgment about a known false-positive class, and it logs the follow-up issue that prevents recurrence.

## Storage

The comment is just a comment on the issue. It travels with the issue's history. There's no separate decision-log database; GitHub issues are the database.

For project-wide judgment patterns, build a search by filtering for `body:"arch-judgment: decision"` across all issues in the repo. That's the audit trail.
