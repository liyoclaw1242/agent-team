# Rule — Feedback Discipline

When you write Mode C feedback, the rules of engagement matter. The system depends on feedback being signal, not noise.

## Threshold to write feedback

Write feedback when, after reading carefully, **you cannot proceed faithfully** without arch's input. Specifically:

- Code conflict: the spec presupposes something untrue
- Missing AC: you don't know what "done" means
- Over-prescription: implementing literally would force an anti-pattern in the codebase
- Wrong outcome: you believe arch decomposed wrong (rare; confirm by reading parent first)

Don't write feedback for:

- "I'd prefer a different approach" without conflict — implement to spec
- "The spec is harder than I thought" — that's not feedback, that's work
- "I don't like this technology" — taste isn't feedback
- Aesthetic disagreements about UX choices already in spec — those go to design review, not feedback

## Strong feedback vs weak feedback

Strong feedback:
- Cites specific evidence (file:line, function name, deployed behaviour)
- States options with trade-offs
- Has a recommendation
- Is brief: 100-300 words usually enough

Weak feedback:
- "This won't work" with no evidence
- Long explanations of how the codebase generally is
- No recommendation; pure problem statement
- Multiple unrelated concerns mixed together

When in doubt, ask yourself: "if arch-feedback reads this, can they decide accept/counter in 60 seconds?" If yes, it's strong; if no, sharpen it.

## One issue, one feedback

Don't bundle multiple concerns. If you see two distinct problems with the spec:

- Pick the one that blocks you most
- Write feedback for that one
- Note the other briefly: "Separately, I notice X — willing to file follow-up if relevant"

This keeps each round of feedback focused. Bundling makes arch-feedback's accept/counter decision harder, since they may agree on one but not the other.

## Tone

The feedback comment will be read by arch-feedback (LLM specialist) for accept/counter decision, and by future humans reading the issue for context. Write professionally:

- Neutral phrasing: "the spec assumes X; the codebase shows Y"
- Not adversarial: avoid "the spec is wrong / mistaken / misguided"
- Acknowledge uncertainty: "I may be missing context here, but..."
- Concrete > abstract: file:line beats "the codebase"

This isn't politeness theatre. Adversarial tone produces adversarial responses; neutral tone gets you better decisions faster.

## Feedback after feedback

If arch-feedback countered your round-1 feedback, and you still believe you're right, **round 2 is the last chance**. Use it carefully:

- Have you addressed their counter-rationale? Don't just repeat round 1.
- New evidence, or new framing of existing evidence, helps.
- If you genuinely don't have new material, accept and implement — don't push for round 3 just to have the last word.

After round 2 the issue auto-escalates to arch-judgment. They read the full thread and rule. At that point your role is to wait, not advocate.

## Writing the comment

Use `actions/feedback.sh` which reads from a markdown file. Compose the file:

```bash
cat > /tmp/feedback-$ISSUE_N.md <<'EOF'
## Technical Feedback from fe

### Concern category
code-conflict

### What the spec says
"Reuse the BillingForm component to render the cancellation reason input."

### What the codebase shows
src/components/BillingForm.tsx is closed-for-extension as of PR #501;
its props are typed strictly to billing fields. Adding a "cancellation
reason" prop requires modifying the component itself.

### Options I see
1. Fork BillingForm into a new CancellationForm — small duplication but clean
2. Modify BillingForm to accept generic reason props — wider blast radius
3. Use a different component entirely (e.g., raw form with shared styles)

### My preference
Option 3. The cancellation reason flow is small enough that a dedicated
form is cleaner than tangling with BillingForm.

### Drift noticed
None.
EOF

bash actions/feedback.sh \
  --issue $ISSUE_N \
  --feedback-file /tmp/feedback-$ISSUE_N.md
```

## Anti-patterns

- **"While I'm at it, here are 5 unrelated concerns"** — bundle = blur. One issue at a time.
- **Feedback as blame** — "this was poorly specified" doesn't help. State what's wrong, not whose fault.
- **Feedback then implement anyway** — pick one path. Routing to arch means waiting; staying to implement means ignoring the conflict you just flagged.
- **Vague "concerns"** — "I have concerns about scalability" is not feedback. Either you have concrete evidence or you don't.
