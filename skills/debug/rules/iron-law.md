# Rule — Iron Law

**No fix proposal without a confirmed root cause.**

## Statement

Debug never produces a fix issue based on guess-fix-and-see. Every root-cause report contains a confirmed cause stated in one sentence with no hedging language ("might", "probably", "I think").

A fix proposed without root cause is not "approximately right" — it's wrong by construction. Either it doesn't fix the bug (and now there's a closed fix issue masking that), or it accidentally fixes the bug for the wrong reason (and the actual underlying issue resurfaces elsewhere later).

## What "confirmed" requires

A root cause is confirmed when ALL of:

1. **Mechanism described**: you can describe what the code does that causes the failure. Not "the validation is broken" but "the validation in `Cancel.tsx:42` doesn't check for `currentPlan === null`, so when a user without a plan loads the page, the cancel button enters its 'enabled' state and crashes when clicked".

2. **Evidence cited**: file:line, log line, trace span, or git commit pointing at the cause. If you can't cite, you've inferred not confirmed.

3. **Repro confirms**: you can demonstrate the cause by reproducing the bug, OR (if non-reproducible like a heisenbug) the trace/log evidence is unambiguous about which code path failed.

4. **Negative test**: ideally, you can describe a counter-example — "if X were true, the bug wouldn't happen" — and verify X. This is the strongest form of confirmation.

## Hedging language is forbidden in the report

Words that indicate insufficient confidence:

- "might"
- "probably"
- "likely"
- "I think"
- "I believe"
- "perhaps"
- "could be"

If your root-cause sentence contains any of these, you're not confirmed yet. Either gather more evidence or escalate per the timebox rule.

## Two valid exits when not confirmed

### Exit A: cannot reproduce

You've tried the repro steps and the bug doesn't happen. See `cases/cannot-reproduce.md`. Comment on the bug, route back to source for more info. Don't file a fix.

### Exit B: timebox exceeded

You've spent the budgeted investigation steps and still don't have a confirmed cause. See `rules/timebox.md`. Escalate to human review or arch-judgment with what you've found so far.

The wrong move is filing a fix issue with hedging language. That sets up the implementer to fail.

## Why "Iron Law"

The name is deliberately strong. In real-world projects, the temptation to "ship a fix and see if it helps" is constant — especially under time pressure with a Sev 1 bug. The Iron Law exists because giving in to that temptation is one of the most reliable ways to ship technical debt and partial fixes.

If a Sev 1 bug needs immediate mitigation, the right move is:
- Mitigation: a runtime workaround (feature flag off, traffic reroute, scaling) — filed as an OPS task, not a fix
- Investigation: continues at debug pace
- Real fix: filed when root cause is confirmed

Don't conflate mitigation with fix. Mitigation is "stop the bleeding"; fix is "address the cause".

## What to do if you're tempted to bend this

That feeling is a signal to escalate, not to bend. Ask arch-judgment:

```markdown
This bug is Sev 1, on for 3 hours, and I've identified a code path
that's likely involved but I can't confirm without {missing thing}.
Should I file a mitigation OPS task and continue investigating, or
escalate to human-review?
```

The right answer is rarely "guess at the fix".
