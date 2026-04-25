# Domain Knowledge

The shared brain for the agent team. Every artefact here is the canonical reference for project structure: bounded contexts, ubiquitous language, service chain, business flows.

## Where this folder lives in production

When this skills repo is shared across multiple projects via Anthropic's user-level skills directory, the `domain/` content under `_shared/` is **template/example only** — placeholders that show what the structure looks like.

In an actual project repo, the team should maintain a real `arch-ddd/` (or equivalent) folder at the project root, containing the same structure with real content. ARCH specialists read from the project's `arch-ddd/`, not from `_shared/domain/`.

This split exists because:
- **`_shared/domain/`** ships with the skill set; defines the schema and provides illustrative examples.
- **`arch-ddd/`** lives in each project repo; contains real business knowledge.

## Schema

Every project's `arch-ddd/` (and the placeholder here) must contain:

```
arch-ddd/
  README.md                          ← Reading guide for agents (which artefacts they read)
  overview.md                        ← Tech stack + high-level architecture (replaces old arch.md)
  glossary.md                        ← Ubiquitous language: every domain term + its code-side spelling
  bounded-contexts/
    README.md                        ← Index of contexts with one-line descriptions
    {context-name}.md                ← One file per bounded context
  domain-stories/
    README.md                        ← Index of flows
    {flow-name}.md                   ← One file per significant business flow
  service-chain.mermaid              ← Mermaid sequenceDiagram or flowchart of the full service topology
```

## Read protocol — who reads what

Progressive disclosure: an agent only loads what its role demands.

| Agent | Loads |
|-------|-------|
| All agents during onboarding | `README.md` (this file) |
| `arch-shape`, `arch-judgment` | Everything |
| `fe-advisor`, `be-advisor` | `bounded-contexts/`, `glossary.md`, `service-chain.mermaid`, relevant `domain-stories/{flow}.md` |
| `fe`, `be`, `ops` implementers | Only the specific `domain-stories/{flow}.md` referenced in their issue |
| `qa`, `design` | `glossary.md`, relevant `domain-stories/{flow}.md` |
| `debug` | `service-chain.mermaid`, `glossary.md` |

This is enforced socially, not technically — but each skill's `workflow/*.md` instructs the agent which artefacts to load for which task.

## Write protocol — who writes what

**Only ARCH specialists write to `arch-ddd/`.** Implementer roles do not modify domain artefacts directly; if they observe drift, they include a `Drift noticed:` section in their PR or feedback that ARCH then propagates.

When `arch-shape` decomposes a request, if the request introduces a new concept (new entity, new external service, new flow), the artefact change is in the **same PR** as the task issues it spawns. This guarantees:
- New tasks reference an updated `glossary.md` / `bounded-contexts/`
- `service-chain.mermaid` reflects current reality at the time tasks are scoped

Discipline: artefact changes always link to the request issue that triggered them. This makes lineage explicit.

## Validation

A `validate/domain.sh` script (in arch-shape's validate/, not here) checks:
- `service-chain.mermaid` is valid mermaid syntax (mermaid CLI lints).
- Every term in `glossary.md` appears at least once in `bounded-contexts/`.
- Every bounded context has at least one domain story.
- `README.md` indices are not stale (every file referenced exists).

The validator is run by arch-shape before delivering decomposed tasks.

## Examples in this folder

The placeholder content under `_shared/domain/` uses **Eric Evans's Cargo Shipping** example from the original DDD book (2003). It's the canonical "Hello World" for DDD; useful to read even if your project is unrelated, because it shows the texture and depth expected of these artefacts.

If you've never seen the example before, read `examples/cargo-shipping/` first, then map the structure onto your own domain.
