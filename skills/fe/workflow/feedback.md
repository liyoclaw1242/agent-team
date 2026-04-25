# Workflow — Feedback (Mode C)

When the spec doesn't fit codebase reality, the right move is **structured feedback back to arch**, not silent reinterpretation.

## When to switch to feedback path

Phase 2 of `implement.md` (reality check) flagged a problem. Specifically, one of:

- **Code conflict**: a file, function, or pattern the spec assumes does not match what's in the codebase
- **Missing AC**: spec lacks information you need to implement (no "how do we know it's done")
- **Over-prescription**: spec mandates an implementation choice that conflicts with the codebase's actual conventions
- **Wrong outcome**: you believe the spec is asking for the wrong thing entirely (rare; usually means you misread)

## Phase 1 — Confirm with codebase

Before writing feedback, verify your concern is real:

- For code conflicts: open the file. Find the actual current shape. Cite `file:line`.
- For missing AC: re-read the spec carefully — sometimes AC are buried in non-obvious places. If still missing, you're right.
- For over-prescription: confirm the codebase's actual convention with a quick `grep`.
- For wrong outcome: read the parent issue. Does the parent's outcome match what you think? If parent is also "wrong" by your read, that's an arch-shape concern, not arch-feedback's.

If after confirmation your concern stands, write feedback.

## Phase 2 — Write structured feedback

Use this exact format. The `Technical Feedback from fe` header line is what triggers dispatcher to route to arch-feedback:

```markdown
## Technical Feedback from fe

### Concern category
{code-conflict | missing-AC | over-prescription | wrong-outcome}

### What the spec says
{Quote or paraphrase the specific spec text in question.}

### What the codebase shows
{Cite file:line, function name, or pattern. Be specific.}

### Options I see
1. {option A — outcome focused}
2. {option B — alternative}
(or: "I don't see a path forward — please advise")

### My preference
{which option you'd pick if it were yours, with one-sentence rationale}

### Drift noticed (optional)
{If the codebase has drifted from `arch-ddd/`, note it here. arch-feedback may
update arch-ddd in the same round.}
```

Be concrete. arch-feedback will categorise this in its own workflow's Phase 3; the more concrete you are, the faster they can act.

## Phase 3 — Post comment, route back

```bash
bash actions/feedback.sh \
  --issue $ISSUE_N \
  --feedback-file /tmp/feedback-$ISSUE_N.md
```

The action:
1. Posts the feedback comment on the issue
2. Routes the issue to `agent:arch` with reason "Mode C feedback from fe"
3. Adds a journal entry recording the feedback round

After this, the dispatcher picks up the issue → sees "Technical Feedback from..." in body → routes to `arch-feedback`. arch-feedback decides accept/counter/escalate.

## Phase 4 — Wait

After `actions/feedback.sh`, the issue is no longer yours. Don't poll it; don't speculate about what arch-feedback will do. When (and if) the issue comes back to `agent:fe`, it'll be there because:

- arch-feedback **accepted**: spec was updated; you implement the new spec
- arch-feedback **countered**: spec stands; you implement the original (with the rationale comment they posted as context)
- arch-judgment **redirected**: rare; the issue went somewhere else entirely

In all cases, you read the latest issue state and start fresh from `implement.md` Phase 1. Don't carry assumptions from before the feedback round.

## Anti-patterns

- **"It's almost right, I'll just adjust it"** — silent reinterpretation. The spec exists for a reason; if you change it without arch knowing, you've introduced drift between spec and code that future reviewers won't catch.
- **Vague feedback ("this doesn't work")** — useless. Either you have specific evidence or you don't yet (in which case investigate before posting).
- **Feedback as venting** — feedback is structured because the receiver (arch-feedback LLM) is parsing it. Tone is professional, evidence is concrete.
- **Repeating yourself across rounds** — if you got countered in round 1, going at it again in round 2 with the same argument is what gets you to round 3 escalation. New evidence or a new angle, or accept and move on.

## Round limit awareness

The system enforces a 2-round limit before automatic escalation to arch-judgment. Be aware:

- Round 1 (`feedback-rounds: 1` after arch-feedback handles): your first pushback was processed
- Round 2 (`feedback-rounds: 2`): your second is the last
- Round 3+ would mean the issue lands in arch-judgment

If you've been countered twice and still believe the spec is wrong, the right move is **wait for arch-judgment** — your feedback's escalation handoff is what they'll read. Don't try to win round 3 by being more emphatic.
