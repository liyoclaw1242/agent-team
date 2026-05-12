# Supervision is cross-cutting infrastructure, not a Bounded Context

Supervision observes all three BCs and routes alerts to Hermes. It has no domain language of its own — it speaks the language of whichever BC it is observing. Treating it as a BC would have forced a parallel vocabulary (e.g., `SupervisionTask` for what is already a Worker iteration), which would then need translation back to the real BCs. That is the textbook indicator that something is infrastructure, not a domain.

Supervision is the *observability* layer; it does not enforce invariants. Enforcement of constraints (access boundaries, Worker concurrency, retry budgets, triple-required calls, runaway protection) lives in the ADRs that own each constraint — see [ADR-0012](./0012-supervision-pure-observability.md) for the full responsibility split.
