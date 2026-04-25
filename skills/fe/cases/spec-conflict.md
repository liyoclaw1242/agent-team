# Case — Spec Conflicts with Codebase

The reality-check phase of `workflow/implement.md` flagged something. This case covers what to do.

## Worked example

Task #144 spec:

```markdown
[FE] Cancellation modal — open from /billing

## Acceptance criteria
- Click "Cancel" button on the subscription card opens the cancellation modal
- Modal uses the BillingActionConfirm primitive
- ...
```

Reality check:

```bash
# Does BillingActionConfirm exist?
grep -r "BillingActionConfirm" src/
# (no results)

# What's actually used for action confirmations?
grep -r "ConfirmDialog\|ActionConfirm" src/components/
# Returns: src/components/ConfirmDialog.tsx (used in 12 places)
```

The spec references a component that doesn't exist. The actual primitive is `ConfirmDialog`. Two possibilities:

1. The spec used a name from arch's mental model that doesn't match code
2. arch-shape was working from an older glossary entry

Either way, you cannot implement faithfully without resolving this.

## Phase 1: confirm the conflict

Before writing feedback, do one more check:

- Search the codebase across branches: maybe `BillingActionConfirm` exists on a feature branch
- Check recent merges: was a primitive renamed?
- Read the parent issue: maybe the parent's broader context implies which is right

```bash
git log --all --oneline --since "2 weeks ago" -- src/components/
# Look for renames
```

If no plausible explanation exists, the conflict is real.

## Phase 2: write feedback

```markdown
## Technical Feedback from fe

### Concern category
code-conflict

### What the spec says
"Modal uses the BillingActionConfirm primitive"

### What the codebase shows
- No component named BillingActionConfirm exists in src/
- The component used for action confirmations across the codebase is
  ConfirmDialog (src/components/ConfirmDialog.tsx)
- ConfirmDialog has 12 existing call sites; it's the established pattern

### Options I see
1. Use ConfirmDialog (the current primitive). Spec updated to match.
2. Create new BillingActionConfirm. Likely duplicates ConfirmDialog;
   would need justification for the divergence.

### My preference
Option 1. ConfirmDialog covers all the spec's described behaviour;
no reason to fragment.

### Drift noticed
arch-ddd doesn't mention either component, so no glossary update needed
(this is component-level, not domain-level).
```

```bash
bash actions/feedback.sh \
  --issue 144 \
  --feedback-file /tmp/feedback-144.md
```

The action posts the comment, routes to `agent:arch`, exits.

## Phase 3: wait

The issue is no longer yours. You go to your next poll.

When the issue comes back to `agent:fe`, read the new state:

- arch-feedback **accepted**: spec body now says "use ConfirmDialog primitive"; you proceed with that
- arch-feedback **countered**: spec stands; the rationale comment will explain why (perhaps "BillingActionConfirm is being introduced in a sibling task you don't know about"; you proceed with original spec, possibly with a deps marker added)
- arch-judgment **routed elsewhere**: rare

Whatever the new state, you start fresh from `workflow/implement.md` Phase 1. Don't carry assumptions from before.

## Variant: spec assumes a deprecated pattern

```markdown
## Technical Feedback from fe

### Concern category
over-prescription

### What the spec says
"Use the useStripeAction hook for the API call"

### What the codebase shows
useStripeAction was deprecated in PR #501 in favour of the more general
useMutation. All new payment-flow code uses useMutation. useStripeAction
still exists but its file has a deprecation comment.

### Options I see
1. Use useMutation (current standard); update spec
2. Use useStripeAction (per spec); add a "TODO: migrate" comment

### My preference
Option 1. Using deprecated patterns is an accepted anti-pattern that
costs us refactor cycles later.

### Drift noticed
None.
```

This is a clean case: the spec was right at some past point; the codebase has moved on. arch-feedback should accept (default-accept rule) and update the spec.

## Variant: spec assumes a service that doesn't exist

```markdown
## Technical Feedback from fe

### Concern category
code-conflict

### What the spec says
"Display the user's last login time, fetched from the AuthHistory service"

### What the codebase shows
- No AuthHistory service exists
- Auth events are logged to a generic "events" table but no API
  surface exposes them to FE
- The /me endpoint returns no last-login field

### Options I see
1. File this as blocked; BE needs to expose auth history first.
2. Defer the last-login display to a follow-up; ship the rest.
3. Check if AuthHistory was scoped in a sibling task I missed.

### My preference
Option 3 first (dispatcher may have routed me too early; let me
verify all sibling tasks are merged). If no AuthHistory task exists,
Option 1 — deps on a new BE task.
```

This is the case where the spec assumes infrastructure that arch-shape forgot to decompose. arch-feedback may accept by adding a sibling BE task and a deps marker.

## Anti-patterns

- **Implementing a partial solution and noting "TODO: spec didn't account for X"** — that's not feedback, it's smuggling unfinished work past the gate. Stop and route back.
- **Implementing the literal spec while quietly knowing it's wrong** — silent compliance is the worst path. The PR may pass review but the bug is shipped.
- **Pre-debating the feedback in your head** — "but maybe arch knows something I don't, let me try harder". You can't read minds. Ask.
