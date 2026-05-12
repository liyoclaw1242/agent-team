# Research Output — Worker Stack Authorities (Grok)

> Source: independent research by Grok against `worker-stacks-authorities-prompt.md`.
> Captured verbatim; minor formatting cleanup only.

---

## Track: TypeScript

### Authoritative voices

#### 1. Anders Hejlsberg
- Role: Creator of TypeScript, Technical Fellow at Microsoft (also created C# and Turbo Pascal).
- Key works:
  - TypeScript design and interviews (GitHub Blog / YouTube)
  - TypeScript origin and scaling talk
- Characteristic pattern or opinion: Prioritizes fast feedback loops, incremental compilation, and scalability for massive codebases over pure language purity.
- Stance on type-driven / contract-first design: Strongly type-first; types are the primary contract for large-scale JS development, enabling safe refactoring and tooling.
- TDD posture: Types themselves act as a form of static verification (reducing some runtime tests); no strong public advocacy for classic TDD but emphasizes developer velocity through static safety.
- Why authoritative (not just popular): Literally invented TypeScript at Microsoft; shaped its core type system and compiler from day one.
- One non-obvious thing they believe that we'd miss without them: TypeScript's self-hosting in JS (and recent Go port experiments) prioritizes developer iteration speed and ecosystem integration over raw runtime performance — types must never slow you down.

#### 2. Ryan Cavanaugh
- Role: Principal Software Engineering Manager / Lead for the TypeScript team at Microsoft.
- Key works:
  - Talking TypeScript with the engineer who leads the team (Stack Overflow Blog)
  - TypeScript team releases and design decisions (e.g., Project Corsa/Go port discussions).
- Characteristic pattern or opinion: Pragmatic evolution of the type system to solve real-world JavaScript pain at enterprise scale while maintaining backward compatibility.
- Stance on type-driven / contract-first design: Types as the foundation for contracts; heavy emphasis on inference, narrowing, and library typing to make contracts self-documenting.
- TDD posture: Focus on static verification first; types catch what tests would otherwise need to assert at runtime.
- Why authoritative (not just popular): Day-to-day leader of the TypeScript compiler and language team; ships the runtime (compiler) and steers every major feature.
- One non-obvious thing they believe that we'd miss without them: The compiler must stay "self-hosted" and fast enough for massive monorepos — performance isn't optional; it's what keeps TypeScript viable at scale.

#### 3. Matt Pocock
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

#### 4. Colin McDonnell (colinhacks)
- Role: Creator of Zod (dominant TypeScript-first schema validation library).
- Key works:
  - Zod GitHub + docs
  - Designing the perfect TypeScript schema validation library (essay)
  - Total TypeScript interview on Zod design choices.
- Characteristic pattern or opinion: Runtime validation must be TypeScript-first with perfect static inference — no separate schema language.
- Stance on type-driven / contract-first design: Contracts live in the schema; runtime + static types are one unified truth.
- TDD posture: Schema acts as executable contract; pair with TDD by testing parse/validate behavior.
- Why authoritative (not just popular): Wrote the foundational library that the entire TS ecosystem now builds runtime validation around (Zod is de-facto standard).
- One non-obvious thing they believe that we'd miss without them: Generic inference in validation libraries is harder than it looks — Zod's design choices (e.g., `.parse` returning inferred type) make "types as tests" actually work at scale.

### Community TDD posture
TDD is respected and practiced in serious TS teams (especially with Vitest + React Testing Library), but often "type-augmented" rather than pure classic TDD. Types reduce test volume; the community leans behavior-focused over mock-heavy.

### Stack-native test tooling consensus
Vitest (native TS/ESM support, Vite speed) has largely displaced Jest for new projects; Playwright for e2e. Strict types + Vitest snapshots/property-based testing where applicable.

### Synthesis for Worker `web-stack` skill targeting this stack

- Treat the type system as the first line of defense — generate exhaustive narrowing and branded types before writing implementation.
- Enforce "types at boundaries, looser inside" (Matt Pocock / Anders).
- Use Zod/Valibot for runtime contracts that perfectly infer types.
- Anti-patterns: Testing implementation details or what types already guarantee (Matt Pocock); over-using `any` or disabling strict mode (entire TS team).
- Specific test-first workflow shape: Red-green-refactor via Vitest; write `.test.ts` first against public API + schema; run `vitest watch`; implement minimally; refactor only after green; use type guards as assertions.

### Top 3 reading list (priority order, for a future skill author)

1. Matt Pocock TDD skill / `tests.md` — Distills exactly how authoritative TS practitioners want tests written.
2. Total TypeScript workshops — Hands-on advanced patterns the community actually ships.
3. Zod design essay — Shows how to make runtime validation feel like native TypeScript.

---

## Track: C#

### Authoritative voices

#### 1. David Fowler
- Role: Distinguished Engineer at Microsoft, ASP.NET Core architect.
- Key works:
  - Minimal API Cheatsheet (prototypes that became .NET features).
  - .NET Blog posts on minimal APIs and Aspire.
- Characteristic pattern or opinion: Minimal, composable APIs over ceremony; start simple and scale without breaking changes.
- Stance on type-driven / contract-first design: Strong nullable reference types + source generators for contracts.
- TDD posture: Supports TDD but favors integration-style tests for web APIs; xUnit preferred.
- Why authoritative (not just popular): Designed and ships the minimal APIs and core ASP.NET runtime that .NET 8+ teams actually use.
- One non-obvious thing they believe that we'd miss without them: Minimal APIs were prototyped as a gist — real innovation comes from throwing away MVC ceremony while keeping the same performance and testability.

#### 2. Jon Skeet
- Role: C# language expert, author of *C# in Depth*, Stack Overflow top C# answerer.
- Key works:
  - *C# in Depth* (book series)
  - Nullable Reference Types in C# 8 talk (GOTO 2019)
- Characteristic pattern or opinion: Deep, precise understanding of language semantics and how features interact.
- Stance on type-driven / contract-first design: Nullable reference types as the biggest C# 8 feature — treat nullability as part of the contract everywhere.
- TDD posture: Classic red-green-refactor with xUnit; types reduce test surface.
- Why authoritative (not just popular): Wrote the definitive book on modern C#; consulted by the language team.
- One non-obvious thing they believe that we'd miss without them: Nullable reference types change everything about EF Core models and library design — you must migrate incrementally with real discipline.

#### 3. Mark Michaelis (with Microsoft MVP input on nullable)
- Role: Chief Technical Architect at IntelliTect, long-time Microsoft MVP, author on nullable.
- Key works:
  - *Essential .NET — C# 8.0 and Nullable Reference Types* (MSDN Magazine)
- Characteristic pattern or opinion: Pragmatic enterprise adoption of new language features.
- Stance on type-driven / contract-first design: Nullable as mandatory contract for production code.
- TDD posture: TDD-friendly; source generators pair well with test-first.
- Why authoritative (not just popular): Serves on Microsoft design review teams for C#, Azure, etc.

### Community TDD posture
TDD is mainstream in enterprise .NET but contested in web vs. library work; xUnit + minimal APIs make it very natural. Not fringe, but not universal default.

### Stack-native test tooling consensus
xUnit.net (most TDD-adherent, no shared state) over NUnit/MSTest; Moq or NSubstitute for mocks; EF Core in-memory or Dapper integration tests common.

### Synthesis for Worker `web-stack` skill targeting this stack

- Respect nullable reference types as non-negotiable contracts from day one.
- Prefer minimal APIs + source generators over full MVC for new services.
- Choose Dapper for performance-critical paths, EF Core for complex queries (Fowler's guidance).
- Anti-patterns: Ignoring nullable warnings or using MVC controllers by default (Fowler warns against ceremony).
- Test-first workflow: Write xUnit facts/theories first against public minimal API endpoints or repo methods; use in-memory DB or test doubles; green → refactor.

### Top 3 reading list (priority order, for a future skill author)

1. David Fowler's Minimal API prototypes / blog — Shows exactly how the runtime team thinks about modern C# web services.
2. Jon Skeet Nullable Reference Types talk — The definitive guide to the biggest C# feature since async.
3. *Essential .NET* on Nullable — Enterprise migration playbook.

---

## Track: Go

### Authoritative voices

#### 1. Dave Cheney
- Role: Long-time Go practitioner, speaker, blogger (*Practical Go*).
- Key works:
  - Real world advice for writing maintainable Go programs (GopherCon)
  - "Don't Just Check Errors, Handle Them Gracefully" talk
  - Absolute Unit (Test) talk
- Characteristic pattern or opinion: "Errors are just values" — treat them with the same care as data.
- Stance on type-driven / contract-first design: Interfaces for contracts; keep them small.
- TDD posture: Strong advocate — tests as first consumer of code; table-driven tests; favors integration-style over heavy mocking.
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
  - Table-driven tests and fuzzing in stdlib/testing.
- Characteristic pattern or opinion: Idiomatic Go favors explicitness, table-driven tests, and context cancellation for concurrency.
- TDD posture: Table-driven + property-based (fuzzing) over mock-heavy; London-school less common.

### Community TDD posture
TDD is the cultural default in serious Go teams — table-driven tests are everywhere. Not contested; it's how Go code is written.

### Stack-native test tooling consensus
`testing` package + table-driven tests + `cmp` (`google/go-cmp`) or `testify` for assertions; built-in fuzzing; minimal mocking (interfaces + real implementations preferred).

### Synthesis for Worker `web-stack` skill targeting this stack

- Enforce "errors are values" + `%w` wrapping everywhere.
- Prefer channels + context cancellation over mutexes for concurrency.
- Flat package layout until scale demands `internal/`.
- Anti-patterns: Sentinel errors without wrapping, or heavy mocking (Dave Cheney warns against it).
- Test-first workflow: Write table-driven test first → `go test -run` → implement → `go test -fuzz` for edge cases.

### Top 3 reading list (priority order, for a future skill author)

1. Dave Cheney's *Practical Go* — The bible of production Go.
2. Go Proverbs + Error handling blog — Core philosophy in one page.
3. *Effective Go* — Official idioms.

---

## Track: Vercel (Next.js + Vercel Postgres + Edge)

### Authoritative voices

#### 1. Tim Neutkens
- Role: Next.js Lead at Vercel, co-author of Next.js.
- Key works:
  - Next.js Conf keynotes and App Router docs.
  - PodRocket interview on Next.js philosophy
- Characteristic pattern or opinion: Server Components and partial prerendering as the default mental model.
- Stance on type-driven / contract-first design: Full TypeScript support with App Router types.
- TDD posture: Test-first with Vitest + Playwright for components and routes.
- Why authoritative (not just popular): Co-authors the framework and ships every major release.
- One non-obvious thing they believe that we'd miss without them: The router doesn't expose events on purpose — philosophy over leaky abstractions.

#### 2. Lee Robinson
- Role: Vercel (product/engineering), major Next.js advocate.
- Key works:
  - Vercel/Next.js blog posts and talks on ISR, Edge, Postgres.
- Characteristic pattern or opinion: Edge-first, streaming, and developer experience above all.
- TDD posture: Practical TDD for full-stack apps.

### Community TDD posture
TDD is common but secondary to DX; integration/e2e with Playwright is the norm for Next.js apps.

### Stack-native test tooling consensus
Vitest + Playwright (or React Testing Library for components); Vercel Postgres/KV tested via integration.

### Synthesis for Worker `web-stack` skill targeting this stack

- Default to App Router + Server Components + Partial Prerendering.
- Use streaming and ISR intelligently.
- Anti-patterns: Client islands everywhere (Tim warns against over-hydration).
- Test-first: Write Playwright/Vitest tests for routes first.

### Top 3 reading list (priority order, for a future skill author)

1. Next.js App Router docs / Tim Neutkens talks — official philosophy.
2. Lee Robinson Vercel blog posts — real-world Edge + Postgres patterns.

---

## Track: Cloudflare (Workers + R2 + D1 + Durable Objects)

### Authoritative voices

#### 1. Josh Howard
- Role: Senior Engineering Manager at Cloudflare (Durable Objects / D1).
- Key works:
  - How Durable Objects and D1 Work: A Deep Dive (YouTube)
- Characteristic pattern or opinion: Durable Objects as the coordination primitive; SQLite-in-DO for local-disk speed.
- Stance on type-driven / contract-first design: Web APIs + TypeScript bindings.
- TDD posture: Test with Miniflare/wrangler; focus on real durability patterns.
- Why authoritative (not just popular): Ships and explains the core runtime primitives.

#### 2. Cloudflare Workers/DO Team (via blog/docs)
- Key works:
  - Durable Objects docs
  - Mental model for Cloudflare storage (Jilles Soeters)

### Community TDD posture
TDD via integration tests against real bindings (Miniflare); practical and growing.

### Stack-native test tooling consensus
Wrangler + Miniflare + Vitest; test Durable Objects as real actors.

### Synthesis for Worker `web-stack` skill targeting this stack

- Treat Durable Objects as the source of truth for state/coordination.
- Use D1 for SQL, R2 for blobs, KV sparingly.
- Respect Web API-only constraints and global isolation.
- Test-first: Spin up real DO instances in tests.

### Top 3 reading list (priority order, for a future skill author)

1. Durable Objects deep dive with Josh Howard — How the primitives actually work.
2. Cloudflare storage mental model — Network-level thinking.

---

## Cross-stack patterns

- **Where do these authorities agree across stacks?** Types/contracts at boundaries (TS + C# + Go), errors as values/explicit (Go + TS runtime validation + C# nullable), fast feedback and minimal ceremony (Fowler + Anders + Cheney), behavior-over-implementation tests.
- **Where do they disagree in instructive ways?** Mocking philosophy (Go/Dave Cheney favors real implementations vs. London-school TS mocks); TDD purity (Go table-driven default vs. TS type-augmented).
- **Anything one stack's authorities would want the others to adopt?** Go's "errors are just values" + table-driven tests would benefit every stack; C#/Fowler's minimal APIs philosophy for Next.js/Workers routing; Matt Pocock's "don't test the type system" for all typed languages; Durable Objects coordination model for any multi-region system.
