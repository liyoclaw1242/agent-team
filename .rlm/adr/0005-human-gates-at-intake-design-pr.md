# Human gates at Intake confirmation, Design approval, and PR review

Humans are in the loop at exactly three gates: **IntakeConfirmation** (does the Spec capture what I want?), **DesignApproval** (do these WorkPackages add up to the right plan?), and **PR review** (does the code do what it should?). Between gates, the system runs autonomously.

## Why

Fully autonomous configurations propagate misunderstandings forward instead of resolving them. By the time a human sees a bad output, the cost of correction is multiples higher than catching it at the spec boundary — and Validators cannot help, because they validate fidelity to the Spec, not fidelity to human intent. The cited references (Factory Mirrors, Alvoeiro's "Actually Ships") keep humans at PR review for exactly this reason; we generalise the same logic to spec and design boundaries, where the misunderstanding-cost asymmetry is even sharper.

Each gate is designed to be cheap to clear: Hermes posts a structured summary to Discord with a default-approve timeout. The human cost per gate is targeted in seconds, not minutes — bottleneck risk is avoided by making gates async, not by removing them.

## Consequences

- The system cannot operate without a reachable human reviewer. This is a deliberate operating constraint, not a limitation to engineer around.
- Future versions may selectively remove gates based on accumulated data showing zero-error rates for a class of tasks. Until that data exists, no gate is removed.
- The "default-approve on timeout" behaviour requires Supervision to record every auto-approval as such, so post-hoc audit is possible.
