# Workflow — Architecture Mode

Triggered when `<!-- intake-kind: architecture -->`. Input is a problem statement requiring a decision; output is an ADR plus tasks to implement.

The big difference from business mode: **the primary deliverable is a decision document**, not just tasks. The tasks come second, and they implement the recorded decision.

## Phase 1 — Read intake

Required:
1. Issue body (template fields: problem, alternatives considered, constraints, stakeholders, reversibility)
2. **Always:** all four files in `arch-ddd/` root + `bounded-contexts/`
3. `service-chain.mermaid` (architecture decisions almost always touch the chain)
4. Existing ADRs under `docs/adr/` (the new ADR will sit next to them)

## Phase 2 — Gates

Architecture intake almost always fails Gate 3 (cross-context impact). Brainstorm is the norm here, not the exception. Apply gates anyway — sometimes a request labelled `architecture` is really business + clear technical solution, and quick path is fine.

## Phase 3 — Brainstorm (typical for architecture mode)

Open consultations:

- Always `fe-advisor` and `be-advisor` (they know what current code can support)
- `ops-advisor` if the decision affects deployment, data, or security boundaries
- A `design-advisor` if user-facing flows change

Ask each advisor specifically about:
- Which alternatives are technically feasible from their context
- What constraints would the team's chosen alternative impose on their work
- What risks they'd flag

After advisors return, weigh inputs and prepare to write the ADR.

## Phase 4 — Write ADR

ADR location: `docs/adr/NNNN-{slug}.md` where NNNN is the next sequential number.

Required structure:

```markdown
# {NNNN} — {Title}

Date: YYYY-MM-DD
Status: Proposed
Deciders: arch-shape (after fe-advisor, be-advisor, ops-advisor consultations)
Refs: #{parent-issue}, #{consultation-issues...}

## Context

{Why this decision is needed. Pull from issue body's "Problem statement".
Add what advisors revealed about current constraints.}

## Decision

{The chosen option. State it positively: "we will X", not "we won't Y".}

## Consequences

### Positive
- ...

### Negative
- ...

### Neutral / future implications
- ...

## Alternatives considered

### Option A: {name}

Rejected because: {reason informed by advisor input}

### Option B: {name}

Rejected because: ...

## Reversibility

{Either "Two-way (rollback path: ...)" or "One-way (the following becomes hard
to undo: ...)"}.

## Implementation tasks

See child issues #N1, #N2, …
```

## Phase 5 — Decompose into tasks

Same as business mode `Phase 3`. Each task references the ADR by number in its body:

```markdown
Implements ADR-0023.
```

Cross-context architecture changes typically split as:

| Task | Role |
|------|------|
| Schema migration | `agent:be` |
| Contract update / shared types | `agent:be` (or shared lib if separate) |
| Consumer updates | `agent:fe`, `agent:be` (per affected service) |
| Deployment / config / DNS | `agent:ops` |
| Migration runbook | `agent:ops` |
| Verification plan covering rollback | `agent:qa` |

## Phase 6 — Domain artefacts

Architecture decisions almost always require domain updates:

- New service → update `service-chain.mermaid`
- New bounded context → new `bounded-contexts/{ctx}.md`
- Renamed concept → update `glossary.md` and add a "deprecation" line
- Changed flow → update relevant `domain-stories/{flow}.md`

The ADR + domain updates + child issue creation are **one PR**. This is the strongest correctness lever: reviewers see the decision, its rationale, and the resulting work in one place.

## Phase 7 — Deliver

Same as business mode. The parent issue closes; the ADR lives on and is referenced by every implementation task.

## Self-test gate

Before deliver:

- [ ] ADR file exists at `docs/adr/NNNN-{slug}.md`
- [ ] ADR has all required sections (Context, Decision, Consequences, Alternatives, Reversibility)
- [ ] ADR references advisor consultation issues by number
- [ ] Every implementation task references the ADR
- [ ] Domain artefacts updated and committed
- [ ] All child issues have correct labels and parent markers

If any check fails, escalate to `arch-judgment` rather than delivering an inconsistent decomposition.
