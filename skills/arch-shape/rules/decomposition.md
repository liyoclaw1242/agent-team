# Rule — Decomposition

Each task is **atomic and role-bounded**: one role, one PR, one merge.

## Atomicity criteria

A task passes atomicity if:

1. **Single role.** Exactly one of `agent:fe` / `agent:be` / `agent:ops` / `agent:design` / `agent:qa`. No "FE + BE" tasks.
2. **Independent merge.** The task can be merged without breaking main, even if other child tasks haven't merged yet. Use feature flags, schema additivity, or careful ordering to enable this.
3. **PR-sized.** Roughly: <500 lines added/changed, <2 days of work for the role. Tasks larger than this should be split.
4. **Verifiable in isolation.** QA can verify this task without needing N other tasks to be merged first.

## When a task feels too big

Split heuristics:

- **By layer**: schema → repository → service → handler → UI
- **By case**: happy path first, error cases later
- **By data**: implementation for one entity type, then another
- **By feature flag stage**: introduce flag (default off) → implement behind flag → enable for staff → enable for all

## Dependencies (deps marker)

When tasks depend on each other, declare the dependency:

```markdown
<!-- deps: #142, #143 -->
```

This puts the task in `status:blocked` until #142 and #143 are closed. `scan-unblock.sh` automates the transition.

Use deps for:
- API contract dependencies: FE task depends on BE task
- Schema dependencies: BE handler depends on schema migration task
- Sequencing requirements

Don't use deps as a way to ship a too-big task piecemeal. If your task only makes sense after 5 other tasks are merged, consider whether the parent should be reshaped.

## Number of tasks

Sweet spot: 2–6 tasks per parent decomposition.

- **1 task** is a code smell — why was this an arch-shape input rather than direct intake? Either it was misclassified, or you should split further.
- **>6 tasks** is also a smell — the request was probably too coarse. Consider whether to split the parent into multiple parents at higher level (e.g., epic → multiple shapeable requests).

## Don't decompose what you don't need to

If after reading the request, you realise the request is actually **already a single role's task** (e.g., "fix typo in /billing page" — pure FE), then:

1. Open one child issue (still goes through the standard pipeline — provenance label, parent marker)
2. Note in the parent comment why no further decomposition was needed

This is rare but legitimate. The parent issue still closes when the child closes (via `scan-complete-requests.sh`).

## Naming child issues

Child issue title format: `[{role}] {imperative outcome}`

- `[FE] Add cancel confirmation modal to /billing`
- `[BE] Cancellation endpoint with effective-date computation`
- `[Design] Spec the cancellation confirmation modal`
- `[QA] E2E test for cancellation happy path`

The role prefix is for the issue list scanability; the agent label is the source of truth for routing.
