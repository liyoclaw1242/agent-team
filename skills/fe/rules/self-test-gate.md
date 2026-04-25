# Rule — Self-Test Gate

Every FE delivery passes through `actions/deliver.sh`, which refuses to open a PR unless `/tmp/self-test-issue-{N}.md` exists with all AC checkboxes ticked. This is non-negotiable.

## What the gate checks

`actions/deliver.sh` runs these checks before pushing:

1. File exists: `/tmp/self-test-issue-{N}.md`
2. File contains a `## Acceptance criteria` section
3. Every line starting with `- [` in that section is `- [x]` (no unchecked boxes)
4. File contains a `## Ready for review: yes` line

Any failure → no PR opened, agent must fix or escalate.

## Why this gate

Without the gate, the failure mode is consistent:

- Agent implements 4 of 5 AC, calls it done, opens PR
- QA verifies, finds AC #5 missing, returns FAIL
- Agent re-opens PR, addresses #5, opens new PR
- Lost cycle: 1 day

With the gate:

- Agent must self-verify all 5 AC before PR opens
- The gate forces the agent to confront "have I really done #5?"
- Most often, this surfaces incomplete work before QA does

## What "verified" means in the self-test

Each AC line should have evidence. Compare:

❌ Useless:
```markdown
- [x] AC #1: button shows loading state
```

✅ Useful:
```markdown
- [x] AC #1: button shows loading state during request
  - Verified: clicked button in /billing, observed disabled state + spinner ~400ms
  - Verified: artificially slowed network in devtools, spinner persists for full duration
```

The "Verified:" lines tell the next reader (QA, reviewer, future you) **what you did to know AC was met**. Bonus: writing them often surfaces "wait, I didn't actually test that" thoughts.

## Common AC-check patterns

| AC type | How to verify |
|---------|---------------|
| Visible behaviour | Manually click through; record what you saw |
| Loading state | Network throttle; observe state during request |
| Error path | Mock a 4xx/5xx response; confirm UX |
| Keyboard/a11y | Tab through; use VoiceOver/NVDA briefly; axe scan |
| Edge cases | Empty data, very long data, special characters |
| Cross-browser | Chrome + Safari + Firefox at minimum |

For each AC, the verification method should match the AC's domain.

## When you can't fully verify

Sometimes an AC requires data you don't have locally (production-only state, integration with services that need staging). Note this honestly:

```markdown
- [x] AC #5: cancellation completion event emits to analytics
  - Verified locally: event emit code path executes; payload shape matches spec
  - NOT verified end-to-end: requires staging env with analytics consumer
  - QA should validate end-to-end on staging
```

This is honest and the gate accepts it (the box is checked because the work is complete; the limitation is documented). QA picks up the gap.

What's NOT acceptable:

```markdown
- [x] AC #5: cancellation completion event emits to analytics
```

…with no evidence at all. Fails the spirit of the gate even if it passes the literal check.

## Gate enforcement is mechanical

The deliver action does not LLM-evaluate the self-test record's quality. It checks:

- File exists
- Each AC line is `[x]`
- "Ready for review: yes" line present

A determined agent could write empty checkboxes everywhere and pass the gate. The gate is a **commitment ceremony**, not an inspection — the agent is signing off, in writing, that they did the work.

In a system with shift-left QA, the QA agent sees the self-test record and verifies the verifications. Lying in self-test is detected by QA; the gate is the prompt for honesty.

## Anti-patterns

- **"I'll write the self-test after the PR is merged"** — the gate prevents this; skirting it is failing the contract
- **Boilerplate self-tests** — copy-pasting the same checkboxes for every issue without varying evidence is a code smell QA notices and routes back as FAIL
- **Marking unchecked AC as `[x]` to pass the gate** — outright dishonest; the issue will FAIL QA review and the round-trip will reveal the lie

## Self-test record location

The convention `/tmp/self-test-issue-{N}.md` is per-machine and per-task. Specifically:

- The file lives on the same host as the agent
- It's not committed to the repo (`.gitignore` should include `/tmp/`)
- It's referenced in the PR description so QA can read it

For agent setups that don't have a writable `/tmp/`, override via `SELF_TEST_DIR` env. The deliver action respects that.
