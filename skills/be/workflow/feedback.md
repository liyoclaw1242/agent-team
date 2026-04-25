# Workflow — Feedback (Mode C)

When the spec doesn't fit codebase reality. Same shape as FE's feedback workflow, but with BE-specific concerns.

## When to switch to feedback path

Phase 1 of `implement.md` revealed an issue. Common BE-specific cases:

- **Schema conflict**: spec assumes a column, table, or constraint that doesn't exist
- **Service chain drift**: spec implies an inter-service call not in `arch-ddd/service-chain.mermaid`
- **Migration impossibility**: spec implies a destructive change with no safe path
- **Bounded context violation**: spec asks BE to reach into another context inappropriately
- **Contract conflict**: spec implies a contract shape that conflicts with consumer expectations from other tasks

Any of these is grounds for Mode C. As with FE: confirm the issue is real (read code, check git log, verify your reading) before posting.

## Phase 1 — Confirm

Before writing feedback, verify:

- For schema conflicts: `\d table_name` in psql; check migrations folder for in-flight changes
- For service chain drift: read `arch-ddd/service-chain.mermaid`; if the spec's flow isn't on it and the spec implies it should be, note that
- For migration impossibility: think through the safe migration steps; if you can't construct a path, the spec's outcome may need rethinking
- For context violations: read `arch-ddd/bounded-contexts/{ctx}.md`; see what the context owns

If after confirmation the concern stands, write feedback.

## Phase 2 — Write structured feedback

Header is `## Technical Feedback from be` — exact match required.

```markdown
## Technical Feedback from be

### Concern category
{schema-conflict | service-chain-drift | migration-impossibility | context-violation | code-conflict | missing-AC | over-prescription | wrong-outcome}

### What the spec says
{Quote the specific spec text.}

### What the codebase / arch-ddd shows
{Concrete evidence: `\d table` output, file:line, mermaid diagram lines.}

### Options I see
1. {option A}
2. {option B}
(or "I don't see a path forward — please advise")

### My preference
{which option, with one-sentence rationale}

### Drift noticed (optional)
{If codebase has drifted from arch-ddd, note it here. arch-feedback may
update arch-ddd in the same round.}
```

## Phase 3 — Post and route

```bash
bash actions/feedback.sh \
  --issue $ISSUE_N \
  --feedback-file /tmp/feedback-$ISSUE_N.md
```

Same as FE's flow.

## Phase 4 — Wait

After feedback.sh, the issue is no longer yours. Don't poll, don't speculate. When/if it returns to `agent:be`, read the new state and start fresh from Phase 1 of `implement.md`.

## BE-specific feedback patterns

### Schema migration impossibility

The spec asks for a destructive change but there's no safe migration path:

```markdown
## Technical Feedback from be

### Concern category
migration-impossibility

### What the spec says
"Drop the `legacy_status` column from `subscriptions` table"

### What the codebase / arch-ddd shows
- legacy_status is referenced in 4 places (handlers, 1 background job, 2 reports)
- The reports query is run by an external scheduled job we don't control
- Production has 2.3M rows; a single ALTER TABLE DROP would lock for ~5min
- We have no expand-contract migration framework currently

### Options I see
1. Stay-with: ship a no-op migration; leave legacy_status as deprecated; mark for future cleanup
2. Multi-step: (a) update internal references to stop reading from it; (b) coordinate with external job owner; (c) drop in a later release
3. Soft-drop: rename to `legacy_status_deprecated_2026q2` first; observe for 2 weeks; then drop

### My preference
Option 2. The 4 internal callers can be updated this sprint; coordination with external owner takes longer but is necessary. Drop column in a separate later task.

### Drift noticed
None.
```

This is a case where arch-shape didn't appreciate migration cost — not arch-shape's fault, just a place where BE's local knowledge is essential. arch-feedback should accept and re-shape into multiple tasks.

### Service chain drift

```markdown
## Technical Feedback from be

### Concern category
service-chain-drift

### What the spec says
"On cancellation, call AccountService.notifyCancellation(userId)"

### What the codebase / arch-ddd shows
- AccountService is shown in service-chain.mermaid as receiving events from
  Booking via the event bus, NOT direct API calls
- Direct call from Booking to AccountService would violate the documented
  topology
- The event-based path exists: `CargoCancelledEvent` already exists in our event schema

### Options I see
1. Use the existing event path: emit CargoCancelledEvent, AccountService subscribes (already does for related events)
2. Update service-chain.mermaid to allow direct call (architectural change; needs ADR)

### My preference
Option 1. The event path matches existing topology and works for the case at hand.

### Drift noticed
None.
```

This kind of feedback prevents architecture decay — arch-shape's spec proposed a shortcut; BE catches and proposes the documented path.

### Context violation

```markdown
## Technical Feedback from be

### Concern category
context-violation

### What the spec says
"In the cancellation handler, also update the user's marketing-preference flag to disable churn-prevention emails"

### What the codebase / arch-ddd shows
- Marketing preferences live in the Marketing context, not Booking
- arch-ddd/bounded-contexts/booking.md says Booking publishes events; downstream contexts subscribe and act
- Updating Marketing's data from Booking handler couples them inappropriately

### Options I see
1. Booking publishes CancellationCompleted; Marketing subscribes and updates preferences as it sees fit
2. Move the marketing preference update to a separate task in Marketing context

### My preference
Option 1. This is the canonical event-driven decoupling pattern.

### Drift noticed
None.
```

## Anti-patterns

(All of FE's apply, plus BE-specific ones:)

- **Implementing the unsafe migration path because "the bug is critical"** — pressure shouldn't break Iron Law equivalents. Mitigation tasks for OPS instead.
- **Adding a temporary direct call between services and "leaving a TODO"** — service chain drift becomes permanent that way.
- **Implementing across context boundaries because "I'll refactor later"** — once shipped, it's much harder to extract.
