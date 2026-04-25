# Case — Distributed / Heisenbug

The bug occurs sporadically, possibly only under specific load or timing conditions, and resists reliable reproduction. Common in distributed systems, async workflows, and concurrent code.

## Diagnostic indicators

- Reports describe behaviour that "sometimes" happens
- Multiple Sentry / Datadog occurrences with the same stack but inconsistent triggers
- The same code path works most of the time
- Adding instrumentation seems to change the behaviour

## Why these are dangerous

Two failure modes:

1. **Investigating to local-repro level**: you spend hours synthesising conditions under which the bug fires. By the time you can reproduce reliably, your "reproduction environment" is so artificial that the cause you find may not be the production cause.

2. **Trusting the first explanation that fits**: "must be a race condition" is a common fallback. Sometimes correct, sometimes lazy. Race conditions are real but they're not the explanation for every intermittent bug.

## Investigation strategy

### Step 1 — Triangulate

Don't trust one trace. Pull at least 5 independent occurrences from the observability platform. For each, capture:

- Exact request/event inputs
- User attributes (account state, recent activity)
- Time of occurrence (does it cluster around specific times?)
- Co-occurring signals (was a deploy in progress? a long-running job? a downstream service slow?)
- Stack trace details (is it always exactly the same, or do they vary slightly?)

Look for **what's common** across occurrences. That's your starting hypothesis.

### Step 2 — Check timing

For most distributed bugs, time matters. Map occurrences against:

- Deploy events (correlation with a recent code change is a strong signal)
- Cron / scheduled jobs (does the bug only fire during a batch window?)
- Traffic patterns (does it correlate with peak load?)
- Dependency incidents (was a downstream service degraded?)

A scatter plot of occurrence times often reveals patterns invisible in single traces.

### Step 3 — Hypothesis-driven instrumentation

When you have a hypothesis but can't repro, the right move is often to **add instrumentation specifically to test the hypothesis**, not to add general logging.

Example: hypothesis is "the bug fires when service A's call to service B times out and falls back". Instrumentation: log the fallback path with full input on every fall-back. Wait for next occurrence; either the fallback log lines up with the bug log, or it doesn't.

This is iterative debugging. Each round narrows. Each round costs a deploy and time-to-occurrence.

## Phase X — When to file vs continue

Heisenbugs eat timebox fast. Plan to escalate or file an instrumentation task by the time you've used half the timebox.

### File an instrumentation task

```bash
bash actions/file-fix.sh \
  --bug-issue $BUG_N \
  --owning-role ops \
  --severity 3 \
  --report-file /tmp/instr-task.md
```

The instrumentation task is for OPS; it adds the specific logs / traces / metrics your hypothesis needs to confirm. The bug stays open with deps on the instrumentation task.

### When the task lands

The bug returns to debug with the new instrumentation in place. Next occurrence captures the data; root cause confirmation usually happens quickly from there.

## Example — the classic race condition

Bug: "Sometimes when I refresh the dashboard, my last-saved settings disappear."

Triangulation across 8 occurrences shows:
- All 8 happened within 10 seconds of a save
- 6 of 8 happened on the user's first refresh after a save
- All 8 came from sessions where the user had multiple browser tabs open

Hypothesis: the dashboard uses optimistic local cache, but cache invalidation on save isn't propagating across tabs.

Instrumentation:
- Log when each tab's cache is invalidated
- Log when each tab's save event fires

Next occurrence: the logs show the saving tab invalidated its own cache; the refreshing tab didn't see the invalidation event. Hypothesis confirmed.

Root cause confirmed → file fix issue.

## Anti-patterns

- **"Must be a race condition" without evidence** — say so only when you have at least one log line showing the wrong order.
- **Adding logs everywhere** — adds noise, doesn't help. Targeted instrumentation per hypothesis.
- **Closing as "intermittent, can't fix"** — usually wrong. With enough triangulation and instrumentation, intermittent bugs become tractable. Close only after exhausting Steps 1–3 and timeboxing has hit.
- **Synthesising local repro and trusting it** — sometimes the local repro is a different bug that produces the same symptom. Always cross-validate against production data.
