# Case — Malformed intake

Hermes or a human files a request that, on read, turns out to be unworkable: contradictory, missing the success signal, or really two requests jammed together.

## Detection

Symptoms:
- Outcome and success signal contradict each other
- "Out of scope" includes something the outcome implies
- Multiple distinct outcomes in one request body
- Required field is empty or hand-wavy ("make it better")
- The request is actually a bug report mis-classified as business

## Anti-pattern: invent the missing pieces

Don't fill gaps from your own assumptions. Pretending the request is well-formed and shipping a decomposition based on guesses is the classic way to produce work that gets rejected at review.

## What to do instead

### If the request is contradictory or missing fields

1. Comment on the issue with **specific** questions:

```markdown
## arch-shape: clarification needed before shaping

Three things I need to confirm before decomposing:

1. The outcome states "users can cancel without engineering help" but
   the success signal mentions "cancellation completion rate above 70%".
   Are those the same thing? If they're separate goals, please file
   them as two requests.

2. "Out of scope: refund handling" — but cancellation in the middle of
   a billing cycle implies a pro-rated refund. Is that intended to
   stay manual?

3. Target audience: "all paid subscribers" — does this include trial
   users mid-trial?
```

2. Route the issue back to its source via `route.sh`:

```bash
bash route.sh "$N" hermes \
  --reason "clarification needed; see comment"
# or "human" if the source was source:human
```

3. Exit. The originator (Hermes or human) responds; the issue comes back to `agent:arch + status:ready` once they've answered.

### If the request is two distinct requests

Comment on the issue:

```markdown
## arch-shape: this is two requests

I see two outcomes here that have different stakeholders, success
signals, and likely different decomposition shapes:

- (1) ... — affects billing context
- (2) ... — affects identity context

I'll close this issue. Please file (1) and (2) as separate intakes.
```

Then close the issue via `gh issue close`. Don't attempt to decompose half of it.

### If the request is a bug mis-classified as business

Re-route to debug:

```bash
bash route.sh "$N" debug \
  --reason "intake misclassified — this is a bug report, not a business request"
```

The intake-validator workflow may also catch this if `<!-- intake-kind: business -->` is wrong; if it didn't, that's a validator bug to fix.

## Why we don't escalate to arch-judgment for these

`arch-judgment` is the escape hatch for things the dispatcher couldn't classify. A malformed-but-classified intake is something arch-shape **can** handle — by pushing it back to its source. Routing to judgment for malformed input would just shift the same "ask for clarification" to another LLM, wasting tokens.

## Track these patterns

If a particular kind of malformed intake recurs (e.g., Hermes consistently leaves the success signal vague), that's a signal to improve **the upstream**:
- Tighten the issue template
- Add validation rules to intake-validator
- Have a conversation with the team / Hermes operator

This is upstream feedback, not arch-shape's job to absorb forever.
