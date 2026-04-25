# Rule — Evidence Over Assertion

Every PASS or FAIL claim cites concrete evidence. "Verified" without evidence is not verification.

## Why this rule

The verdict comment is what people trust the implementation against. If the verdict says PASS but lacks evidence, future debugging starts with "did QA actually check this, or just rubber-stamp?". Trust in the system erodes; PRs become harder to review.

A small amount of evidence per AC is cheap to produce and changes "I trust QA's judgment" into "I can verify QA's judgment myself".

## What counts as evidence

Listed in roughly increasing strength:

### Manual click-through

> Evidence: clicked the cancel button on staging (staging.example.com); observed disabled state + spinner for ~400ms; final state showed cancellation toast.

Specifies environment, action, observation. Reproducible by another reader.

### Test name

> Evidence: TestCancelButton_LoadingDuringRequest passes (CI run #4521).

The test exists; it passes. Reader can navigate to the test, read what it asserts.

### CI run + test name

> Evidence: TestCancel_E2E_HappyPath passes in PR #501's CI run #4521. Snapshot diff of the modal matches expected.

Specifies which CI run; matters because flaky tests sometimes pass and fail.

### Specific log / metric

> Evidence: After triggering the cancellation, the `cargo.cancellation.completed` Datadog metric incremented within 2 seconds; trace ID abc123 shows the event publish step succeeded.

Specifies a numerical or log-based observation tied to the system's actual behaviour.

### Screenshot / video

> Evidence: see screenshot uploaded to the PR comment showing the disabled button state.

Strongest for visual / interaction concerns. Use when text description is ambiguous.

## What does NOT count as evidence

- "Looked correct" — not specific
- "Tests pass" — which tests? Did they cover this AC specifically?
- "Same as last time" — meaningless audit trail
- "Implementer claimed to verify" — relying on implementer's self-test alone defeats the point of QA
- "I trust the team" — trust is built on evidence, not asserted

## Tying evidence to AC

The structure is one-AC-to-one-or-more-evidence:

```markdown
- AC #1: cancel button shows loading state — ✓
  Evidence:
  - TestCancelButton_LoadingDuringRequest passes (component test)
  - Manual: clicked button on staging deployment; spinner visible ~400ms
  - Screenshot in PR comment
```

Multiple evidence sources are fine and strengthen the verdict. Single-source is OK if the source is strong enough.

## What if an AC can only be verified with multiple steps

Sometimes a single AC requires a sequence:

```markdown
- AC #5: cancellation publishes CargoCancelledEvent — ✓
  Evidence:
  - TestCancel_PublishesEvent passes (integration test verifies event bus mock receives the event)
  - Manual on staging: triggered cancellation, observed event consumer (tracking-svc) updated within 1.5s
  - Datadog: `cargo.cancellation.completed` metric incremented for the test cargo ID
```

Three pieces of evidence. The integration test handles the structural correctness, manual handles end-to-end propagation, metric confirms it actually flows.

## Evidence in FAIL verdicts

FAIL needs evidence too — specifically, evidence of HOW it fails:

```markdown
- AC #2: confirmation modal opens on click — ✗
  Evidence of failure:
  - Clicked the cancel button on PR's preview deploy
  - Browser console: "Uncaught TypeError: useModal is not a function"
  - Stack trace points at CancelButton.tsx:42
  - The expected test (TestCancelModal_OpensOnButtonClick) does not exist in the PR's test files
  Triage: fe (frontend implementation gap)
```

Vague FAIL evidence ("doesn't work") is just as bad as vague PASS evidence. Implementers need to know what to fix; without specifics, FAIL becomes "do it again" with no useful direction.

## Evidence in cannot-verify situations

If you can't gather evidence (environment unavailable, requires production data, etc.), the right path is Mode C feedback (`workflow/feedback.md`), not posting a verdict with weak evidence.

A verdict that admits "Evidence: implementer claims this works; couldn't verify locally" reads as the QA hadn't done their job. If you can't verify, say so via Mode C; arch decides whether to accept implementer's word, find a way to verify, or escalate.

## Anti-patterns

- **"All AC verified" without per-AC evidence** — fails this rule's spirit. Every AC line needs its own evidence.
- **Borrowing implementer's evidence wholesale** — the implementer's self-test is their own claim. QA's evidence should add an independent layer (you ran the tests, you clicked through, you read the metrics). Just paraphrasing the self-test gives no extra signal.
- **Overstating evidence strength** — "manually verified end-to-end" when actually only the local UI was clicked. If the upstream/downstream steps weren't observed, say so.
- **Evidence for the wrong AC** — pasting a test name that's relevant but doesn't actually cover this AC. The reader looks up the test, sees it tests something else, trust is broken.

## Calibration

Strong evidence > convenient evidence. If verifying an AC is hard (requires a flag, a specific user setup, a specific time of day), do the hard verification rather than skipping or weak-evidencing. The PR is the team's commitment; evidence is how that commitment becomes credible.
