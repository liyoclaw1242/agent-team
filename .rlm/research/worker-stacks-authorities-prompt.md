# Research Prompt — Authoritative Voices for TS / C# / Go + Vercel + Cloudflare (TDD-flavoured)

## Context

We're building an "AI Agent-Team" — a system where an LLM-driven **Worker
agent** writes code based on WorkPackage specs handed to it by other LLM
agents (Hermes for design, Validators + Arbiter for verification). Worker
is generic; it composes "skills" from a configurable skill profile to do
its work. The first skill profile we're authoring is `web-stack`.

Before writing the actual skills (`scaffold-nextjs`, `db-migration-prisma`,
`e2e-test`, `error-handling-go`, etc.), we want to ground their content in
the opinions / patterns of **authoritative practitioners** for each stack
we'll commonly touch. We want skills that embody what the people who
*shaped* these stacks would actually do, not generic "best practices."

The development discipline across all stacks is **TDD**. Where the
community supports it, skills will enforce red-green-refactor with
stack-native tooling. Where the community has alternative test-first
postures, we want to know.

You are an independent researcher. Find the people whose ideas hold up
over time and distil their thinking into a form a future skill author
can act on.

## What to research (five tracks)

### Track 1: TypeScript

Production TS — type-system depth, narrowing, module structure, library
shape, error modelling, runtime validation (zod / valibot).

### Track 2: C#

Modern .NET 8+ — nullable reference types, source generators, async/await
idioms, channels, ASP.NET Core minimal APIs vs MVC, EF Core vs Dapper.

### Track 3: Go

Idiomatic Go — error handling (sentinel vs wrapped vs %w), concurrency
(channels-vs-mutex, context cancellation), test patterns (table-driven,
golden files, fuzzing), package layout (flat vs cmd/internal/pkg).

### Track 4: Vercel (Next.js + Vercel Postgres + Edge)

Practitioners shaping Next.js — App Router server components vs client
islands, ISR cadence, Vercel Postgres / KV usage, image optimisation,
streaming, partial prerendering, deployment idioms.

### Track 5: Cloudflare (Workers + R2 + D1 + Durable Objects)

Workers idioms — runtime constraints (Web APIs only), D1 + Durable
Objects durability patterns, Hyperdrive, Workers AI, Queues.

## Per-voice deliverable shape

For each authority you find (3-5 per track), produce:

- **Name** + role / employer / standing in the community
- **Top 2-3 pieces of their work** (book / blog / repo / video) — actual URLs
- **Characteristic pattern or opinion** (one sentence — what's distinctive about how they think?)
- **Stance on type-driven / contract-first design** (where applicable)
- **TDD posture** — do they practice / advocate TDD? In what shape?
  - Classic red-green-refactor?
  - Detroit vs London school (mock-heavy vs integration-first)?
  - Types-as-tests / property-based / snapshot?
  - Or do they reject TDD with a coherent alternative?
- **Why authoritative (not just popular)** — one or two sentences. "Created
  the language" / "ships the runtime" / "wrote the foundational library"
  beats "lots of followers".
- **One non-obvious thing they believe that we'd miss without them** — the
  thing that doesn't show up in generic "best practices" pages.

## Cross-cutting: TDD per track

After listing the voices, for each track produce:

- **Community TDD posture summary** — is TDD the default, fringe, or
  contested in this stack?
- **Stack-native test tooling consensus** — Vitest vs Jest in TS; xUnit vs
  NUnit in C#; testing + testify + cmp in Go; Playwright + Vitest in
  Vercel; Miniflare + Vitest in Cloudflare.
- **A Worker skill in this stack should enforce TDD via**: <one paragraph
  describing the test-first workflow Worker should follow>.

## Output format

Single markdown file with one section per track in this exact shape:

```
## Track: <stack name>

### Authoritative voices

#### 1. <Name>
- Role: ...
- Key works:
  - [<title>](<url>)
  - [<title>](<url>)
- Characteristic pattern: ...
- TDD posture: ...
- Why authoritative (not just popular): ...
- Non-obvious belief: ...

#### 2. <Name>
...

### Community TDD posture
- ...

### Stack-native test tooling consensus
- ...

### Synthesis for Worker `web-stack` skill targeting this stack

- 3-5 bullets distilling what the skill should respect / embody.
- Anti-patterns to avoid (cite which authority warns against).
- Specific test-first workflow shape (commands / file structure / ordering).

### Top 3 reading list (priority order, for a future skill author)

1. [<link>] — <one-line reason>
2. [<link>] — <one-line reason>
3. [<link>] — <one-line reason>
```

After the five tracks, end with a **Cross-stack patterns** section:

- Where do these authorities **agree** across stacks? (e.g., "types at boundaries, looser inside" appearing in TS + Go + C#)
- Where do they **disagree** in instructive ways? (e.g., mocking philosophy
  differs between Detroit-school Go folks and London-school TS folks)
- Anything one stack's authorities would want the others to adopt?

## Quality criteria

- "Authoritative" = work survives 5+ years; cited by other authorities;
  or holds a structural role (language designer, runtime team lead, the
  long-term maintainer of a foundational library). **Not** "lots of
  followers on Twitter / YouTube subs".
- Prefer **primary sources** (their own writing / talks / commits) over
  secondary commentary about them.
- Where opinions diverge inside a stack, **name the disagreement** rather
  than averaging it away. The disagreements are usually the load-bearing
  part.
- If a stack is dominated by official content (Microsoft Docs, Vercel
  Docs, Cloudflare Docs) and no individual stands out, **say so**
  explicitly — that's also data.
- For Vercel and Cloudflare specifically: the official DX team often *are*
  the authorities. Name the specific people behind the docs/blog posts,
  not just the brand.

## What NOT to include

- Generic "top 10 frameworks 2024" listicles
- Books older than 8 years unless the author is still active + still cited
- Sponsored / conference-marketing content
- AI-influencer hot takes without track record
- "Best practices" pages without an attributed author
- Tutorials aimed at beginners (we want the *opinionated* layer, not the introductory one)

## Time budget

~30-60 minutes per track. The **synthesis** section is the most valuable
output — don't shortchange it by chasing more names than you can usefully
process.

## Note about parallel runs

This prompt is being run in parallel by two researchers (Claude + Grok).
Their outputs will be cross-referenced. Focus on what *you* find —
overlap between researchers is signal (the canonical voices); divergence
is also signal (where research methodology surfaces different parts of
the community).
