# Workflow — Business Mode

Triggered when `<!-- intake-kind: business -->`. Input is a business outcome; output is N role-ready tasks.

## Phase 1 — Read intake

Required reads:

1. The full issue body (template-shaped: outcome, motivation, success signal, scope boundaries, target user)
2. Any comments — Hermes or human may have added clarifications
3. **Always:** `arch-ddd/glossary.md`
4. **For Gate 1:** the relevant `arch-ddd/bounded-contexts/{ctx}.md`

Conditional reads (load only if relevant):

5. `arch-ddd/domain-stories/{flow}.md` if a specific flow is touched
6. `arch-ddd/service-chain.mermaid` if the request introduces or modifies inter-service communication

## Phase 2 — Classify (gates)

Run the three gates from `classify.md`. Either:

- All pass → continue Phase 3
- Any fail → switch to brainstorm path (`cases/brainstorm-flow.md`); after advisors return, resume here

## Phase 3 — Decompose

Goal: produce atomic, role-bounded tasks where each:

- Belongs to exactly one role (`agent:fe`, `agent:be`, `agent:ops`, `agent:design`, or `agent:qa` for shift-left test plans)
- Has clear acceptance criteria (5-10 bullets typical)
- Can be implemented in a single PR
- States dependencies on other child tasks via `<!-- deps: -->`

### Decomposition checklist

For each candidate task, verify:

- [ ] Single role can complete it without needing another role's code change
- [ ] AC are testable (each bullet maps to a check QA could perform)
- [ ] No vague directives ("make it nice", "consider performance")
- [ ] References to domain entities use glossary spelling
- [ ] If touching a bounded context, the relevant context doc is referenced in the task body

### Common shapes

| Shape | Typical task split |
|-------|-------------------|
| Customer flow with new UI | `agent:design` (specs first) → `agent:be` (API) → `agent:fe` (UI) → `agent:qa` (E2E test) |
| API change, no UI | `agent:be` (impl + migrations) → `agent:qa` (contract tests) |
| Internal tool / dashboard | `agent:fe` + `agent:be` parallel → `agent:qa` |
| New external integration | `agent:ops` (creds + DNS) → `agent:be` (client + handlers) → `agent:qa` |

These are starting points; the real shape depends on the request.

### When to add a Design task

Add `agent:design` as the first task when **any** of:
- The request introduces a new screen, modal, or distinct UI flow
- A change to copy / labels / errors that users see
- A change to colour / spacing / motion that has accessibility implications

Skip Design when:
- Pure backend work
- UI change is mechanical (replace icon library, rename existing button)

## Phase 4 — Domain artefacts

Before opening child issues, update `arch-ddd/` if:

- New entity → add to `glossary.md` with code-side spelling
- New bounded context → create `bounded-contexts/{ctx}.md`
- New cross-service call → update `service-chain.mermaid`
- New significant flow → write `domain-stories/{flow}.md`

These changes are part of the same git operation as creating child issues. Discipline: **the PR description links to the parent issue this update derives from.**

## Phase 5 — Open child issues

For each task:

```bash
bash actions/open-child.sh \
  --parent-issue "$PARENT_N" \
  --agent fe \
  --title "Add cancel button to /billing" \
  --body-file /tmp/task-body.md
```

The action handles:
- Prepending `<!-- parent: #N -->` and any `<!-- deps: -->` markers
- Setting `source:arch`, `agent:{role}`, `status:ready` (or `status:blocked` if deps)
- Returning the new issue number

## Phase 6 — Deliver

```bash
bash actions/deliver.sh \
  --parent-issue "$PARENT_N" \
  --children "#142,#143,#144" \
  --reason "decomposed from Hermes business request"
```

The action posts a parent comment summarising the decomposition (titles + assignees + link), then routes the parent to `status:done`.

## Self-test gate

Before deliver:

- [ ] Every child issue has all four labels (source/agent/status/intake-kind in body)
- [ ] Every child has parent marker matching this issue
- [ ] Glossary terms used in tasks match exactly
- [ ] If domain artefacts were updated, the update is committed in this same PR

Failing the self-test means: don't deliver. Fix or escalate to `agent:arch-judgment` with a comment explaining what's blocking.
