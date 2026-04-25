# Cargo Shipping (DDD example)

Eric Evans's classic Cargo Shipping example, restructured to match the `arch-ddd/` schema. Use this as a template when starting a real project's domain folder.

## Files

| File | What it is |
|------|------------|
| `overview.md` | Tech stack + 30-second domain summary |
| `glossary.md` | Ubiquitous language: every term + its code spelling |
| `bounded-contexts/` | One file per context (Booking, Routing, Handling, Tracking) |
| `domain-stories/` | Concrete end-to-end flows |
| `service-chain.mermaid` | Sequence diagram of the full system |

## How to use as a template

When starting a real project's `arch-ddd/`:

1. Copy the structure (folder layout) but not the content.
2. Run an event-storming session (or DDD discovery workshop) with the team.
3. Identify your bounded contexts; write a 1-page `.md` for each.
4. Write your glossary as you go — every domain term appearing in two places gets an entry.
5. Pick 2-3 most important business flows; write them up as domain stories.
6. Draw your service chain in mermaid; check it into the repo.

The key discipline: **the artefacts ARE the model**. If a developer adds a new entity in code without it appearing in the glossary, that's a bug to fix in code (or in the glossary if the team agrees the new term is real). Drift between code and these documents is the most common DDD failure mode; the agent team's `arch-shape` workflow has explicit checks against it.

## Why Cargo Shipping?

Eric Evans uses this example throughout the original DDD book. Three reasons it's a good template:

1. The domain is non-trivial (multiple bounded contexts, async events, anti-corruption layers) but easy to grasp without industry knowledge.
2. It's been studied for two decades — there are reference implementations in many languages, blog posts, and books building on it. If your team has read DDD literature, this maps onto things they've seen.
3. The contexts are clearly differentiated and the boundaries are well-justified — useful for showing what "good" boundaries look like.

If your domain is wildly different (e.g., fintech, healthcare, ML platform), the *structure* of the artefacts still applies, just the content varies.
