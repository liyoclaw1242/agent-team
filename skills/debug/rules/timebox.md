# Rule — Investigation Timebox

Bounded investigation: if root cause isn't confirmed within the timebox, escalate. Don't loop indefinitely.

## The timebox

Default: **6 distinct hypotheses tested** OR **8 hours of wall-clock investigation**, whichever comes first.

These are starting numbers; tune per project.

## Why a timebox

Two failure modes the timebox prevents:

### Failure mode 1: rabbit-hole investigation

A bug is genuinely hard. Each hypothesis turns up just enough new evidence to suggest the next hypothesis. After 12 hypotheses, you've learned a lot about adjacent systems but still don't have root cause. Meanwhile, the bug ticket is days old.

The timebox forces a check-in: am I actually converging? Sometimes the honest answer is no, and human input or different tools (replay debugging, distributed tracing instrumentation) is needed.

### Failure mode 2: confirmation loop

You have a hypothesis. Each test seems to confirm it slightly, never refutes it, but also never quite confirms. After 6 tests, you've gathered weak signals around your hypothesis but nothing that meets Iron Law.

The timebox forces the question: am I confirming, or convincing myself? If 6 tests haven't met Iron Law, the hypothesis is probably wrong (or incomplete).

## What "distinct hypothesis" means

Counting hypotheses requires honesty about what's actually different:

- "It's the validation logic" → "It's the validation logic, but specifically the null check" — same hypothesis, refined. Counts as 1.
- "It's the validation logic" → "It's the database query timing out" — different hypothesis. Counts as 2.

Refinement is part of testing one hypothesis. Switching hypotheses is what you count.

## What to do when the timebox is hit

Three options:

### Option 1: escalate to human-review

Best when:
- The bug is high-severity and ongoing
- Investigation has surfaced enough information that a human with deeper context can probably finish it quickly
- The remaining work needs tools or access debug doesn't have (e.g., production-only debugger, customer's environment)

```bash
bash route.sh $BUG_N human-review \
  --reason "investigation timebox exceeded; see investigation log in comments"
```

Comment with everything you've found so far — hypotheses tested, evidence gathered, ruled-out paths. Don't make the human start from scratch.

### Option 2: file an OPS task for instrumentation

Best when:
- The bug is intermittent and you suspect missing observability is the bottleneck
- Adding logs / traces / metrics to specific code paths would let the next investigation pin it down

```bash
bash actions/file-fix.sh \
  --bug-issue $BUG_N \
  --owning-role ops \
  --severity 3 \
  --report-file /tmp/instrumentation-task.md
```

The "fix" issue here is for OPS to add instrumentation, not to fix the bug. The bug stays open. When instrumentation lands and a new occurrence is captured, debug picks it up again.

### Option 3: escalate to arch-judgment

Best when:
- The bug seems to require architectural change to fix
- The investigation revealed an arch-ddd inconsistency

Judgment routes appropriately (probably to arch-shape if architecture mode is needed).

## Anti-pattern: "let me just try one more hypothesis"

Once you've hit timebox, escalating IS the productive next step. "One more" is the failure mode the rule prevents.

If new evidence arrives later (e.g., another occurrence with better data), the bug surfaces back to debug and you continue with that fresh evidence. That's a clean restart, not a continuation of the previous timebox.

## Tracking

The investigation log lives in the bug issue's comments. Each hypothesis you test should be commented:

```markdown
## Investigation: hypothesis 3 of 6

Tested: race condition between login flow and session refresh.

Method: ran the repro 100 times with a 50ms artificial delay injected
in the session refresh callback.

Result: refuted. Bug reproduces at the same rate with or without the
delay. The bug is not timing-related at this layer.
```

This makes the timebox visible (count comments tagged "Investigation:") and gives the next investigator (or human) a complete record.
