# Workflow — Investigate

Single-pass investigation per pickup. If the timebox exhausts before root cause is confirmed, escalate; don't loop here indefinitely.

## Phase 1 — Read intake

Required:
1. The bug issue body (from `bug-report.yml` template) or alert payload
2. All comments — sometimes the originator added context after filing
3. Any prior investigation comments — if this issue has been picked up before by a previous debug agent, their notes are valuable

For `source:alert`:
4. The `<!-- alert-id: ... -->` marker — fetch the alert details from the observability platform (Datadog / Sentry / Grafana, depending on the project)
5. Linked traces, dashboards, or runbooks

## Phase 2 — Reproduce

For `source:human` bugs with reproduction steps:

1. Try the steps in the lowest environment that exhibits the bug (local → staging → prod, prefer earlier)
2. Confirm "actual" matches what was reported
3. If you can't reproduce: skip to `cases/cannot-reproduce.md`

For `source:alert`:

1. Find the trace / event the alert fired on
2. Identify the failing code path from the stack trace or instrumented spans
3. Check whether the failure is ongoing (if not, treat as historical investigation; if yes, urgency is high)

For both:
- If you can reproduce, capture the reproduction recipe in your notes — it'll go into the fix issue's AC ("the test reproducing this should now pass").

## Phase 3 — Form hypothesis

Read enough context to form ONE hypothesis. Common starting points:

- **Stack trace** — where in the code does the failure surface?
- **Recent changes** — `git log --since "1 week ago" --oneline -- <suspect file>` often points right at it
- **Diff between expected and actual** — what would the code have to do for "actual" to be observed?

Write your hypothesis in one sentence. If you can't, you don't have one yet — gather more evidence.

## Phase 4 — Test the hypothesis

Run experiments to confirm or refute:

- Local repro with logging added at suspect points
- Targeted code reading: does the suspect path have the behaviour your hypothesis describes?
- Differential analysis: does the bug surface only under conditions consistent with your hypothesis?

If the hypothesis is **confirmed**: proceed to Phase 5.
If **refuted**: form a new hypothesis and repeat. Each repeat consumes timebox steps.
If you can't form a new hypothesis: see `rules/timebox.md`.

## Phase 5 — Write root-cause report

The structured report is what gets posted as a comment on the bug issue. Format:

```markdown
## Root cause report (debug)

### Reproduction
{Steps that reliably trigger the bug. For alerts, the trace ID or event reference.}

### Hypothesis confirmed
{One sentence describing the cause. No "might", no "probably" — confirmed cause.}

### Evidence
- {Specific log lines / trace data / git blame pointing at the cause}
- {File:line references}
- ...

### Why this happens
{Mechanism: what does the code actually do that causes the observed failure?
Be specific enough that a fixer reads this and knows what's wrong.}

### Suggested owning role
{fe / be / ops — whoever owns the failing code}

### Suggested approach (high-level only)
{Sketch of what fixing means. NOT prescriptive — just enough that the
fix-issue's spec can be written. The implementer picks the approach.}

### Severity confirmation
{Per the bug-report template severity. Adjust if investigation reveals
the bug is more / less severe than initially classified.}
```

This format is consumed by `actions/file-fix.sh` to populate the fix issue's body.

## Phase 6 — File the fix issue

```bash
bash actions/file-fix.sh \
  --bug-issue $BUG_N \
  --owning-role be \
  --severity 2 \
  --report-file /tmp/root-cause-report.md
```

The action:
- Creates a new issue with `source:arch` (because debug is an arch-family specialist), `agent:{role}`, `status:ready`
- Adds `<!-- bug-of: #BUG_N -->` to the new fix issue
- Adds `<!-- fix: #FIX_N -->` to the original bug issue
- Posts the root-cause comment on the bug issue
- Routes the bug issue to `status:blocked` with `<!-- deps: #FIX_N -->` so it auto-closes when the fix lands

## Phase 7 — Self-test

Before exiting:
- [ ] Bug issue has a root-cause report comment
- [ ] Fix issue exists with `bug-of` marker
- [ ] Bug issue has `fix` marker pointing to the new fix issue
- [ ] Bug issue is `status:blocked` with deps on the fix
- [ ] Severity in fix issue matches the report (which may differ from original tag if investigation revealed different severity)

If any check fails: don't exit. Either fix the inconsistency or, if you can't, escalate to arch-judgment with a handoff.

## Anti-patterns

- **Patching by guessing** — Iron Law violation. If you don't know the cause, don't suggest a fix.
- **Closing the bug yourself** — the bug stays open until the fix lands. `scan-complete-requests.sh` handles closure.
- **Writing the fix in the report** — implementation details belong to the implementer. Suggested approach is high-level only.
- **Indefinitely looping** — see `rules/timebox.md`. Escalate when stuck.
