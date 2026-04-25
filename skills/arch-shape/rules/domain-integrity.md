# Rule — Domain Integrity

Tasks must not contradict `arch-ddd/`. If a request requires deviation, update `arch-ddd/` in the same PR — never leave a task that says "implement X" while the glossary says X means something else.

## What this rule prevents

- A task using a glossary term in the wrong sense
- A task implying a service interaction that's not in `service-chain.mermaid`
- A task adding a behaviour to a bounded context that contradicts the context's stated responsibilities
- A task introducing a new concept (entity, flow, integration) without updating glossary / contexts / service chain

## How to apply

For each candidate task, before opening the issue, verify:

1. **Term check.** Every domain noun in the task body either appears in `glossary.md` or is being added to it in this same PR.
2. **Context check.** The task's role + the surface it touches matches a documented bounded context. If a `agent:be` task says "modify cargo booking", verify Booking context's doc covers that surface.
3. **Chain check.** If the task adds, removes, or changes an interaction with another service, the `service-chain.mermaid` is updated in the same PR.
4. **Story alignment.** If a domain story exists for the affected flow, the task is consistent with it. If the task changes the flow, the story is updated.

## Anti-patterns

- **"This is a small task, the artefact change can come later."** No. Drift compounds: a backlog of unrecorded changes makes the next decomposition harder.
- **"The artefact is wrong, but I'll leave it for now."** Either fix the artefact in this PR (with a brief comment explaining the correction) or escalate to `arch-judgment` to decide whether the request itself needs reconsidering.
- **"Hermes used a wrong term, but I know what they meant."** Use the correct glossary term in the task. If the team term has shifted, update glossary explicitly.

## Validation

The arch-shape `validate/domain-integrity.sh` script runs:

```bash
# Every task's body has its domain nouns appearing in glossary
# (or in this PR's glossary diff)

# service-chain.mermaid is valid mermaid syntax (mermaid CLI lint)
# After a PR adds new service interactions, mermaid still parses.
```

A failing validator means: the deliverable is inconsistent. Don't ship it.
