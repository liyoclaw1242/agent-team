# Research Output — Worker Stack Authorities (Claude)

> Source: independent research by Claude against `worker-stacks-authorities-prompt.md`.
> Captured verbatim; preserved structure.

---

# Authoritative Voices for the `web-stack` Skill Profile

**Audience:** future authors of skills like `scaffold-nextjs`, `db-migration-prisma`, `e2e-test`, `error-handling-go`.
**Goal:** ground skill content in the opinions and patterns of practitioners who shaped each stack, not generic best-practice pages. TDD posture is called out per voice and per track.
**Method:** for each track, 3–5 authoritative voices with key works, characteristic patterns, TDD posture, and one non-obvious belief; followed by a community TDD synthesis, a tooling consensus, a distillation for Worker, and a 3-item reading list. A final **Cross-stack patterns** section maps agreements and disagreements.

---

## Track: TypeScript

### Authoritative voices

#### 1. Anders Hejlsberg
- **Role:** Technical Fellow at Microsoft. Lead architect of TypeScript and original designer of C# (also Turbo Pascal, Delphi). Still active in TypeScript design decisions.
- **Key works:**
  - [The history of C# and TypeScript with Anders Hejlsberg (GitHub video)](https://www.youtube.com/watch?v=uMqx8NNT4xY)
  - [7 learnings from Anders Hejlsberg (GitHub Blog summary)](https://github.blog/developer-skills/programming-languages-and-frameworks/7-learnings-from-anders-hejlsberg-the-architect-behind-c-and-typescript/)
  - [TypeScript: Static Types for JavaScript (ITU lecture page)](https://cs-lectures.itu.dk/lectures/211123-hejlsberg-typescript.html)
- **Characteristic pattern:** Make the type system *feel* uncomplicated even when it's deeply complex; types should be a developer-experience layer, not a religion.
- **Stance on type-driven / contract-first design:** TypeScript exists to give large JS teams the tooling they were already faking with separate compilers; types are pragmatic and structural, not nominal. Strict superset of JS is non-negotiable; types must always be erasable.
- **TDD posture:** Does not advocate classic TDD. The implicit posture is *types-first*: the type checker is the fastest, most ever-present test you'll ever run. Static analysis and editor feedback substitute for many test cycles a Java/C# shop would write.
- **Why authoritative (not just popular):** He designed the language. Decisions about narrowing, structural typing, the `--strict` family, and (with Mads Torgersen) the conceptual ancestry of nullable reference types in C# trace directly to him.
- **Non-obvious belief:** Languages succeed by meeting users where they are, not by purity. TypeScript shipped as a JS superset *specifically* to lower adoption friction; that framing should shape any "TypeScript style" — the right style is whatever a working JS team can adopt incrementally.

#### 2. Daniel Rosenwasser
- **Role:** Principal Product Manager of TypeScript at Microsoft. He has held the PM role since around 2016, after starting as a developer on the team.
- **Key works:**
  - [TypeScript Dev Blog (author page)](https://devblogs.microsoft.com/typescript/author/danielrosenwasser/) — release notes are the canonical statement of how the language is *intended* to be used at each version.
  - [Announcing TypeScript 6.0 / 7.0 Beta posts](https://devblogs.microsoft.com/typescript/announcing-typescript-6-0/) — explains the rationale for the Go port (TypeScript 7) and the compatibility bridge.
  - [Interview on TypeScript History and Growth (Total TypeScript)](https://www.totaltypescript.com/bonuses/typescript-expert-interviews/typescript-history-and-growth-with-daniel-rosenwasser)
- **Characteristic pattern:** Long-game language stewardship — features ship only when they pull their weight in the type-checker and editor experience; quality-of-life often beats raw expressiveness.
- **Stance on type-driven / contract-first design:** Pro contracts at the boundary, but allergic to type-level gymnastics that don't help editor tooling. Pragmatic strict mode (`strict: true`) is the working default.
- **TDD posture:** Not a TDD advocate publicly; what he *does* advocate is treating the type-checker as the inner-loop feedback signal. He has been explicit that testing infrastructure ("evaluators") is becoming the central engineering activity in the AI era.
- **Why authoritative (not just popular):** He owns the roadmap. His blog posts are how Microsoft signals which patterns to lean on and which to abandon.
- **Non-obvious belief:** The next decade of software engineering will be more about building good evaluators (which are tests, essentially) than about writing implementation code — a TDD-adjacent stance arrived at from the language-tools side, not the agile side.

#### 3. Matt Pocock
- **Role:** Independent TypeScript educator; previously XState core team and Vercel DX. Author of *Total TypeScript* (book and course).
- **Key works:**
  - [Total TypeScript](https://www.totaltypescript.com/) — workshops on type transformations, generics, advanced patterns.
  - [`mattpocock` on GitHub](https://github.com/mattpocock) — includes his Claude skills directory ("Skills for Real Engineers"), which contains a published `tdd` skill alongside `grill-me` (code review) and `improve-codebase-architecture`.
  - [*Total TypeScript* (No Starch, with Taylor Bell)](https://www.amazon.com/Total-Typescript-Matt-Pocock/dp/1718504160) — the printed workshop.
- **Characteristic pattern:** *Editor-first* learning — let TypeScript's hover/error messages teach you the type system; favor `satisfies`, `as const`, and derived types over hand-maintained annotations.
- **Stance on type-driven / contract-first design:** Strongly type-driven. Derive types from runtime values where possible (`typeof`, `as const`). Treat `any` as a failure mode. Use generics to encode constraints, not to show off.
- **TDD posture:** He has published a `tdd` skill specifically for a TypeScript test-driven workflow, alongside skills for Socratic code review and architecture improvement. So he does advocate TDD, in a flavor compatible with type-driven design: write the type first, then a failing test, then the implementation. He's in the "Detroit-leaning, real-collaborators-where-cheap" camp — not heavy on mocking.
- **Why authoritative (not just popular):** He has trained the working TypeScript community more than any other single person; he's also worked as a library maintainer (XState), so his advice is tested against real public-API design.
- **Non-obvious belief:** Reading TypeScript's error messages is a *skill* you train deliberately. Most type frustration comes from never developing a mental model for what TS is telling you; "just use `any`" is a learned helplessness response, not a pragmatic shortcut.

#### 4. Colin McDonnell
- **Role:** Creator of [Zod](https://zod.dev/) (TypeScript-first schema validation) and author of the initial version of tRPC. Has worked as a developer relations engineer at EdgeDB/Gel and Bun.
- **Key works:**
  - [Zod (GitHub)](https://github.com/colinhacks/zod) — the de facto runtime-validation library for TS.
  - [Zod docs / release notes](https://zod.dev/v4) — substantive design essays accompany every major release.
  - [Designing the perfect TypeScript schema validation library (essay)](https://colinhacks.com/essays/zod)
- **Characteristic pattern:** *Parse, don't validate* — a schema is a parser from `unknown` to a typed value; if input doesn't fit, it never enters your typed world.
- **Stance on type-driven / contract-first design:** Contract-first at every untrusted boundary. One Zod schema becomes both the runtime validator and the static type via `z.infer<>`. Zod 4 introduces template literal types, recursive schemas without manual casts, and a `core` package designed as a substrate for other libraries.
- **TDD posture:** Not a public TDD advocate, but the design of Zod *implies* a test-first mentality at boundaries: you write the schema (which is a kind of executable contract), and the type and validation fall out together. This is closer to property-based / contract-driven testing than to red-green-refactor.
- **Why authoritative (not just popular):** He wrote the foundational library. Zod is downloaded ~10M times/week and is the validation layer of choice for Next.js, Vercel docs, AI SDKs, MCP tooling.
- **Non-obvious belief:** Validation libraries should be a *substrate* for other libraries, not application code. Zod 4 explicitly designed `zod/v4/core` as a low-level base so other schema libraries (form, AI structured-output, ORM-bridge) can build on the same primitives — your domain library shouldn't reinvent parsing.

### Community TDD posture
TDD is *fringe-to-contested* in TypeScript. The dominant posture is "types-as-tests" plus "parse at boundaries, trust inside" — exemplified by Pocock and McDonnell. Where teams do write tests, they often skip strict red-green-refactor and instead lean on: (a) the type-checker as continuous feedback, (b) Zod (or valibot) parsing at I/O edges, (c) Vitest in watch mode for behavioural assertions, (d) Playwright for E2E. Matt Pocock's published `tdd` skill is the main mainstream signal that classic TDD has a TS-native shape; outside it, most influential TS voices are post-TDD or TDD-agnostic.

### Stack-native test tooling consensus
- **Unit / integration:** Vitest is the modern default. Jest is legacy but still common.
- **Type tests:** `expect-type` or `tsd` for asserting on inferred types; Vitest has a built-in `assertType`.
- **Runtime validation at the edge:** Zod (canonical), valibot (lighter), arktype (more advanced inference). Treat as part of the test surface — a schema *is* a contract test.
- **E2E:** Playwright (Vercel-blessed) > Cypress.
- **Mocking:** `vi.mock` and msw for HTTP. Heavy mocking is culturally discouraged.

### Synthesis for Worker `web-stack` skill targeting this stack
- Enforce `strict: true` plus `noUncheckedIndexedAccess` in `tsconfig.json` by default. Pocock and the TS team treat this as the table stakes for production code.
- Generate Zod schemas at every external boundary (HTTP request bodies, env vars via `process.env`, third-party API responses) and use `z.infer<>` for the static type — never hand-write a parallel `interface` for the same data.
- Prefer `satisfies` over annotation, and derive types from `as const` runtime literals where possible (Pocock).
- Anti-patterns to avoid: `any` as an escape hatch (Pocock), hand-rolled type guards where a schema would do (McDonnell), validation libraries that don't infer types (McDonnell's foundational critique that led to Zod), starting projects without `strict` (Hejlsberg/Rosenwasser team default).
- **Test-first workflow shape:** for each new module — (1) write the function signature with no body, (2) write a Zod schema for any external input, (3) write a Vitest test that asserts the desired behaviour against the typed signature, (4) run `vitest --run` and confirm RED, (5) implement to GREEN, (6) refactor. For type-only changes, run `tsc --noEmit` as the test step.

### Top 3 reading list (priority order)
1. [Total TypeScript book](https://www.totaltypescript.com/) — fastest path from "I know TS" to "I think in TS." Pocock's editor-first method.
2. [Zod docs and the v4 release notes](https://zod.dev/v4) — the case for parse-don't-validate, plus the design rationale for runtime-static unification.
3. [TypeScript Dev Blog](https://devblogs.microsoft.com/typescript/) — Rosenwasser's release posts are the most authoritative source on "what TS is actually for."

---

## Track: C#

### Authoritative voices

#### 1. Mads Torgersen
- **Role:** Lead designer of the C# programming language and an architect on the .NET team at Microsoft. He joined Microsoft in 2005 from Aarhus University and took over from Hejlsberg as C# lead designer around the time of the TypeScript move.
- **Key works:**
  - [.NET Blog (author page)](https://devblogs.microsoft.com/dotnet/author/madst/) — definitive on records, nullable reference types, pattern matching.
  - ["Introducing Nullable Reference Types in C#"](https://devblogs.microsoft.com/dotnet/nullable-reference-types-in-csharp/) — the design essay that frames how to roll out NRTs.
  - [Interview with the C# Boss (DotNetCurry)](https://www.dotnetcurry.com/csharp/1455/mads-torgersen-interview) — explicit on TypeScript-as-inspiration for NRTs and the C# weekly LDM with Hejlsberg.
- **Characteristic pattern:** Make new features mesh with the existing language so they feel native; treat null safety, records, and pattern matching as a single pull *toward* a functional-friendly object-first language.
- **Stance on type-driven / contract-first design:** Strongly type-driven. Records give value-equality and immutability by default. NRTs make null explicit in the type system. Required members and primary constructors push toward "construct it valid or it doesn't compile."
- **TDD posture:** Torgersen does not publicly evangelise TDD; he optimises for *compile-time* correctness. The implicit message: lean on NRTs and records to push errors left, then test behaviour, not shapes.
- **Why authoritative (not just popular):** He drives the language design meetings. Every C# feature since C# 7 carries his fingerprints; the published [csharplang](https://github.com/dotnet/csharplang) design notes show this directly.
- **Non-obvious belief:** Nullable reference types should be analogous to TypeScript's strict null checks — a feature that *feels* trivial (just sprinkle `?`) but is engineering-deep underneath. The team explicitly modelled the rollout (off by default, then opt-in) on what worked for TS.

#### 2. David Fowler
- **Role:** Distinguished Engineer at Microsoft; ASP.NET Core architect. Co-creator of NuGet and SignalR; foundational work on Kestrel and the generic host.
- **Key works:**
  - [`davidfowl` on GitHub](https://github.com/davidfowl) — his repos function as a living textbook; the bedrock samples and async guidance are widely cited.
  - ["ASP.NET Core Architecture Overview"](https://speakerdeck.com/davidfowl/asp-dot-net-core-architecture-overview) — definitive on hosting, Kestrel transports, and the request pipeline.
  - [Async Guidance (gist)](https://github.com/davidfowl/AspNetCoreDiagnosticScenarios/blob/master/AsyncGuidance.md) — canonical do/don't list for async/await in production .NET.
- **Characteristic pattern:** Design for the *real* failure modes — deadlocks, sync-over-async, allocations on the hot path. Treat the framework as middleware over a pluggable transport, not a magic box.
- **Stance on type-driven / contract-first design:** Pro abstractions at boundaries (the `IServer`/`IConnectionListener`/`HttpContext` layering), but suspicious of premature interfaces. He's a frequent voice for "don't add an interface until you need a second implementation."
- **TDD posture:** Test-friendly by design rather than test-first by ideology. ASP.NET Core's `WebApplicationFactory` and `TestServer` exist precisely so you can integration-test the whole pipeline in-process. He pushes integration tests over deep unit tests for HTTP handlers.
- **Why authoritative (not just popular):** He architected the runtime you're using. If you write `app.MapGet` or `IHostedService`, you're working inside his design.
- **Non-obvious belief:** Minimal APIs are not just a beginner ramp — they're a sound long-term style for services where the request/response shape *is* the API. The MVC controller habit is often cargo culture.

#### 3. Stephen Cleary
- **Role:** Independent .NET developer and author; the most cited public voice on `async`/`await` and concurrency in C#.
- **Key works:**
  - [*Concurrency in C# Cookbook*, 2nd ed.](https://www.amazon.com/Concurrency-Cookbook-Asynchronous-Multithreaded-Programming/dp/149205450X) — the practical reference.
  - [blog.stephencleary.com](https://blog.stephencleary.com/) — long-running source for async patterns, including the "don't block on async code" posts.
  - ["Async and Await" introductory post](https://blog.stephencleary.com/2012/02/async-and-await.html) — still the cleanest mental model for the state machine.
- **Characteristic pattern:** Async-all-the-way-down. Use the right tool for the concurrency shape: async for I/O, dataflow/Rx for pipelines, Parallel/PLINQ for CPU-bound work. Don't reach for `Task.Run` to "make it async."
- **Stance on type-driven / contract-first design:** Pragmatic. Favors `IAsyncEnumerable<T>`, `CancellationToken` as a first-class parameter, and channels for producer/consumer.
- **TDD posture:** Doesn't lead with TDD, but his code is highly testable: async methods return `Task<T>`, dependencies pass via constructor, cancellation tokens are explicit. The Cookbook's recipe format implicitly encourages writing the test for "what happens on cancellation / what happens on faulted task" first.
- **Why authoritative (not just popular):** He filled a vacuum. When async/await landed in C# 5, the docs were thin; his recipes became the de facto reference and are still cited in StackOverflow answers and Microsoft talks.
- **Non-obvious belief:** Traditional synchronization primitives (lock, Mutex) do not compose with async. Most async deadlocks come from holding a sync lock across an `await`. The right answer is usually to *remove* the contention via dataflow or channels, not to invent a fancier lock.

#### 4. Jon Skeet
- **Role:** Staff Software Engineer at Google. Author of *C# in Depth*; ECMA C# convener; maintainer of Noda Time. Long-time Microsoft C# MVP.
- **Key works:**
  - [*C# in Depth*, 4th ed.](https://www.manning.com/books/c-sharp-in-depth-fourth-edition) — the deep-dive reference for C# 2–7.
  - [Noda Time](https://nodatime.org/) — his date/time library, used as a worked example throughout the book.
  - [Coding Blog (codeblog.jonskeet.uk)](https://codeblog.jonskeet.uk/) — extended reasoning on edge cases.
- **Characteristic pattern:** *Read the spec.* Skeet's distinguishing trait is reading language specifications literally and surfacing the corner cases everyone else gets wrong (overload resolution, generic variance, lambda capture, time zone math).
- **Stance on type-driven / contract-first design:** Strongly contract-first. Noda Time's public API is famously opinionated: you cannot accidentally mix instants, local date-times, and zoned date-times because the types refuse to compile.
- **TDD posture:** Practices TDD, but in a *Detroit-school* shape: state-based assertions, minimal mocking, integration-flavored tests where the cost is low. Noda Time has an extensive test suite that uses tabular fixtures (epochs, timezone transitions) rather than mocks.
- **Why authoritative (not just popular):** He is the ECMA C# convener, has been a top StackOverflow answerer for over a decade, and his book is the language reference even Microsoft engineers cite.
- **Non-obvious belief:** When the language lets you express a domain constraint in the type system, do it — even if it costs extra types. Noda Time has a deliberately larger type vocabulary than `DateTime` because mixing wall-clock and instant time is a category of bug, not a typo.

#### 5. Andrew Lock
- **Role:** Microsoft MVP; long-time ASP.NET Core practitioner; author of *ASP.NET Core in Action*. His blog is frequently re-shared on the official .NET blog by the ASP.NET team.
- **Key works:**
  - [*ASP.NET Core in Action, 3rd Edition* (Manning)](https://www.manning.com/books/asp-net-core-in-action-third-edition) — restructured around minimal APIs as the on-ramp.
  - [andrewlock.net](https://andrewlock.net/) — series posts on source generators, configuration, OpenTelemetry.
  - [GitHub: `andrewlock/asp-dot-net-core-in-action-3e`](https://github.com/andrewlock/asp-dot-net-core-in-action-3e) — runnable book samples including testing chapters with `WebApplicationFactory` and EF Core in-memory SQLite.
- **Characteristic pattern:** Teach the *current* idiomatic shape, not the historical one. The third edition leads with minimal APIs and the `WebApplication` host model rather than the Startup/Program split.
- **Stance on type-driven / contract-first design:** Pragmatic. Use minimal APIs with strongly-typed parameter binding; lean on `IOptions<T>` for configuration; document with OpenAPI.
- **TDD posture:** Test-first friendly. The book covers unit tests of services, middleware tests against `TestServer`, and full integration tests via `WebApplicationFactory<T>` with EF Core in-memory SQLite. He treats integration tests at the HTTP boundary as the highest-value tests for ASP.NET Core apps.
- **Why authoritative (not just popular):** Long track record of explaining each .NET release with sample code that compiles; the ASP.NET team cross-posts his work.
- **Non-obvious belief:** For a typical ASP.NET Core service the *highest-leverage* tests aren't unit tests of controllers — they're `WebApplicationFactory` integration tests that exercise routing, model binding, filters, and EF Core together. Mock as little as possible above the database.

### Community TDD posture
TDD has a deeper, more positive tradition in C# than in TypeScript — descended from the agile/XP-era C# community of the 2000s. It is *contested but mainstream*: many .NET shops practice TDD, especially with xUnit + Moq or NSubstitute. The modern center of gravity has shifted from heavily-mocked London-school unit tests toward Detroit-leaning integration tests using `WebApplicationFactory`, EF Core in-memory or SQLite, and Testcontainers for real Postgres/SQL Server. NRTs and records reduce the *need* for some tests by pushing errors to compile time.

### Stack-native test tooling consensus
- **Unit:** xUnit is the modern default (the ASP.NET Core repo itself uses it). NUnit is still common in older codebases; MSTest is a distant third outside Microsoft-internal contexts.
- **Mocking:** Moq was the default; NSubstitute and the newer FakeItEasy are increasingly preferred for ergonomics. Heavy mocking is discouraged for handlers/controllers.
- **Integration:** `Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<TEntryPoint>` plus `TestServer` (in-process) — Fowler-blessed.
- **Property-based:** FsCheck (also usable from C# via FsCheck.Xunit).
- **DB:** EF Core in-memory provider for fast tests; SQLite in-memory for relational fidelity; Testcontainers for real DB.

### Synthesis for Worker `web-stack` skill targeting this stack
- Default to .NET 8+, `<Nullable>enable</Nullable>`, `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`. NRTs are not optional for new code (Torgersen).
- Prefer records for DTOs and value objects (Torgersen). Use `required` members so invalid construction fails to compile.
- Prefer minimal APIs over MVC controllers for JSON services (Fowler, Lock); fall back to MVC only when you need filter pipelines, model binding behaviours, or Razor.
- Async-all-the-way-down with explicit `CancellationToken` parameters; never `Task.Run` to "make it async"; never `.Result` or `.Wait()` on async code (Cleary).
- Anti-patterns to avoid: sync-over-async (Cleary), interface-per-class "just in case" (Fowler), `DateTime` for instants and zoned times in the same model (Skeet), MVC controllers as the default shape for JSON APIs (Lock).
- **Test-first workflow shape:** for each feature — (1) write a failing `WebApplicationFactory` integration test that hits the HTTP endpoint with realistic input and asserts on status + body (Lock); (2) make it compile by stubbing the minimal API handler; (3) make it pass by implementing the handler and the service layer; (4) add unit tests *only* for service logic with non-trivial branches. Use xUnit + `dotnet watch test` for the inner loop. For long-running concurrency code, add a cancellation-token test before implementation (Cleary).

### Top 3 reading list (priority order)
1. [*ASP.NET Core in Action, 3rd Edition*](https://www.manning.com/books/asp-net-core-in-action-third-edition) — the most up-to-date end-to-end model of a production ASP.NET Core app, minimal-API-first.
2. [Fowler's Async Guidance gist](https://github.com/davidfowl/AspNetCoreDiagnosticScenarios/blob/master/AsyncGuidance.md) — densest set of "do this, not that" recommendations from the runtime architect.
3. [*Concurrency in C# Cookbook*](https://www.amazon.com/Concurrency-Cookbook-Asynchronous-Multithreaded-Programming/dp/149205450X) — Cleary's recipes, still the practical reference for any non-trivial async code.

---

## Track: Go

### Authoritative voices

#### 1. Rob Pike
- **Role:** Co-creator of Go (with Robert Griesemer and Ken Thompson); distinguished engineer, previously at Bell Labs (Unix, Plan 9, UTF-8).
- **Key works:**
  - ["Concurrency is not parallelism" talk](https://go.dev/talks/2012/waza.slide) — the conceptual core of Go's concurrency model.
  - [Go Proverbs (go-proverbs.github.io)](https://go-proverbs.github.io/) — distilled style rules: *Don't communicate by sharing memory; share memory by communicating. Channels orchestrate; mutexes serialize. Make the zero value useful. The bigger the interface, the weaker the abstraction. A little copying is better than a little dependency.*
  - ["Errors are values" (Go blog)](https://go.dev/blog/errors-are-values)
- **Characteristic pattern:** *Simplicity through subtraction.* If a feature can be done with what's already in the language, it shouldn't be added. The result is a small language with a large stylistic surface area defined by community proverbs.
- **Stance on type-driven / contract-first design:** Interfaces are small and *discovered* at the call site (structural, not nominal). Define them where they're consumed, not where they're produced. Generics arrived late (1.18) and are deliberately constrained.
- **TDD posture:** Not a TDD advocate. The Go culture he shaped favors heavy testing but in *test-after-or-alongside* form, with table-driven tests as the canonical shape. Mocking is unfashionable.
- **Why authoritative (not just popular):** He designed and named the language. The proverbs are quoted as code-review rationale across the community.
- **Non-obvious belief:** *Errors are values* — meaning you should program *with* errors as ordinary data (count them, filter them, accumulate them) rather than treating them as a separate control-flow channel. This is why Go has no exceptions and why `if err != nil { return err }` is acceptable rather than a code smell.

#### 2. Russ Cox
- **Role:** Long-time Go tech lead (stepping back from the role recently). Architect of Go modules (`vgo` → modules), `go test -fuzz`, and large chunks of the toolchain.
- **Key works:**
  - [research.swtch.com](https://research.swtch.com/) — his research blog; the [Go & Versioning series](https://research.swtch.com/vgo) is the design document for modules.
  - ["Go Testing By Example" (talk + post)](https://research.swtch.com/testing) — 20 testing tips from the person who shipped `go test -fuzz`.
  - ["The Go Programming Language and Environment"](https://cacm.acm.org/research/the-go-programming-language-and-environment/) (CACM article, with Griesemer, Pike, Taylor, Thompson) — the official retrospective on Go's design rationale.
- **Characteristic pattern:** *Tooling and testing are first-class language concerns.* Modules, fuzzing, and `go vet` are part of the language for him, not afterthoughts. Reproducibility is a hard requirement.
- **Stance on type-driven / contract-first design:** Pragmatic. Generics where they reduce duplication, not as a general-purpose programming model. Strong preference for parsers and printers as test infrastructure.
- **TDD posture:** Test-heavy but not classic TDD. His 20 tips emphasise making it easy to add new test cases, using test coverage to find untested code (not as a substitute for thought), and writing parsers/printers to simplify tests — even building "testing mini-languages." Closer to *example-driven development* than red-green-refactor.
- **Why authoritative (not just popular):** He shipped the Go toolchain. If you `go test`, `go mod tidy`, or `go test -fuzz`, his fingerprints are on it.
- **Non-obvious belief:** When tests have to compare against reference outputs that may change (golden files, formatter output, parser output), *write code that updates them automatically* on a flag — don't paste expected output by hand. He uses this pattern with txtar to put multi-file fixtures into a single test file.

#### 3. Dave Cheney
- **Role:** Independent Go consultant and writer; long-time Go contributor; foundational voice on error handling and idiomatic style.
- **Key works:**
  - [dave.cheney.net](https://dave.cheney.net/) — long-running blog, especially the error-handling series.
  - ["Don't just check errors, handle them gracefully"](https://dave.cheney.net/2016/04/27/dont-just-check-errors-handle-them-gracefully) — and its update on `pkg/errors` ([Stack traces and the errors package](https://dave.cheney.net/2016/06/12/stack-traces-and-the-errors-package)).
  - ["Practical Go: Real world advice for writing maintainable Go programs"](https://dave.cheney.net/practical-go/presentations/qcon-china.html)
- **Characteristic pattern:** *Three error strategies, picked deliberately:* sentinel values (rare), error types (sometimes), opaque errors with behaviour assertions (default). Wrap errors with context as they cross package boundaries; unwrap when you need to inspect.
- **Stance on type-driven / contract-first design:** Interfaces should be *small* and *consumer-defined*. Errors are part of your public API and deserve the same care as any other type.
- **TDD posture:** Test-after-or-alongside, not strict TDD. Strong advocate of table-driven tests and of testing public behaviour via interfaces.
- **Why authoritative (not just popular):** `github.com/pkg/errors` was the de facto extension to Go's error handling for years and directly influenced the `errors.Is` / `errors.As` / `%w` design that landed in Go 1.13.
- **Non-obvious belief:** Minimise the number of sentinel errors in your program — they couple callers to packages and to specific failure points. When you need to discriminate, assert on *behaviour* (`interface{ Temporary() bool }`) rather than equality or type. Better than improving error syntax is having fewer errors to handle at all.

#### 4. Bill Kennedy
- **Role:** Managing partner at Ardan Labs; author of *Go in Action*; long-running Ultimate Go training program; frequent GopherCon speaker.
- **Key works:**
  - [Ultimate Go (training)](https://www.ardanlabs.com/training/live/teams/ultimate-go/) and the self-paced bundle.
  - [Ardan Labs blog (`ardanlabs.com/blog`)](https://www.ardanlabs.com/blog/) — including the table-driven tests reference post.
  - [`ardanlabs/gotraining`](https://github.com/ardanlabs/gotraining) — the public training material, including service-oriented architecture samples.
- **Characteristic pattern:** *Data-oriented design.* Think about how data is shaped and moved (cache lines, allocations) before you think about types. Concrete first, abstract only when forced.
- **Stance on type-driven / contract-first design:** Strongly anti-premature-abstraction. "Accept interfaces, return concrete types" is a refrain. Define interfaces where you consume them; let them stay tiny.
- **TDD posture:** Test-heavy and behaviour-focused. Heavy use of table-driven tests; integration-leaning. Doesn't strictly red-green-refactor but does train the discipline of writing the test alongside the code, not after.
- **Why authoritative (not just popular):** He has personally trained a substantial fraction of professional Gophers (corporate workshops and online courses) and is one of the most consistent GopherCon voices on engineering practice.
- **Non-obvious belief:** Most "design patterns" from the OO world are *the wrong starting point* in Go. Apply *mechanical sympathy* — understand the runtime, the GC, and the cache — and let the design emerge from data and execution shape, not from a pattern catalogue.

#### 5. Mat Ryer
- **Role:** Engineer at Grafana; previously founder of Pace.dev; long-time Gopher (since pre-1.0). Author of *Go Programming Blueprints*. Co-host of *Go Time*.
- **Key works:**
  - ["How I write HTTP services after eight years"](https://pace.dev/blog/2018/05/09/how-I-write-http-services-after-eight-years.html) (and the [updated 13-years version on Grafana's blog](https://grafana.com/blog/2024/02/09/how-i-write-http-services-in-go-after-13-years/))
  - [`matryer/is`](https://github.com/matryer/is) — minimal test assertion library; "Testify off steroids."
  - Long-time contributor to `stretchr/testify`.
- **Characteristic pattern:** *Server-as-a-struct.* Define a `server` struct that holds dependencies; attach handlers as methods or via `routes()`; pass everything explicitly. Predictable, testable, no global state.
- **Stance on type-driven / contract-first design:** Pragmatic. Use interfaces at the consumer (especially for testing). Use code generation for cross-language API/CLI consistency.
- **TDD posture:** Practices TDD in a Detroit-leaning style — real dependencies where cheap, small interfaces where needed, table-driven tests as the default shape. His `is` library is designed for terse, readable assertions that don't tempt over-mocking.
- **Why authoritative (not just popular):** Contributed to testify, the most-used Go assertion library; the HTTP-services post is one of the most-cited "how to structure a Go service" pieces in the community.
- **Non-obvious belief:** Don't put your service in `func main()`; put it in a `run(ctx, args, stdin, stdout, stderr) error` function. `main` becomes a trivial wrapper that handles exit codes and signals. This single move makes integration tests trivial because `run` is callable from a test.

### Community TDD posture
TDD is *not the default* in Go and is mildly *contested*. The community is test-heavy but rarely red-green-refactor by ritual. The dominant patterns: table-driven tests (Cox, Cheney, Kennedy, Ryer all teach this), example-driven testing (`ExampleFoo` functions doubling as docs), `testdata/` directories with golden files (Cox), fuzzing (Cox, Go 1.18+), and integration tests close to real dependencies. Mocking is culturally suspect; "accept interfaces, return concrete types" leads to small consumer-defined interfaces that are easy to fake without a framework.

### Stack-native test tooling consensus
- **Core:** the stdlib `testing` package (no replacement, no framework needed).
- **Assertions:** `stretchr/testify` is very common (Ryer contributes there) but contested — many idiomatic Gophers prefer stdlib + `cmp.Diff` (from `github.com/google/go-cmp/cmp`).
- **Lighter alternative:** `matryer/is` for terse, opinion-free assertions.
- **Diffs:** `google/go-cmp` is the canonical choice for structural equality with custom comparison options.
- **HTTP:** `net/http/httptest`, plus `httpexpect` if you want fluent assertions.
- **Fuzzing:** built-in via `go test -fuzz` since Go 1.18.
- **Mocking:** `gomock` exists; community generally prefers hand-rolled fakes or interface stubs.

### Synthesis for Worker `web-stack` skill targeting this stack
- Structure services with a `run(ctx, args, ...) error` function and a `server` struct that holds dependencies (Ryer). `main` is a trivial wrapper.
- Define interfaces at the consumer, not the producer; keep them small (Pike, Cheney, Kennedy). The skill should refuse to scaffold a `MyServiceInterface` next to `MyServiceImpl`.
- Errors: wrap with `fmt.Errorf("...: %w", err)` at every package boundary that adds meaningful context; use `errors.Is`/`errors.As` to discriminate; minimise sentinels (Cheney).
- Tests: prefer table-driven (`[]struct{ name, in, want, wantErr string }` style) for any function with branching; use `testdata/` and golden files for parser/formatter output (Cox); add a `-update` flag to regenerate goldens (Cox).
- Concurrency: pass `context.Context` as the first parameter on anything that does I/O. Channels orchestrate, mutexes serialize — pick deliberately (Pike). Don't reach for goroutines until you've measured.
- Anti-patterns to avoid: interface-per-struct ahead of need (Kennedy, Cheney), sentinel errors as the default discriminator (Cheney), `panic` for control flow, mocks where a fake or real dependency would do (Kennedy, Ryer), business logic in `main` (Ryer).
- **Test-first workflow shape:** for each new package — (1) sketch the public API in `package_test.go` first via an example test or a table-driven test of the most important behaviour; (2) `go test ./...` and confirm RED; (3) implement until GREEN; (4) add a fuzz test (`func FuzzFoo(f *testing.F)`) for any function that parses bytes/strings; (5) `go test -race ./...` before commit. Use `go test -run TestFoo -v` in watch mode (e.g. via `gotestsum --watch`).

### Top 3 reading list (priority order)
1. [Russ Cox — "Go Testing By Example"](https://research.swtch.com/testing) — 20 tips; the most concentrated wisdom on testing Go from inside the team.
2. [Dave Cheney — "Don't just check errors, handle them gracefully"](https://dave.cheney.net/2016/04/27/dont-just-check-errors-handle-them-gracefully) + ["Practical Go"](https://dave.cheney.net/practical-go/presentations/qcon-china.html) — error handling and idiomatic style, paired.
3. [Mat Ryer — "How I write HTTP services in Go after 13 years"](https://grafana.com/blog/2024/02/09/how-i-write-http-services-in-go-after-13-years/) — the single most pragmatic template for a Go HTTP service.

---

## Track: Vercel (Next.js + Vercel Postgres + Edge)

### Authoritative voices

#### 1. Guillermo Rauch
- **Role:** Founder and CEO of Vercel; creator of Next.js; previously created Socket.IO and Mongoose; ex-Automattic.
- **Key works:**
  - [rauchg.com](https://rauchg.com/) — long-form essays.
  - [Vercel blog (CEO posts)](https://vercel.com/blog) — strategic framing for Next.js features.
  - Public talks at JSWorld, Sequoia's *Training Data*, First Round, etc.
- **Characteristic pattern:** *Progressive disclosure of complexity.* The default path must work for a beginner with one line of code; the same framework must scale to top-30 internet websites. *Develop, preview, ship* — short feedback loops are the product.
- **Stance on type-driven / contract-first design:** TypeScript-first by default; opinionated build output as a contract (the Build Output API). Vercel templates use Zod-based validation.
- **TDD posture:** Not a TDD advocate. He is firmly on the "ship fast, get production feedback, iterate" side; the Next.js culture is closer to *preview-driven development* (every PR gets a deploy preview at a unique URL, which becomes the test surface).
- **Why authoritative (not just popular):** He created Next.js and runs the company that ships it. Strategic decisions (App Router default, server components, Server Actions, Partial Prerendering) are his to make.
- **Non-obvious belief:** Performance is a product feature, not an engineering concern — fast sites convert better, rank better, retain users. This is why Next.js privileges static-by-default, streaming, and edge — it's a *business* argument, not just a technical one.

#### 2. Lee Robinson
- **Role:** Currently at Cursor (teaching AI); previously VP of Developer Experience at Vercel, where he led Next.js community work.
- **Key works:**
  - [leerob.com](https://leerob.com/) (formerly leerob.io) — long-form writing on Next.js and self-hosting.
  - ["Common mistakes with the Next.js App Router and how to fix them"](https://vercel.com/blog/common-mistakes-with-the-next-js-app-router-and-how-to-fix-them) — canonical do/don't reference.
  - [Next.js SaaS Starter](https://github.com/leerob/next-saas-starter) — production-shape template (Postgres + Drizzle + Stripe + Tailwind + shadcn/ui + cookie auth + middleware).
- **Characteristic pattern:** *Show the working shape.* Lee's signature is publishing a complete, runnable template that exercises every major Next.js feature in a realistic combination — then explaining each decision in prose.
- **Stance on type-driven / contract-first design:** Pro-TypeScript-strict, pro-Zod for input validation in Server Actions, pro-Drizzle (typed SQL builder) over Prisma where edge-compatibility matters.
- **TDD posture:** Not a TDD advocate. The dominant testing posture he models is Playwright for end-to-end critical paths plus Vitest for utilities and Server Action logic. Type safety substitutes for many unit tests.
- **Why authoritative (not just popular):** He effectively wrote the modern "how to use the App Router" canon at Vercel during the App Router rollout; the patterns in his blog posts and starter became the patterns the Next.js docs absorbed.
- **Non-obvious belief:** Route Handlers (the `/app/api/...` REST endpoints) are usually unnecessary when you control both client and server — call your server logic directly from Server Components, or use Server Actions from Client Components. The extra network hop and the parallel API surface buy you nothing if there is no third-party client.

#### 3. Tim Neutkens
- **Role:** Next.js lead at Vercel. Has been on the core team since the early versions; drives architectural direction (App Router, Turbopack, Partial Prerendering).
- **Key works:**
  - Next.js release blog posts on [nextjs.org/blog](https://nextjs.org/blog) (Tim is the most frequent author/co-author for architecture posts).
  - Conference talks on Turbopack and the App Router internals (Next.js Conf).
  - [`timneutkens` on GitHub](https://github.com/timneutkens) — direct code authorship on App Router and the compiler integration.
- **Characteristic pattern:** *Framework-as-compiler.* Decisions like Turbopack, the React Server Components integration, and the file-system router exist to push optimization into the build/compile layer so application authors don't think about it.
- **Stance on type-driven / contract-first design:** Pro typed boundaries; the Next.js ecosystem standardised on TypeScript-first APIs (route segment configs, `generateMetadata`, typed page props).
- **TDD posture:** Not a TDD evangelist; the Next.js itself uses heavy integration testing (the `next.js/test` directory has thousands of tests against real builds) but for application code the messaging is "use Playwright for what users see, Vitest for what they don't."
- **Why authoritative (not just popular):** He leads the framework. Patterns he doesn't bless tend not to land.
- **Non-obvious belief:** Server Components are the *default*, Client Components are the exception. Most app authors invert this in their first weeks and end up with bloated client bundles; the right mental model is "everything is a Server Component until you need state, effects, or browser APIs at this exact node."

#### 4. Dan Abramov
- **Role:** Independent (formerly React core team at Meta; briefly at Bluesky). Co-creator of Redux and Create React App; one of the loudest public voices for React Server Components.
- **Key works:**
  - [overreacted.io](https://overreacted.io/) — long-form essays on React mental models.
  - [React Server Components RFC and follow-up explainers on his blog](https://overreacted.io/) — the conceptual ground for the App Router.
  - Talks: "React for Two Computers", "Forget About Client-Side Rendering."
- **Characteristic pattern:** *Mental-model essays.* Doesn't write reference docs — writes long, narrative explorations of *why* React works the way it does, so that the API stops feeling arbitrary.
- **Stance on type-driven / contract-first design:** Less type-heavy than the TS community proper; he treats types as enabling but secondary to component composition and data-flow correctness.
- **TDD posture:** Not a TDD advocate. He has been openly skeptical of unit-testing-as-ritual, especially in UI; favours integration/e2e and high-level snapshotting where useful.
- **Why authoritative (not just popular):** He shaped React's developer-facing API (functional setState, hooks era, Server Components storytelling). Even though he's no longer at Meta, his framing is how a generation of React developers understand the library — and the App Router is Vercel's bet on his "two computers" framing.
- **Non-obvious belief:** *The UI is a function of state on two computers, not one.* Server Components aren't an optimisation — they're a way to make the two-computer reality of every web app a first-class part of the component model, instead of pretending the client is the only place that exists.

### Community TDD posture
TDD is *fringe* in the Vercel/Next.js community. The center of gravity is preview-driven development (every PR is a live URL), TypeScript-as-contract, and Playwright for the critical user journeys. Unit tests for Server Components are awkward by design (they're async and touch the data layer); the Vercel-blessed path is to test the Server Action or the data-access function in isolation with Vitest, and to test the rendered route end-to-end with Playwright. There is *no* widely accepted RGR shape for Server Components.

### Stack-native test tooling consensus
- **Unit / integration:** Vitest > Jest, especially for projects that already use Vite or `next dev`.
- **E2E:** Playwright (Vercel uses and promotes it). Cypress is acceptable but losing share.
- **Component / visual:** Storybook + Playwright's Chromatic-style visual regression; less mandatory.
- **Validation at boundaries:** Zod schemas in Server Actions and Route Handlers (Lee Robinson's templates lead with this).
- **Database / ORM:** Drizzle (typed, edge-friendly) is the modern default in Vercel-influenced templates; Prisma still common but heavier at the edge.
- **Preview deploys** are the closest thing to a test environment for many teams.

### Synthesis for Worker `web-stack` skill targeting this stack
- Default to Next.js App Router on TypeScript, `strict: true`, Tailwind + shadcn/ui, Drizzle ORM (or Prisma if explicitly requested), Zod for every Server Action input and every Route Handler body.
- Server Components are the default; mark `"use client"` only at the leaf where state/effects/browser APIs are needed (Neutkens).
- Skip Route Handlers when the server logic is only consumed by your own client — call data-access functions directly in Server Components, or use Server Actions from Client Components (Robinson).
- Prefer streaming with `<Suspense>` boundaries placed at the unit of "what shows a fallback" — not blanket-wrapping pages (Robinson, Vercel blog).
- For background tasks: Vercel Cron Jobs for periodic work; for long-running, prefer offloading to a queue or a Workflow rather than a long-lived Route Handler (Vercel's framework-defined infrastructure model).
- Anti-patterns to avoid: client-fetching data that a Server Component could fetch directly (Robinson), wrapping context providers higher than necessary (Robinson), hand-writing fetch-and-cache when `fetch` in a Server Component already memoises per-request (Vercel), inverting the server/client default (Neutkens).
- **Test-first workflow shape:** for each user-facing feature — (1) write a Playwright spec for the critical user journey first; (2) `pnpm test:e2e` and confirm RED; (3) for any Server Action or data-access function the journey calls into, write a Vitest test with a real (test) database and Zod input validation; (4) implement the Server Action and the UI until the Playwright spec passes; (5) use `next dev` preview + Vercel preview deploys for design review. Type errors (`tsc --noEmit`) are part of CI's "test" stage.

### Top 3 reading list (priority order)
1. [Next.js docs — App Router section](https://nextjs.org/docs/app) — Tim Neutkens's team's authoritative shape, kept current.
2. [Lee Robinson — "Common mistakes with the App Router"](https://vercel.com/blog/common-mistakes-with-the-next-js-app-router-and-how-to-fix-them) + his Next.js SaaS Starter — the most pragmatic single pairing.
3. [Dan Abramov — overreacted.io](https://overreacted.io/) — the mental model behind Server Components (essential if you want to *understand*, not just type-check, App Router code).

---

## Track: Cloudflare (Workers + R2 + D1 + Durable Objects)

### Authoritative voices

#### 1. Kenton Varda
- **Role:** Principal Engineer at Cloudflare; architect of Cloudflare Workers and lead developer of the open-source [`workerd`](https://github.com/cloudflare/workerd) runtime. Previously led Protocol Buffers at Google; creator of [Cap'n Proto](https://capnproto.org/) and the new [Cap'n Web](https://blog.cloudflare.com/capnweb-javascript-rpc-library/) JS-native RPC.
- **Key works:**
  - [Cloudflare blog (author page)](https://blog.cloudflare.com/author/kenton-varda/) — the design essays for Durable Objects, Workers RPC, SQLite-in-DOs, and bindings.
  - [`cloudflare/workerd`](https://github.com/cloudflare/workerd) — the open-source runtime.
  - ["The network is the computer" interview on Cloudflare TV](https://cloudflare.tv/this-week-in-net/ai-writes-code-kenton-varda-on-trust-review-and-why-workers-is-the-best-ai-platform/PZ5rmMg2) — the long-form architectural vision.
- **Characteristic pattern:** *Bindings, not connections.* Resources (KV, R2, D1, DOs, secrets, other Workers) are exposed via capability-style bindings in `wrangler.toml`/`wrangler.jsonc`, not URLs and credentials in code. This is both a DX win and a security primitive.
- **Stance on type-driven / contract-first design:** Strongly contract-first — at the RPC layer (Cap'n Proto, Cap'n Web) and at the binding layer. Workers RPC lets Worker-to-Worker and Worker-to-DO calls look like local method calls with full TypeScript types.
- **TDD posture:** Not a TDD evangelist, but a strong advocate for *running tests in the same runtime as production*. Workers' `vitest-pool-workers` integration exists because tests that run in Node and not in `workerd` lie about behaviour.
- **Why authoritative (not just popular):** He designed the runtime. Every Workers primitive — isolates over containers, Durable Objects as named single-tenant servers, SQLite-in-DOs, Dynamic Workers — is his or under his direction.
- **Non-obvious belief:** SQLite-in-Durable-Objects inverts conventional cloud architecture: instead of putting your application near a remote database, put a small private database *inside* your application's compute. For per-user/per-room/per-document state this is dramatically simpler and faster than any client-server DB.

#### 2. Sunil Pai
- **Role:** Principal Systems Engineer at Cloudflare, working on the Agents SDK; founder of PartyKit (acquired by Cloudflare in 2024). Previously on the React core team at Meta.
- **Key works:**
  - [sunilpai.dev](https://sunilpai.dev/) — blog.
  - [PartyKit / partyserver](https://github.com/threepointone/partyserver) — minimal library for stateful real-time apps on Durable Objects.
  - [Cloudflare Agents SDK](https://developers.cloudflare.com/agents/) — current focus; "batteries-included platform for AI agents that think, act, and persist."
- **Characteristic pattern:** *Programming model first, infrastructure second.* PartyKit reduced Durable Objects to a `Server` class with `onConnect`/`onMessage` so the developer doesn't think about handshake/upgrade plumbing. The Agents SDK does the same for persistent AI agents.
- **Stance on type-driven / contract-first design:** Pro typed RPC and pro durable, addressable identity (a DO instance is named, so its API is essentially a typed singleton).
- **TDD posture:** Not a TDD advocate publicly; the messaging is closer to "make the primitive so simple you can iterate live." Tests come from local dev with `wrangler dev` plus the Vitest pool when behaviour gets non-trivial.
- **Why authoritative (not just popular):** PartyKit demonstrated, before anyone else, that Durable Objects could be made *boring* for application developers. His framing of stateful serverless influenced how Cloudflare positions Workers vs. Lambda/Vercel functions.
- **Non-obvious belief:** Pull-based and durable-execution models can replace much of what people currently solve with WebSockets and ad hoc event-loops. The DO-per-entity pattern (one DO per room, one DO per user, one DO per document) is a different shape from "shard-by-user-id in Redis" and unlocks programming models that aren't worth attempting in conventional cloud.

#### 3. Brendan Coll
- **Role:** Creator of [Miniflare](https://github.com/cloudflare/workers-sdk/tree/main/packages/miniflare) (local simulator for Workers); now research engineer at XBOW.
- **Key works:**
  - [Miniflare](https://miniflare.dev/) — local-first simulator; v3+ uses the actual `workerd` runtime instead of polyfills.
  - [`@cloudflare/vitest-pool-workers`](https://blog.cloudflare.com/workers-vitest-integration/) — Vitest pool that runs your tests inside `workerd`.
  - ["Testing Alternative Runtimes with Node and Vitest"](https://gitnation.com/contents/testing-alternative-runtimes-with-node-and-vitest) — talk explaining the design.
- **Characteristic pattern:** *Eliminate the gap between local and production.* If `wrangler dev` runs Worker code in `workerd`, and `vitest` runs Worker code in `workerd`, the only difference is the global-network routing — which is far easier to reason about than a runtime-shape mismatch.
- **Stance on type-driven / contract-first design:** Pro full type generation from `wrangler.toml` bindings (the Cloudflare tooling now builds types for each user's specific compatibility settings).
- **TDD posture:** Test-first friendly. The whole vitest-pool-workers design is optimised for fast watch-mode reruns, isolated per-test storage, and direct access to DO instances. This is the most TDD-amenable testing setup of any edge platform.
- **Why authoritative (not just popular):** He built the testing infrastructure the rest of the ecosystem relies on. If you write tests for a Worker, you almost certainly run them under his code.
- **Non-obvious belief:** Vitest's custom-pool architecture is the right abstraction for testing in non-Node runtimes generally — not just Workers. The pool can run Node-side orchestration while the test bodies execute in the foreign runtime, with RPC between them. The lesson generalises beyond Cloudflare.

#### 4. Rita Kozlov
- **Role:** Senior Director of Product at Cloudflare; leads the Workers product organisation.
- **Key works:**
  - Cloudflare blog product launches (D1 GA, Hyperdrive GA, Workers analytics) — frequently co-authored.
  - [InfoQ Q&A: "Cloudflare D1, Workers Analytics Engine and Hyperdrive"](https://www.infoq.com/news/2024/04/cloudflare-d1-hyperdrive-ga/) — explicit on the rationale for Hyperdrive vs. D1 vs. DOs.
- **Characteristic pattern:** *Frame the developer's full stack.* Storage choices (D1 vs. DO-with-SQLite vs. KV vs. R2 vs. Hyperdrive-to-Postgres) are not interchangeable; product positioning explicitly tells you which to pick for which shape.
- **Stance on type-driven / contract-first design:** Pro bindings as contracts; pro typed Wrangler-driven configuration.
- **TDD posture:** Product-side, not engineering-side, but the public messaging consistently includes "test locally with Miniflare/`workerd`" as part of the standard developer loop.
- **Why authoritative (not just popular):** She owns the roadmap that decides which primitives exist and which get deprecated.
- **Non-obvious belief:** The right mental model for choosing storage on Cloudflare isn't "relational vs. document vs. cache" — it's "per-entity strong consistency (DO + SQLite) vs. global read-heavy (D1) vs. cached-frontend-to-existing-DB (Hyperdrive) vs. eventual KV vs. object R2." Most Workers apps end up using two or three of these, not one.

### Community TDD posture
TDD is *contested but enabled*. Historically, Workers had a testability gap (Miniflare 2 polyfilled the runtime, so tests were close-but-not-exact). The combination of Miniflare 3 + `workerd` + `@cloudflare/vitest-pool-workers` (2024) effectively removed that gap. The community is now *the most test-first-amenable edge platform* — tests can run inside the real runtime, with bindings, isolated per-test storage, and access to DO instances. But the cultural emphasis is still "make the primitive so good you don't need many tests": typed RPC, single-tenant DOs, declarative bindings remove whole categories of test.

### Stack-native test tooling consensus
- **Local dev:** `wrangler dev` (runs `workerd` locally).
- **Unit / integration:** [`@cloudflare/vitest-pool-workers`](https://developers.cloudflare.com/workers/testing/vitest-integration/) — Vitest with a custom pool that runs each test file inside `workerd`. Provides isolated per-test storage, a `cloudflare:test` module for binding access, and direct Durable Object access.
- **E2E:** Playwright (against a `wrangler dev` instance or a preview deploy).
- **Validation at boundaries:** Zod for incoming request bodies in Hono / itty-router handlers (the JS/TS web-framework ecosystem mostly carries over).
- **Mocking outbound HTTP:** declarative HTTP request mocking baked into the Vitest pool.

### Synthesis for Worker `web-stack` skill targeting this stack
- Default project: a TypeScript Worker scaffolded with `npm create cloudflare@latest`, using Hono (or itty-router) for routing if HTTP, plus the relevant bindings in `wrangler.jsonc`.
- Use **bindings, not URLs**, for every Cloudflare resource (Varda). Never embed a D1 connection string; bind the database in `wrangler.jsonc` and consume via `env.MY_DB`.
- Pick storage deliberately per Kozlov's mental model:
  - DO + SQLite for per-entity strong-consistency state (rooms, users, documents).
  - D1 for shared relational, read-heavy data with global replication.
  - KV for eventually-consistent config and session data.
  - R2 for blobs.
  - Hyperdrive when you need a centralised Postgres/MySQL with pooled connections at the edge.
- Web APIs only — `node:*` imports require explicit `nodejs_compat`. The skill should refuse common-but-incompatible Node patterns (`fs`, raw `net`).
- Anti-patterns to avoid: using D1 where a DO would naturally hold per-entity state (Varda, Kozlov), opening a fresh DB connection per request instead of using Hyperdrive's pool, treating a Worker as if it had long-lived in-memory state (use DOs), reaching for WebSockets without using DOs as the coordination point (Pai).
- **Test-first workflow shape:** for each new endpoint or DO — (1) install `@cloudflare/vitest-pool-workers` and set up `vitest.config.ts` with `cloudflareTest({ wrangler: { configPath: './wrangler.jsonc' } })`; (2) write a Vitest test that uses `SELF.fetch(...)` (or `env.MY_DO.get(id)` for DOs) and asserts on the response; (3) `vitest --run` → RED; (4) implement until GREEN; (5) for DO storage, leverage the pool's per-test isolated storage so tests don't leak; (6) wire a Playwright spec against `wrangler dev` for the critical end-to-end path.

### Top 3 reading list (priority order)
1. [Cloudflare Workers docs — Vitest integration](https://developers.cloudflare.com/workers/testing/vitest-integration/) + [the launch post](https://blog.cloudflare.com/workers-vitest-integration/) — the test-first foundation; everything else assumes this is in place.
2. [Kenton Varda — Durable Objects + SQLite blog series](https://blog.cloudflare.com/author/kenton-varda/) — the design vocabulary for stateful workers, RPC, bindings.
3. [Cloudflare docs — "Choosing a data or storage product"](https://developers.cloudflare.com/workers/platform/storage-options/) — the canonical decision matrix for D1 / DO / KV / R2 / Hyperdrive.

---

## Cross-stack patterns

### Where the authorities agree

- **Types (or schemas) at the boundary; looser inside.** Hejlsberg/Rosenwasser/Pocock/McDonnell (TS), Torgersen/Fowler/Skeet (C#), Cheney ("errors are part of your public API") and Pike ("the bigger the interface, the weaker the abstraction") (Go), Robinson with Zod-in-Server-Actions (Vercel), Varda with typed bindings and RPC (Cloudflare) — every track agrees that the *boundary* is where type/schema discipline pays off most, and that internal code can be looser. The disagreement is only about *which mechanism* enforces the boundary (TS narrowing + Zod, C# NRTs + records, Go small interfaces, Cloudflare bindings + Cap'n Web).

- **Small consumer-defined interfaces beat ahead-of-time abstractions.** Pike, Cheney, Kennedy ("accept interfaces, return concrete types"), Fowler (don't add an interface until you need a second implementation), Pocock (let the type system *infer* shapes rather than declaring them ahead of use) — convergent across Go, C#, and TS.

- **Integration-leaning tests beat heavy mocking.** Skeet's Noda Time test suite, Lock's `WebApplicationFactory` advocacy, Kennedy and Ryer's preference for real fakes over generated mocks, Coll's vitest-pool-workers (which exists precisely so tests run in the real runtime), Robinson and Vercel's Playwright-first messaging — across stacks, the modern center of gravity is *Detroit-school* rather than *London-school* testing.

- **Make the zero/default valid.** Pike's "make the zero value useful," Torgersen's NRTs and required members, McDonnell's parse-don't-validate (an invalid value never enters your typed world), Varda's bindings (you can't construct a Worker with malformed dependencies — it won't deploy). The shared idea: arrange types and constructors so that the *easy* path is the *correct* path.

- **Tooling and inner-loop feedback are a language-level concern.** Cox on `go test` and modules, Pocock and Rosenwasser on the type-checker as inner loop, Coll on `vitest-pool-workers`, Rauch and Robinson on preview deploys — every track treats the development feedback loop as part of "the language," not as separate plumbing.

### Where they disagree (instructively)

- **Mocking philosophy.** The TypeScript world (especially older codebases coming from Jest culture) is more London-school — `vi.mock`, msw, mock service-worker patterns. The Go world is firmly Detroit-school — fakes and small interfaces, mocking frameworks viewed with suspicion (Kennedy, Cheney). C# sits in between, with the modern voice (Lock, Fowler) pulling toward integration tests against `WebApplicationFactory` and away from per-class Moq setups. A skill author should pick a side per stack rather than averaging.

- **Test-first as a ritual.** C# (Skeet, Lock) is the *most* TDD-positive of the five stacks. Cloudflare (Coll's tooling) is the most TDD-enabled. Go and TypeScript are TDD-agnostic — test-heavy but not red-green-refactor by ritual. Vercel/Next.js is the most TDD-skeptical, relying on preview deploys, types, and Playwright rather than RGR loops. This is a *real* community split: a Worker skill enforcing strict RGR in Vercel idiom would feel alien even though the same Worker enforcing strict RGR in C# would feel natural.

- **Where the contract lives.** TS encodes contracts in inferred types and Zod schemas (parse-don't-validate). C# encodes them in record types, NRTs, and OpenAPI generated from minimal API signatures. Go encodes them in small interfaces defined at the call site and in error wrapping conventions (`%w`). Cloudflare encodes them in bindings (compile-time-checked against `wrangler.jsonc`) and typed RPC. Vercel encodes them at the route boundary (Server Action input schemas, route segment configs). When porting a pattern, ask: *where does this stack put the contract?*

- **Errors as values vs. exceptions.** Go's "errors are values" (Pike, Cheney) is the cleanest expression of the values-camp. C# uses exceptions but, post-NRTs, is migrating toward Result-style patterns for expected failures (and away from exceptions for control flow — Cleary on this). TS lacks language support either way; the community has split between try/catch (legacy), tagged-union Result types (functional camp), and ".safeParse()-style" returns (McDonnell-influenced). Cloudflare's `workerd` uses standard JS exceptions but typed RPC errors at the boundary. A skill should pick one model per stack and not blend them.

### What one stack's authorities would want the others to adopt

- **From Go to everyone:** Pike's "errors are values" — treat error data as ordinary data you compose and filter, not as a separate control channel. C# and TS in particular would benefit from this discipline; the Result-type movement in both languages is an echo of it.

- **From Cloudflare to everyone:** Varda's *bindings, not connections* — capability-style declarations of dependencies that can't be misconstructed. Vercel's environment variables and Next.js Server Actions are closer to this model than people realise; Cloudflare just pushed it further.

- **From C# to TS:** Mads Torgersen's records + NRTs + required members — a coherent story about "invalid construction doesn't compile." TypeScript can express most of this (`as const`, branded types, `Object.freeze`, `readonly`), but the community has no equivalent canonical pattern; the closest is Pocock's "use `satisfies` and derive everything," which is the right move but not as one-stop.

- **From TS/Vercel to C#/Go:** preview-deploy-driven development. Both the Vercel and Cloudflare ecosystems treat "every PR gets a URL" as table stakes; C# and Go shops typically run staging environments that lag the PR. Even partial adoption (an ephemeral environment per PR) would change the C# and Go feedback loop substantially.

- **From Pocock (TS) to everyone:** *read the error messages.* Every type system gets better at explaining itself; every language has improved its compiler diagnostics; every test runner has a `--verbose`. The single highest-leverage skill across stacks is treating tool output as something to *read deliberately*, not skim. A Worker skill that surfaces and annotates compiler/test-runner output is doing more useful work than one that suppresses it.
