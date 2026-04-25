# Rule — Default Accept

When in doubt, accept the implementer's pushback. Counter only when you have a specific, explicit reason.

## Why this default

arch-shape decomposed the issue with whatever context it had at the time. The implementer:

- Has read more of the codebase, more recently
- Knows about in-flight work that may not be in arch-ddd yet
- Has empirical experience of which patterns work in this codebase
- Bears the cost of the spec being wrong (they have to rework)

These advantages compound. The bias toward accepting is **not weakness**; it's recognising where the local information lives.

## When to counter

Counter only when one of:

### Counter-reason 1: Global concern the implementer can't see

Example: FE wants to switch from `lodash.debounce` to `useMemo`-based debouncing because it's "more idiomatic". You know that 5 other components use `lodash.debounce` and a recent perf review chose this for a reason. The implementer doesn't have that visibility.

In this case the counter explains the global reason:
> Other components use `lodash.debounce` for consistency and to share a single bundle. Switching this one inverts that. If you have a strong case for migrating all of them, file a separate refactor issue. For this task, please use the existing pattern.

### Counter-reason 2: Pushback is asking for scope expansion

Example: BE's feedback says "while I'm in there, I should refactor the validation layer." The spec was about adding one endpoint; refactoring is out of scope.

> Refactor proposal noted. Please file as a separate issue. For this task, ship the endpoint first using existing validation patterns; we can revisit the refactor as its own decision.

### Counter-reason 3: Pushback is based on a misreading

Example: FE says "the spec says use React, but we're a Vue codebase." Reading the spec, it never said React; the implementer misread.

> Re-reading the spec: it says "the framework's standard async hook" — for this codebase, that's our internal `useAsync` from `@/lib`. Original spec stands; let me know if any specific phrasing is unclear.

### Counter-reason 4: Pushback contradicts arch-ddd

Example: BE says "I'll just call the Booking service directly from Tracking." But `service-chain.mermaid` shows Tracking subscribes to events from Booking, never calls directly.

> Direct call from Tracking to Booking is forbidden by service-chain (see `arch-ddd/service-chain.mermaid`). The cargo data needs to flow via the event the Booking service publishes. If we genuinely need synchronous data, that's an architecture-mode change — file an architecture intake.

## Note: counter is rarely the right move

In practice, you should accept ~85% of feedback. If you find yourself countering more than this, one of:

- Decomposition is consistently over-prescribing → arch-shape's spec discipline needs tightening
- Implementers are pushing back on routine spec → some friction is healthy, but >50% pushback rate suggests communication problem
- arch-feedback (you) is too defensive → bias check needed

Periodic review of feedback acceptance rate is a good observability signal even if no one acts on it immediately.

## When to neither accept nor counter — escalate

Sometimes the right answer is "neither side is wrong, but I can't decide unilaterally":

- The pushback reveals an arch-ddd gap that needs deliberate decision
- The pushback would change the parent's outcome (not just the child's spec)
- The pushback creates a new cross-context concern

Route to arch-judgment with rationale. That's not failure; that's appropriate use of the escape hatch.
