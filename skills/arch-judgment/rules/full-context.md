# Rule — Full Context Reading

Judgment reads more than other specialists. Token budget concerns that constrain arch-shape and arch-feedback don't apply as strongly here, because judgment runs on 1–5% of issues.

## What "full context" includes

For an issue routed to judgment, read in this order:

1. The handoff comment from the previous specialist (most condensed signal)
2. The current issue's body and ALL comments
3. The parent issue (if any) — body and ALL comments
4. Sibling child issues (if any) — at least their bodies, and any comments mentioning the current issue
5. Linked PR if applicable — verdict comments, CI status, recent reviews
6. arch-ddd files relevant to the bounded contexts in play
7. Recent feedback rounds across the project (only if "pattern" is one of the hypotheses)

This is more than other specialists read. That's the point.

## Why this matters

Judgment-quality decisions require seeing the system, not just the symptom. A round-3 feedback escalation isn't well-resolved by reading round-3's comment — you need round 1, round 2, and what's around the parent that might have shifted between them.

A verdict conflict isn't well-resolved by picking which specialist looks more confident — you need to read the failure descriptions and identify whether it's UX or functional in nature.

The cost of reading wrong: judgment makes a bad call, the issue surfaces again, the team loses trust in the system.

The cost of reading thoroughly: a few thousand tokens per invocation. Cheap.

## When NOT to read more

- When you've already identified Category C (malformed input cycled): the right action is "back to source for revision". You don't need to dig into arch-ddd.
- When you've already identified Category E (system bug): file the follow-up, route to human. Reading more won't change that.

## Reading via tools, not memory

Even if you've seen a related issue earlier in the session, re-read it. Issue state changes between reads (label updates, new comments, body edits). Acting on stale memory is a common bug class for LLM agents.

The cost is one extra `gh issue view` call. The risk it prevents is acting on outdated information.

## Cross-reference reading

If two specialists each escalated to judgment recently with similar handoff comments, they may be symptoms of the same problem. Search recent judgment activity:

```bash
gh issue list --repo $REPO --label agent:arch-judgment --state all --search "in:comments arch-judgment" --limit 10
```

If you spot a pattern (e.g., 4 round-3 escalations all touching billing context in the past week), that itself is a signal — the bounded context may need re-defining, not just one more issue resolved. File a follow-up architecture intake noting the pattern.
