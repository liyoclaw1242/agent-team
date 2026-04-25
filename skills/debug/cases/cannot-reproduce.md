# Case — Cannot Reproduce

You followed the bug report's steps; the bug doesn't happen. Common, and dangerous to handle wrong: investigating without repro produces speculative reports that don't actually address the bug.

## What "cannot reproduce" means

Specifically: after following the reproduction steps in the same environment described, you don't observe the reported "actual" behaviour. You see "expected" instead.

Don't conclude this from one attempt — the bug may be intermittent. Try at least:
- 3 attempts in the same environment
- 1 attempt in each environment mentioned (local, staging, prod-equivalent)
- A check whether the user's specific data shape might matter (logged-in vs anonymous, account age, plan tier)

If after these attempts the bug doesn't surface, treat as "cannot reproduce".

## Phase 1 — Document what you tried

Comment on the bug issue with what you did:

```markdown
## Investigation: cannot reproduce (attempt 1)

Tried:
- Steps 1–4 as written, in staging, 3 separate runs — no error
- Same steps in local with seeded test data — no error
- Same steps with anonymous session — no error

Observed: the page loads correctly each time, no console errors,
network 200 on the payment POST.

Hypotheses to differentiate:
- The user has a specific data shape (e.g., null fields somewhere)
- The user's session is in some unusual state (recently deleted account?)
- Browser-specific (the bug report didn't say which browser/version)
- A dependency timing condition (slow network, retries)
- The bug only happens at specific times (cron, batch processing windows)

What I need to confirm any of these:
- Browser + version
- Time of day when the bug was observed
- Whether the user had any unusual recent activity (account changes, admin actions)
```

## Phase 2 — Don't investigate without repro

The temptation: "the user said it crashed; I'll read the code and find a possible cause anyway".

Don't. Without a repro:
- Many wrong hypotheses fit the observed report
- The "fix" you propose might address a different bug
- You could ship a fix and the user reports the bug again, having not been fixed

## Phase 3 — Choose one of three exits

### Exit A: Route back to the originator for more info

For `source:human` bugs, the usual case. Ask specifically:

```bash
bash route.sh $BUG_N human-review \
  --reason "cannot reproduce; need more info from originator"
```

The comment requesting info should be specific. Generic "please give more info" doesn't help. Ask the questions whose answers would let you reproduce:

- What browser and version?
- What time did this happen (UTC)?
- Did anything unusual happen on the user's account recently (plan changes, admin actions)?
- Can you share a screenshot of the error or a HAR file?
- Is the user willing to repro again with developer tools open?

### Exit B: Add observability and wait for next occurrence

For bugs that are believed real but rare, file an OPS task to instrument the suspect path:

```bash
bash actions/file-fix.sh \
  --bug-issue $BUG_N \
  --owning-role ops \
  --severity 4 \
  --report-file /tmp/instrumentation-task.md
```

The task body explains: "this is for instrumentation, not a fix; the bug stays open until next occurrence is captured with better data".

This is appropriate when:
- The bug is real but rare (Sev 3 / 4)
- Existing instrumentation doesn't cover the suspect surface
- Adding instrumentation has low cost

It's NOT appropriate for ongoing Sev 1 / 2 — those need real-time investigation, not "wait and see".

### Exit C: Close as not reproducible

Last resort, only after Exit A has been tried and the originator hasn't responded for >2 weeks (project-tunable):

```markdown
## Closing — cannot reproduce, no further info

Original report could not be reproduced after multiple attempts. Originator
asked for more info on {date}; no response received in 2 weeks.

If this recurs, please reopen with:
- Browser + version
- Exact time + UTC offset
- Steps verified to reproduce in your environment

Closing for hygiene; not because the bug is rejected.
```

Then `gh issue close` the bug.

## Phase 4 — Don't file a fix

This case never produces a fix issue. Filing one would violate the Iron Law (no fix without confirmed root cause).

If you find yourself wanting to file a "speculative fix" — that's the failure mode this case documents. Resist.

## Anti-patterns

- **Reading code and writing a "probably the cause" report** — Iron Law violation. The user reads "this is the fix" and assumes it's confirmed; when the bug recurs, trust in debug erodes.
- **Closing immediately on first failed repro** — bugs can be intermittent. Try a few times and consider hypotheses about why your environment differs from the user's.
- **Hand-waving with "user error"** — sometimes it is, but say so explicitly with reasoning, don't bury it.
