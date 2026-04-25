# Rule — Reproducibility

Every root-cause claim must rest on either:

- A reliable reproduction recipe, OR
- Unambiguous evidence (specific trace IDs, log lines, stack traces) that points at the failing code path

Reproducibility-or-evidence is what makes a confirmed root cause distinct from a plausible-sounding guess.

## When reproduction works

Most bugs from `source:human` come with reproduction steps. When you can run those steps and consistently reproduce the failure, you have a strong handle:

1. Use the repro to test hypotheses (instrument, add logs, set breakpoints)
2. Bisect with confidence (each test has a clean signal)
3. Capture the repro in the fix issue's AC

Capture the repro recipe in your investigation notes. It's the foundation for the fix's verification:

```markdown
## Reliable reproduction (verified by debug)

1. Log in as a user with no payment method on file
2. Navigate to /billing/upgrade
3. Click any plan in the upgrade list
4. Observe: page goes blank with console error "Cannot read property 'amount' of undefined"

Reproduces 100% of the time on staging.
```

## When reproduction doesn't work — the hard cases

### Hard case: source:alert with no human repro

The originator is an observability platform; there's no human to ask "how did you do that". Instead you have:

- A trace ID
- A stack trace (or breadcrumbs)
- Surrounding context (other traces in the same time window)

Treat the trace as evidence. If the trace clearly identifies the code path (specific function, specific line, specific input), that's "unambiguous evidence" — proceed with hypothesis testing using the trace data, even without local repro.

If the trace is ambiguous or incomplete (e.g., only a generic "panic in handler X"), file an OPS task for better instrumentation per `rules/timebox.md` Option 2.

### Hard case: heisenbug

The bug occurs sporadically and resists reliable reproduction. See `cases/distributed-bug.md`.

In this case, "evidence" replaces "repro":
- Multiple traces from separate occurrences, all showing the same code path failing
- Statistical: error rate spikes correlate with specific events (deploys, traffic patterns, time of day)

Three independent occurrences with consistent evidence is a reasonable bar for "confirmed".

### Hard case: cannot reproduce despite trying

You followed the steps and the bug doesn't happen. See `cases/cannot-reproduce.md`. Don't attempt to investigate without repro or trace evidence — too many wrong hypotheses fit observed data.

## Don't fabricate evidence

When you write the root-cause report:

- Quote actual log lines, don't paraphrase ("the log says X" is fine; "the log probably says X" is not)
- Reference specific line numbers from the actual code at investigation time
- Reference specific commits — `git blame` on the suspect line shows when it was introduced

If you find yourself writing "the system would do X" without being able to verify it, you're at hypothesis stage, not confirmation. Go test.

## Repro as test

Once root cause is confirmed and a fix issue is filed, the reliable repro becomes a regression test. The fix issue's AC includes:

```markdown
- [ ] The reliable repro from #BUG_N (login as no-pm user → /billing/upgrade → click plan → no console error) passes
- [ ] An automated test exercising this path is added to the regression suite
```

This closes the loop: debug found it → fix addresses it → the test prevents regression.

## Anti-patterns

- **Inferring from "must be the case"** — "the database call must be timing out because everything else looks fine" is not evidence. Test it.
- **Picking the most recent commit and assuming it's the cause** — sometimes is, sometimes isn't. `git blame` tells you the commit that introduced the line; whether that's the cause needs separate verification.
- **Trusting one trace** — for non-trivial bugs, one trace can mislead. Cross-reference with at least two occurrences when possible.
