# Dispatcher Decision Table

Canonical reference for what `dispatcher.sh` does. Every routing decision is one of these rules; `classify()` in `dispatcher.sh` is a direct translation of this table.

## Inputs

For each issue with `agent:arch + status:ready`:
- **labels** — space-separated label names
- **body** — raw markdown including HTML comments
- **intake-kind** — extracted from `<!-- intake-kind: ... -->` via `issue-meta.sh get`

## Decision rules (top-down, first match wins)

| # | Condition | Route to | Reason |
|---|-----------|----------|--------|
| 0 | Body contains `Technical Feedback from {role}` | `arch-feedback` | Post-impl pushback overrides intake classification |
| 1 | `intake-kind` ∈ {`qa-audit`, `design-audit`} | `arch-audit` | Audit findings need decomposition into fix tasks |
| 2 | `intake-kind` = `business` | `arch-shape` | Business request needs shaping |
| 3 | `intake-kind` = `architecture` | `arch-shape` | Architecture request needs ADR + shaping |
| 4 | `intake-kind` = `bug` | `arch-judgment` | Bugs should arrive on `agent:debug`; if on `agent:arch`, escalate |
| 5 | None of the above match | `arch-judgment` | Escape hatch |

## Why feedback overrides intake-kind

An issue starts life with `<!-- intake-kind: business -->` (set by the issue template). After arch-shape decomposes it, the resulting child issues go to FE/BE. If FE detects a spec conflict and writes `Technical Feedback from fe-agent: ...` in the comment thread (later promoted into the body), the issue is pushed back to `agent:arch + status:ready`.

At this point, the **original intake-kind is misleading** — the issue is no longer a fresh business request, it's pushback that needs Mode C handling. Hence rule 0 fires before rules 2/3.

## Why intake-kind=bug routes to judgment

Bugs are filed via `bug-report.yml`, which sets `agent:debug`, not `agent:arch`. If a bug somehow lands on `agent:arch`, that means either:
- a human / Hermes mis-labelled it
- some routing went wrong upstream

Either way, this is a "weird state" — judgment investigates. Once judgment confirms it really is a bug, it routes to `agent:debug` with `--reason "rerouted from arch-judgment".

## Reading order

A new operator should read in order:
1. `LABEL_RULES.md` (top-level) — defines label semantics
2. This file — defines dispatcher routing
3. `dispatcher.sh` — sees the table as code

A change in dispatcher behaviour requires updating both this file and `dispatcher.sh` in the same PR. The test fixture at `test-fixtures/test-classify.sh` should grow a case for the new rule.

## Mapping from LABEL_RULES.md

LABEL_RULES.md has a 9-row table covering both intake-side (this file's scope) and post-implementation (pre-triage.sh's scope). The relationship:

| LABEL_RULES.md rule | Handler |
|----------------------|---------|
| Rules 1, 2 (`source:arch + agent:role`) | `pre-triage.sh` directly routes — these issues never reach dispatcher |
| Rule 3 (`bug + agent:debug`) | Direct to debug, never reaches dispatcher |
| Rules 4, 5, 6 (intake-kind classification) | **Dispatcher's job** — covered by this file's rules 1–3 |
| Rule 7 (PR + verdict) | `pre-triage.sh` |
| Rule 8 (feedback) | **Dispatcher's job** — this file's rule 0 |
| Rule 9 (none of the above) | **Dispatcher's job** — this file's rule 5 |

Dispatcher only ever sees issues at `agent:arch + status:ready`. Other label combinations are pre-triage's responsibility.
