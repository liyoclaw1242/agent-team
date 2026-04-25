# Workflow — Feedback (Mode C)

QA's Mode C is rarer than fe/be's because QA's contract surface is smaller. Common cases:

- **Test plan mode**: AC are too vague to derive test names; sibling contracts not published yet
- **Verify mode**: PR is unverifiable due to infrastructure / scope / quality issues you can't resolve

## When to switch to feedback

### Test-plan mode triggers

- Parent's AC say "performant" or "user-friendly" without measurable criteria
- A required sibling contract (BE's API contract, Design's spec) hasn't been published yet, and you'd be guessing
- Multiple parent ACs are mutually exclusive
- The flow being tested isn't documented in `arch-ddd/domain-stories/`

### Verify mode triggers

- The PR doesn't link to the issue (no `Refs: #N`); you can't tell if it's even the right PR
- The implementer's self-test record is missing entirely (against process, but happens)
- CI is red on infrastructure / flaky tests, not on actual code; you can't tell if the implementation is good
- Multiple PRs mention the same issue and disagree about what's being delivered
- A required deps task hasn't merged, but the issue is somehow at QA already

## Feedback format

Header is exactly `## Technical Feedback from qa` (dispatcher's regex contract):

```markdown
## Technical Feedback from qa

### Concern category
{vague-AC | missing-contract | unverifiable-pr | scope-confusion}

### What I needed to do
{briefly: write test plan / verify PR}

### What's blocking me
{specific evidence: which AC is vague, which sibling task doesn't have its contract,
which PR linkage is broken}

### Options I see
1. {what could resolve this}
2. ...

### My preference
{which option, with one-sentence rationale}
```

## Phase: post and route

Same as fe/be:

```bash
bash actions/feedback.sh \
  --issue $ISSUE_N \
  --feedback-file /tmp/feedback-$ISSUE_N.md
```

Issue routes to `agent:arch`. Dispatcher → arch-feedback → decision.

## Common patterns

### Pattern 1: vague AC at test-plan time

```markdown
## Technical Feedback from qa

### Concern category
vague-AC

### What I needed to do
Write test plan for parent #142 (cancellation flow).

### What's blocking me
- AC #6 says "the cancellation experience should feel smooth"
- I cannot derive a test name from "feel smooth"
- Other AC are specific and testable; just this one is fuzzy

### Options I see
1. Drop AC #6 (it's not actually a testable requirement)
2. Replace with measurable: "modal opens within 100ms of click; transition under 200ms"
3. Replace with broader: "no console errors during the flow"

### My preference
Option 2. "Smooth" usually means perceived latency; making it numeric lets us verify.
```

This kind of feedback often results in the parent's AC being amended — that's not a re-shape, just AC clarification.

### Pattern 2: missing sibling contract at test-plan time

```markdown
## Technical Feedback from qa

### Concern category
missing-contract

### What I needed to do
Write test plan for parent #142.

### What's blocking me
- BE sibling task #143 has no contract block published yet
- Without the contract, I can't write tests against the API shape
- I'd have to guess — and if I guess wrong, the test plan misleads

### Options I see
1. Wait for #143's contract to publish; QA task picks up again after
2. Mark the API-related part of the plan TBD; deliver partial plan
3. Re-shape: add deps so QA blocks until BE publishes

### My preference
Option 3. The deps marker should have been on this issue from the start; flagging this as a process gap.
```

This catches an arch-shape oversight (the deps marker should have ordered tasks correctly).

### Pattern 3: unverifiable PR

```markdown
## Technical Feedback from qa

### Concern category
unverifiable-pr

### What I needed to do
Verify PR #501 against parent #142's AC.

### What's blocking me
- PR #501 doesn't reference issue #142 in body or commits
- Two PRs (#501 and #503) both claim to "implement cancellation"
- I can't tell which (if either) is the canonical implementation

### Options I see
1. Implementer should clarify which PR is the canonical one; the other is closed/rebased
2. arch-shape may have decomposed wrong (two implementers picked up the same issue?)

### My preference
Option 1. Implementer side has more context.
```

## Anti-patterns

- **Posting FAIL when you mean cannot-verify** — those are different. FAIL says "the implementation is wrong"; cannot-verify says "I can't tell". The triage routing is different.
- **Filing test-plan feedback after publishing a tentative plan** — pick one path. Either you publish a plan with confidence, or you flag and wait.
- **Mode C as a way to delay** — if the AC are genuinely fine and you just don't feel like writing the plan, that's not feedback territory.

## After feedback returns

If the issue comes back to QA after arch-feedback acts, read the new state and start fresh from `workflow/test-plan.md` or `workflow/verify.md` Phase 1. Don't carry assumptions from before the round.
