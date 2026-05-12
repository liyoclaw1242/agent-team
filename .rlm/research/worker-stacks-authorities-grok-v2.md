# Research Output — Worker Stack Authorities (Grok, follow-up)

> Source: independent re-run by Grok, supplementing the first pass.
> Key additions over v1:
>   - TS: Kent C. Dodds (Testing Trophy) — major addition
>   - C#: Mads Torgersen elevated to #1 (was missing in v1)
>   - Vercel: Guillermo Rauch added (Vercel CEO / Next.js creator)
>   - Cloudflare: Sunil Pai added (PartyKit / Agents SDK)
> Both Grok v1 and v2 are kept for paper trail / methodology comparison.

---

## Track: TypeScript

### Authoritative voices

#### 1. Anders Hejlsberg
- Role: Creator of TypeScript (and C#), Technical Fellow at Microsoft.
- Key works:
  - TypeScript design and interviews (GitHub Blog / YouTube)
  - TypeScript origin and scaling talk
- Characteristic pattern or opinion: Prioritizes fast feedback loops, incremental compilation, and scalability for massive codebases over language purity.
- Stance on type-driven / contract-first design: Strongly type-first; types are the primary contract for large-scale JS development, enabling safe refactoring and tooling.
- TDD posture: Types themselves act as a form of static verification (reducing some runtime tests); no strong public advocacy for classic TDD but emphasizes developer velocity through static safety.
- Why authoritative (not just popular): Literally invented TypeScript at Microsoft; shaped its core type system and compiler from day one.
- One non-obvious thing they believe that we'd miss without them: TypeScript's self-hosting in JS (and recent Go port experiments) prioritizes developer iteration speed and ecosystem integration over raw runtime performance — types must never slow you down.

#### 2. Matt Pocock
- Role: TypeScript educator (Total TypeScript), former Vercel Dev Advocate and XState core team member.
- Key works:
  - Total TypeScript workshops
  - TDD skill for Claude Code / testing philosophy
  - "Testing in TypeScript SUCKS - let's make it better" (YouTube)
- Characteristic pattern or opinion: Deep type manipulation and "wizard-level" patterns that make complex libraries feel simple; types should drive architecture.
- Stance on type-driven / contract-first design: Extreme — use the type system aggressively for contracts; "do not test what the type system already guarantees."
- TDD posture: Classic red-green-refactor with strong emphasis on behavior/public-API tests only (survives internal refactors); rejects implementation-coupled tests. Uses types-as-tests heavily.
- Why authoritative (not just popular): Ships production-grade libraries and teaches the undocumented patterns the TS team and library authors actually use.
- One non-obvious thing they believe that we'd miss without them: Tests should describe what callers care about (observable behavior), not how the code works internally — pair this with exhaustive type narrowing for near-zero runtime test surface.

#### 3. Kent C. Dodds *(new in v2)*
- Role: Creator of the Testing Library family (React Testing Library et al.), Epic React / Testing JavaScript instructor; dominant voice in modern JS/TS testing.
- Key works:
  - The Testing Trophy and Testing Classifications
  - Write tests. Not too many. Mostly integration.
  - When I follow TDD
- Characteristic pattern or opinion: Tests must resemble how the software is actually used; prioritize user confidence over isolated implementation details.
- Stance on type-driven / contract-first design: Treats strong static typing (TS) as the cheapest, highest-ROI layer of the Testing Trophy — types + integration tests together form the ideal contract.
- TDD posture: Practices pragmatic red-green-refactor when it fits; strongly prefers the Testing Trophy model (static analysis + integration/E2E > heavy unit mocks). Closer to Detroit/classicist school than pure London/mockist.
- Why authoritative (not just popular): His Testing Library fundamentally reshaped how the entire JS/TS/React ecosystem tests components and apps (behavior-over-implementation is now the de-facto standard).
- One non-obvious thing they believe that we'd miss without them: "Not too many" tests — over-testing at the unit level is a trap; combine TS types with integration tests for dramatically higher ROI and maintainability.

#### 4. Colin McDonnell (colinhacks)
- Role: Creator of Zod (dominant TypeScript-first schema validation library).
- Key works:
  - Zod GitHub + docs
  - Designing the perfect TypeScript schema validation library (essay)
- Characteristic pattern or opinion: Runtime validation must be TypeScript-first with perfect static inference — no separate schema language.
- Stance on type-driven / contract-first design: Contracts live in the schema; runtime + static types are one unified truth.
- TDD posture: Schema acts as executable contract; pair with TDD by testing parse/validate behavior.
- Why authoritative (not just popular): Wrote the foundational library that the entire TS ecosystem now builds runtime validation around (Zod is de-facto standard).
- One non-obvious thing they believe that we'd miss without them: Generic inference in validation libraries is harder than it looks — Zod's design choices (e.g., `.parse` returning inferred type) make "types as tests" actually work at scale.

### Community TDD posture
TDD is respected and practiced in serious TS teams (especially with Vitest + React Testing Library), but often "type-augmented" rather than pure classic TDD. Types reduce test volume; the community leans behavior-focused (Kent C. Dodds Trophy) over mock-heavy (London school).

### Stack-native test tooling consensus
Vitest (native TS/ESM support, Vite speed) has largely displaced Jest for new projects; Playwright for e2e. Strict types + Vitest snapshots/property-based testing where applicable.

### Synthesis for Worker `web-stack` skill targeting this stack

- Treat the type system as the first line of defense — generate exhaustive narrowing and branded types before writing implementation.
- Enforce "types at boundaries, looser inside" (Matt Pocock / Anders); combine with Kent C. Dodds' Testing Trophy for integration-first tests.
- Use Zod/Valibot for runtime contracts that perfectly infer types.
- Anti-patterns: Testing implementation details or what types already guarantee (Matt Pocock + Kent C. Dodds); over-using `any` or disabling strict mode (entire TS team).
- Specific test-first workflow shape: Red-green-refactor via Vitest; write `.test.ts` first against public API + schema (integration style); run `vitest watch`; implement minimally; refactor only after green; use type guards as assertions.

### Top 3 reading list (priority order)

1. Kent C. Dodds — The Testing Trophy — Defines the modern, pragmatic TDD/testing posture the TS ecosystem actually ships.
2. Matt Pocock TDD skill / `tests.md` — Distills exactly how authoritative TS practitioners want tests written.
3. Zod design essay — Shows how to make runtime validation feel like native TypeScript.

---

## Track: C#

### Authoritative voices

#### 1. Mads Torgersen *(elevated to #1 in v2)*
- Role: Lead Designer of the C# language, Principal Architect on the .NET team at Microsoft (succeeded Anders Hejlsberg).
- Key works:
  - Introducing Nullable Reference Types in C# (.NET Blog)
  - "C# into the Future" talk
  - Multiple .NET Blog posts and Build talks on language evolution.
- Characteristic pattern or opinion: Evolutionary, pragmatic language design — add powerful features (nullable, records, pattern matching) with zero breaking changes and maximum productivity.
- Stance on type-driven / contract-first design: Nullable reference types are the biggest leap in contract enforcement since async/await; make nullability part of the type contract everywhere.
- TDD posture: Language features (nullable, source generators) are explicitly designed to make TDD and integration testing easier and less boilerplate-heavy; not a vocal TDD evangelist but enables it at scale.
- Why authoritative (not just popular): Current lead designer shaping C# 8–14+; directly responsible for the modern type system and language direction.
- One non-obvious thing they believe that we'd miss without them: Nullable reference types are "probably the most impactful feature of C# 8.0" — they fundamentally change how libraries and APIs are designed and tested.

#### 2. David Fowler
- Role: Distinguished Engineer at Microsoft, ASP.NET Core architect.
- Key works:
  - Minimal API Cheatsheet / prototypes (features that became .NET standards).
  - .NET Blog posts on minimal APIs and Aspire.
- Characteristic pattern or opinion: Minimal, composable APIs over ceremony; start simple and scale without breaking changes.
- Stance on type-driven / contract-first design: Strong nullable reference types + source generators for contracts.
- TDD posture: Supports TDD but favors integration-style tests for web APIs; xUnit preferred.
- Why authoritative (not just popular): Designed and ships the minimal APIs and core ASP.NET runtime that .NET 8+ teams actually use.
- One non-obvious thing they believe that we'd miss without them: Minimal APIs were prototyped as a gist — real innovation comes from throwing away MVC ceremony while keeping the same performance and testability.

#### 3. Jon Skeet
- Role: C# language expert, author of *C# in Depth*, Stack Overflow top C# answerer.
- Key works:
  - *C# in Depth* (book series)
  - Nullable Reference Types in C# 8 talk (GOTO 2019)
- Characteristic pattern or opinion: Deep, precise understanding of language semantics and how features interact.
- Stance on type-driven / contract-first design: Nullable reference types as the biggest C# 8 feature — treat nullability as part of the contract everywhere.
- TDD posture: Classic red-green-refactor with xUnit; types reduce test surface.
- Why authoritative (not just popular): Wrote the definitive book on modern C#; consulted by the language team.
- One non-obvious thing they believe that we'd miss without them: Nullable reference types change everything about EF Core models and library design — you must migrate incrementally with real discipline.

### Community TDD posture
TDD is mainstream in enterprise .NET but contested in web vs. library work; xUnit + minimal APIs make it very natural. Not fringe, but not universal default.

### Stack-native test tooling consensus
xUnit.net (most TDD-adherent, no shared state) over NUnit/MSTest; Moq or NSubstitute for mocks (when needed); EF Core in-memory or Dapper integration tests common.

### Synthesis for Worker `web-stack` skill targeting this stack

- Respect nullable reference types as non-negotiable contracts from day one (Mads Torgersen).
- Prefer minimal APIs + source generators over full MVC for new services (David Fowler).
- Choose Dapper for performance-critical paths, EF Core for complex queries.
- Anti-patterns: Ignoring nullable warnings or using MVC controllers by default (Fowler warns against ceremony); treating nullability as optional.
- Test-first workflow shape: Write xUnit facts/theories first against public minimal API endpoints or repo methods; use in-memory DB or test doubles; green → refactor.

### Top 3 reading list (priority order)

1. Mads Torgersen — Introducing Nullable Reference Types — The definitive contract-first mindset for modern C#.
2. David Fowler's Minimal API prototypes / blog — Shows exactly how the runtime team thinks about modern C# web services.
3. Jon Skeet Nullable Reference Types talk — The definitive guide to the biggest C# feature since async.

---

## Track: Go

### Authoritative voices

#### 1. Dave Cheney
- Role: Long-time Go practitioner, speaker, blogger (*Practical Go*).
- Key works:
  - Practical Go presentations
  - "Don't Just Check Errors, Handle Them Gracefully"
  - Absolute Unit (Test) talk
- Characteristic pattern or opinion: "Errors are just values" — treat them with the same care as data.
- Stance on type-driven / contract-first design: Interfaces for contracts; keep them small.
- TDD posture: Strong advocate — tests as first consumer of code; table-driven tests; favors integration-style over heavy mocking (Detroit/classicist school).
- Why authoritative (not just popular): His talks and blog define what "practical, maintainable Go" actually looks like in production.
- One non-obvious thing they believe that we'd miss without them: Error handling is not boilerplate — it deserves the same design attention as happy-path code.

#### 2. Rob Pike
- Role: Co-creator of Go (with Ken Thompson and Robert Griesemer).
- Key works:
  - Go Proverbs
  - Error handling and Go (Go Blog)
- Characteristic pattern or opinion: "Errors are values"; simplicity and orthogonality above all.
- Stance on type-driven / contract-first design: Small interfaces and explicit error returns as the contract.
- TDD posture: Go culture is test-first by convention (table-driven, golden files, fuzzing).
- Why authoritative (not just popular): Co-designed the language and its standard library idioms.
- One non-obvious thing they believe that we'd miss without them: Package layout should be flat and obvious; `cmd/`, `internal/`, and `pkg/` only when truly needed.

#### 3. The Go Team (Andrew Gerrand et al.)
- Role: Core Go contributors / blog authors.
- Key works:
  - *Effective Go*
- Characteristic pattern or opinion: Idiomatic Go favors explicitness, table-driven tests, and context cancellation for concurrency.
- TDD posture: Table-driven + property-based (fuzzing) over mock-heavy; London-school less common.

### Community TDD posture
TDD is the cultural default in serious Go teams — table-driven tests are everywhere. Not contested; it's how Go code is written.

### Stack-native test tooling consensus
`testing` package + table-driven tests + `cmp` (`google/go-cmp`) or `testify` for assertions; built-in fuzzing; minimal mocking (interfaces + real implementations preferred).

### Synthesis for Worker `web-stack` skill targeting this stack

- Enforce "errors are values" + `%w` wrapping everywhere (Dave Cheney / Rob Pike).
- Prefer channels + context cancellation over mutexes for concurrency.
- Flat package layout until scale demands `internal/`.
- Anti-patterns: Sentinel errors without wrapping, or heavy mocking (Dave Cheney warns against it).
- Test-first workflow shape: Write table-driven test first → `go test -run` → implement → `go test -fuzz` for edge cases.

### Top 3 reading list (priority order)

1. Dave Cheney's *Practical Go* — The bible of production Go.
2. Go Proverbs + Error handling blog — Core philosophy in one page.
3. *Effective Go* — Official idioms.

---

## Track: Vercel (Next.js + Vercel Postgres + Edge)

### Authoritative voices

#### 1. Guillermo Rauch *(new in v2)*
- Role: Creator of Next.js, CEO and co-founder of Vercel.
- Key works:
  - Next.js original creation and ongoing vision talks.
  - Vercel/Next.js Conf keynotes on App Router and Edge.
- Characteristic pattern or opinion: Full-stack React with server-first philosophy; make the web feel instant.
- Stance on type-driven / contract-first design: Full TypeScript integration as non-negotiable for Next.js.
- TDD posture: Practical test-first with Vitest + Playwright for routes/components.
- Why authoritative (not just popular): Invented Next.js and steers Vercel's entire product direction.
- One non-obvious thing they believe that we'd miss without them: The framework should hide complexity (no manual routing events) so developers focus on product, not plumbing.

#### 2. Tim Neutkens
- Role: Next.js Lead at Vercel, co-author/maintainer of Next.js.
- Key works:
  - Next.js Conf keynotes and App Router docs.
  - PodRocket interview on Next.js philosophy
- Characteristic pattern or opinion: Server Components and partial prerendering as the default mental model.
- Stance on type-driven / contract-first design: Full TypeScript support with App Router types.
- TDD posture: Test-first with Vitest + Playwright for components and routes.
- Why authoritative (not just popular): Co-authors the framework and ships every major release.
- One non-obvious thing they believe that we'd miss without them: The router doesn't expose events on purpose — philosophy over leaky abstractions.

#### 3. Lee Robinson
- Role: Vercel (product/engineering leadership), major Next.js advocate and educator.
- Key works:
  - Vercel/Next.js blog posts and talks on ISR, Edge, Postgres, streaming.
- Characteristic pattern or opinion: Edge-first, streaming, and developer experience above all.
- TDD posture: Practical TDD for full-stack apps.
- Why authoritative (not just popular): Ships real production patterns used by Vercel's largest customers.
- One non-obvious thing they believe that we'd miss without them: Partial Prerendering + ISR cadence turns static sites into dynamic apps without complexity.

### Community TDD posture
TDD is common but secondary to DX; integration/e2e with Playwright is the norm for Next.js apps.

### Stack-native test tooling consensus
Vitest + Playwright (or React Testing Library for components); Vercel Postgres/KV tested via integration.

### Synthesis for Worker `web-stack` skill targeting this stack

- Default to App Router + Server Components + Partial Prerendering (Tim Neutkens / Guillermo Rauch).
- Use streaming, ISR, and Edge intelligently (Lee Robinson).
- Anti-patterns: Client islands everywhere / over-hydration (Tim warns against it); treating Next.js as just another React SPA.
- Test-first workflow shape: Write Playwright/Vitest tests for routes and server actions first; implement; green → refactor with type safety.

### Top 3 reading list (priority order)

1. Next.js App Router docs / Tim Neutkens talks — Official philosophy from the people who ship it.
2. Lee Robinson Vercel blog posts on Edge + Postgres — Real-world deployment and performance patterns.
3. Guillermo Rauch keynotes on Next.js vision — Foundational thinking behind the framework.

---

## Track: Cloudflare (Workers + R2 + D1 + Durable Objects)

### Authoritative voices

#### 1. Kenton Varda
- Role: Principal Engineer and architect of Cloudflare Workers + Durable Objects (inventor of the core primitives).
- Key works:
  - Durable Objects: Easy, Fast, Correct — Choose three
  - Introducing Workers Durable Objects
  - Recent talks on Durable Object Facets and sandboxing.
- Characteristic pattern or opinion: Durable Objects as the correct primitive for stateful coordination — actors + co-located SQLite that make global apps feel local.
- Stance on type-driven / contract-first design: Web-standard APIs + TypeScript bindings; contracts via Durable Object interfaces.
- TDD posture: Practical integration testing with wrangler/Miniflare against real DO instances and durability guarantees.
- Why authoritative (not just popular): Designed and built the Workers runtime and Durable Objects model from the ground up.
- One non-obvious thing they believe that we'd miss without them: Think of the network as a single programmable computer; DOs let you choose "easy + fast + correct" simultaneously by colocating compute + storage.

#### 2. Sunil Pai *(new in v2)*
- Role: Principal Systems Engineer at Cloudflare (ex-React core, ex-PartyKit founder acquired by Cloudflare); Workers DX and AI agents lead.
- Key works:
  - Dynamic Workers / sandboxing AI agents
  - Personal blog posts on "Durable Objects are computers" and building agents on Workers.
  - Wrangler v2+ DX improvements.
- Characteristic pattern or opinion: Durable Objects as stateful "computers" that make serverless finally feel natural for real-time and agent workflows.
- Stance on type-driven / contract-first design: Web APIs + strong TS typing for Workers.
- TDD posture: Test-first against real bindings and DO instances; focus on observable behavior.
- Why authoritative (not just popular): Built key DX tooling (wrangler) and modern AI/agent patterns actually running on the platform.
- One non-obvious thing they believe that we'd miss without them: The future of serverless is stateful actors (DOs), not stateless functions + external DB.

#### 3. Josh Howard (Cloudflare DO/D1 team)
- Role: Senior Engineering Manager at Cloudflare (Durable Objects / D1).
- Key works:
  - Deep-dive talks on how Durable Objects and D1 actually work internally.
- Characteristic pattern or opinion: SQLite-in-DO for local-disk speed with global coordination.
- TDD posture: Test with Miniflare/wrangler; focus on real durability patterns.
- Why authoritative (not just popular): Ships and explains the core runtime primitives at scale.

### Community TDD posture
TDD via integration tests against real bindings (Miniflare/wrangler); practical and growing rapidly with AI/agent use cases.

### Stack-native test tooling consensus
Wrangler + Miniflare + Vitest; test Durable Objects as real actors with actual SQLite.

### Synthesis for Worker `web-stack` skill targeting this stack

- Treat Durable Objects as the source of truth for state/coordination (Kenton Varda / Sunil Pai).
- Use D1 for SQL, R2 for blobs, KV sparingly; respect Web API-only constraints.
- Anti-patterns: Treating Workers as stateless functions only (Kenton warns this misses the point of DOs); ignoring isolation and global consistency.
- Test-first workflow shape: Write tests that spin up real DO instances via wrangler/Miniflare first; implement behavior; green → refactor.

### Top 3 reading list (priority order)

1. Kenton Varda — Durable Objects: Easy, Fast, Correct — The foundational mental model for the entire platform.
2. Sunil Pai on Dynamic Workers and DOs as computers — Practical DX and AI-agent patterns.
3. Durable Objects deep-dive talks — How the primitives actually behave in production.

---

## Cross-stack patterns

- **Where do these authorities agree across stacks?** Types/contracts at boundaries (TS + C# + Go — Anders/Mads, Matt Pocock, Rob Pike/Dave Cheney), errors as values/explicit (Go + TS Zod + C# nullable), fast feedback and minimal ceremony (Fowler + Anders + Cheney), behavior-over-implementation tests (Kent C. Dodds Trophy + Dave Cheney table-driven + Matt Pocock).
- **Where do they disagree in instructive ways?** Mocking philosophy (Go/Dave Cheney and Kent C. Dodds favor real implementations / integration = Detroit/classicist school vs. historical London/mockist tendencies in some TS/React circles); TDD purity (Go table-driven default vs. TS type-augmented + Trophy model).
- **Anything one stack's authorities would want the others to adopt?** Go's "errors are just values" + table-driven tests would benefit every stack; C#/Mads + Fowler's minimal APIs + nullable contracts for Next.js/Workers routing; Kent C. Dodds' Testing Trophy (static + integration) for all typed languages; Cloudflare's Durable Objects coordination model for any multi-region system (Kenton Varda's "network is the computer").
