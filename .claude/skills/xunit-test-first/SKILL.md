---
name: xunit-test-first
description: |
  C#-flavoured TDD sub-skill, chained from `tdd-loop` whenever the
  detected stack is .NET (`*.csproj` or `*.sln` exists). Implements the
  drifting-toward-Detroit modern .NET testing idiom canonised by Andrew
  Lock (*ASP.NET Core in Action*, 3rd ed.), David Fowler (ASP.NET Core
  architect, async guidance), Stephen Cleary (*Concurrency in C#
  Cookbook*), Mads Torgersen (C# lead designer; nullable reference
  types + records + required members), and Jon Skeet (Noda Time;
  contract-first typing).

  Specifically:
  - **Integration tests via `WebApplicationFactory<TEntryPoint>` are
    the default** for any ASP.NET Core feature — exercise routing,
    model binding, filters, and EF Core together. Mock as little as
    possible above the database. (Lock + Fowler.)
  - **xUnit.net** as the test framework — `[Fact]` for single cases,
    `[Theory]` + `[InlineData]` for table-driven cases.
  - **Records + required members + NRTs** are non-negotiable —
    "construct it valid or it doesn't compile." (Torgersen + Skeet.)
  - **Async-all-the-way-down**, `CancellationToken` as the first
    parameter on anything that does I/O, never `.Result` / `.Wait()` /
    `Task.Run` to "make it async". (Cleary.)
  - **EF Core in-memory or SQLite** for fast DB tests; Testcontainers
    when real Postgres/SQL Server semantics matter. (Lock.)
  - **`NSubstitute` or `FakeItEasy`** only at the I/O boundary when
    needed; prefer hand-rolled fakes (Nullables pattern) for internal
    collaborators. Heavy mocking is culturally suspect post-`WebApplicationFactory`.

  This skill drives the inner red-green-refactor *for one AC at a time*.
  Aggregation across ACs is `tdd-loop`'s job.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
agent-class: Worker (web-stack profile, sub-skill)
chained-from: tdd-loop (when stack is .NET / C#)
---

# xunit-test-first

You drive one RGR cycle in C# for one Acceptance Criterion. Your test runner is **xUnit.net** (the de facto modern default — the ASP.NET Core repo itself uses it). Your testing model is **Detroit-drifting**: integration via `WebApplicationFactory<TEntryPoint>` is the default surface; unit tests for the service layer come only when a branch deserves isolated coverage.

You do not heavily mock controllers/handlers/services. You *do* lean on `nullable reference types`, `record`s, and `required` members so that invalid construction fails to compile — meaningfully reducing the test surface (Torgersen + Skeet).

---

## When this sub-skill applies

The parent `tdd-loop` chained you because:

- `*.csproj` or `*.sln` exists at the repo root or in a known location
- The current AC's `impact_scope.files` includes `*.cs` files

If no .NET project exists yet, the parent should have routed to a future `scaffold-aspnet-minimal` first. Don't try to bootstrap a project yourself.

---

## Inputs (passed by `tdd-loop`)

- The specific AC under this iteration (text + ID)
- The WP's `impact_scope.files` — where you're allowed to write code
- The detected project shape: **minimal API** (Fowler/Lock default) or **MVC controller-based** (legacy)

---

## Step 1: Translate the AC into the right test shape

| AC shape | Test shape |
|---|---|
| "POST /api/invite with valid body returns 201 + invite payload" | **`WebApplicationFactory` integration test** that hits the real pipeline (routing, model binding, filters, EF Core in-memory). Default surface. |
| "GET /api/invite without auth returns 401" | Same — integration test, exercise the auth middleware. |
| "Service `InviteService.CreateAsync` throws when the email is already pending" | **xUnit `[Fact]`** unit test against the service in isolation, with a hand-rolled fake or in-memory DbContext. Use this *only* when the branch logic in the service is non-trivial and isn't naturally covered by an integration test. |
| "Function `ValidateTokenAsync(token)` accepts ... and rejects ..." | **xUnit `[Theory]` + `[InlineData]`** table-driven test. |
| "Operation cancels gracefully on cancellation token" | Dedicated `[Fact]` that creates a CTS, cancels it, asserts on `OperationCanceledException` — the cancellation test is canonical per Cleary. Write it *before* the implementation. |

For ASP.NET Core APIs, the `WebApplicationFactory` integration test is the **highest-leverage** test — it exercises everything that goes wrong in production (model binding, filter ordering, content negotiation, middleware). Unit tests of controllers/handlers in isolation are usually low-ROI. (Lock.)

---

## Step 2: Write the failing test

### 2a. `WebApplicationFactory` integration (the default)

Project layout convention:

```
src/
  MyApp/
    MyApp.csproj
    Program.cs                  ← entry; minimal API or controllers
    ...
tests/
  MyApp.IntegrationTests/
    MyApp.IntegrationTests.csproj
    Endpoints/
      InviteEndpointsTests.cs
    Infrastructure/
      TestWebApplicationFactory.cs
```

The fixture:

```csharp
// tests/MyApp.IntegrationTests/Infrastructure/TestWebApplicationFactory.cs
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;

namespace MyApp.IntegrationTests.Infrastructure;

public sealed class TestWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureServices(services =>
        {
            // Swap real DbContext for in-memory SQLite for fast deterministic tests.
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlite("DataSource=:memory:"));

            // Reset DB once per factory instance.
            using var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.OpenConnection();
            db.Database.EnsureCreated();
        });
    }
}
```

The test:

```csharp
// tests/MyApp.IntegrationTests/Endpoints/InviteEndpointsTests.cs
using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using MyApp.IntegrationTests.Infrastructure;
using Xunit;

namespace MyApp.IntegrationTests.Endpoints;

public sealed class InviteEndpointsTests : IClassFixture<TestWebApplicationFactory>
{
    private readonly TestWebApplicationFactory _factory;

    public InviteEndpointsTests(TestWebApplicationFactory factory) => _factory = factory;

    [Fact]
    public async Task PostInvite_WithValidBody_Returns201AndPayload()
    {
        var client = _factory.CreateClient();
        client.DefaultRequestHeaders.Add("Cookie", "session=test_session_token");

        var response = await client.PostAsJsonAsync("/api/invite", new
        {
            HouseholdId = "hh_test",
            Email = "user@example.com",
        });

        response.StatusCode.Should().Be(HttpStatusCode.Created);
        var body = await response.Content.ReadFromJsonAsync<InvitePayload>();
        body.Should().NotBeNull();
        body!.Token.Should().StartWith("inv_");
    }

    [Fact]
    public async Task PostInvite_WithoutAuth_Returns401()
    {
        var client = _factory.CreateClient();

        var response = await client.PostAsJsonAsync("/api/invite", new
        {
            HouseholdId = "hh_test",
            Email = "user@example.com",
        });

        response.StatusCode.Should().Be(HttpStatusCode.Unauthorized);
    }

    private sealed record InvitePayload(string Token);
}
```

Notice:
- `IClassFixture<TestWebApplicationFactory>` shares the factory across tests in the class — fast.
- The test exercises the *real* middleware pipeline. If auth is misconfigured, the integration test catches it; a unit test of the handler wouldn't.
- `FluentAssertions` for readable assertions (idiomatic in .NET land, narrows mental jump from `Assert.Equal(expected, actual)` to readable English).
- `InvitePayload` is a private nested `record` — minimal, used only by this test class.

### 2b. xUnit `[Theory]` (table-driven)

```csharp
public sealed class ValidateTokenTests
{
    [Theory]
    [InlineData("inv_abc123def456ghij", true, "abc123def456ghij")]
    [InlineData("", false, null)]
    [InlineData("malformed", false, null)]
    [InlineData("inv_TOOSHORT", false, null)]
    public void ValidateToken_ReturnsExpected(string input, bool ok, string? extracted)
    {
        var result = InviteTokens.Validate(input);
        result.IsValid.Should().Be(ok);
        result.Extracted.Should().Be(extracted);
    }
}
```

`[Theory]` + `[InlineData]` is xUnit's table-driven shape — the C# analogue to Go's `tests := []struct{...}{...}`. Cheap, readable, scales to dozens of cases.

### 2c. Cancellation token (Cleary's signature pattern)

```csharp
[Fact]
public async Task LongRunningOp_RespectsCancellation()
{
    using var cts = new CancellationTokenSource();
    var task = _service.RunAsync(cts.Token);

    cts.Cancel();

    await Assert.ThrowsAsync<OperationCanceledException>(() => task);
}
```

Write this *before* implementing the long-running op — it ensures cancellation is a first-class requirement, not retrofitted. (Cleary's Cookbook treats cancellation as a property to test, not an implementation detail.)

### 2d. Run it. Confirm RED.

```bash
dotnet test
```

Or with watch mode for inner-loop feedback:

```bash
dotnet watch --project tests/MyApp.IntegrationTests test
```

If it's accidentally green, your test isn't exercising the change — tighten the assertion.

---

## Step 3: Implement to GREEN

Apply Torgersen's "construct it valid or it doesn't compile" + Fowler's minimal API shape:

```csharp
// src/MyApp/Program.cs
using MyApp.Endpoints;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseNpgsql(builder.Configuration.GetConnectionString("Default")));
builder.Services.AddScoped<IInviteService, InviteService>();
builder.Services.AddAuthentication(/* ... */);

var app = builder.Build();

app.UseAuthentication();
app.MapInviteEndpoints();

app.Run();

public partial class Program; // expose for WebApplicationFactory<Program>
```

```csharp
// src/MyApp/Endpoints/InviteEndpoints.cs
namespace MyApp.Endpoints;

public sealed record CreateInviteRequest
{
    public required string HouseholdId { get; init; }
    public required string Email { get; init; }
}

public sealed record InvitePayload(string Token);

public static class InviteEndpoints
{
    public static IEndpointRouteBuilder MapInviteEndpoints(this IEndpointRouteBuilder app)
    {
        app.MapPost("/api/invite", async (
            CreateInviteRequest req,
            IInviteService service,
            HttpContext httpContext,
            CancellationToken ct) =>
        {
            var user = httpContext.User;
            if (user.Identity?.IsAuthenticated != true)
                return Results.Unauthorized();

            var token = await service.CreateAsync(req.HouseholdId, req.Email, ct);
            return Results.Created($"/api/invite/{token}", new InvitePayload(token));
        });

        return app;
    }
}
```

Notice:
- `record` with `required` members on the request — invalid construction fails to compile (Torgersen). The model binder still validates the wire shape; the type system catches programmer error.
- `CancellationToken` is the *last* parameter and bound automatically by ASP.NET Core — passed through to async calls.
- No try/catch swallowing exceptions. Errors propagate; ASP.NET Core middleware turns them into 500 (or whatever the exception handler middleware says).
- `Results.Created(...)` — Fowler's minimal API result helpers.

Run the test. Confirm green:

```bash
dotnet test --filter "FullyQualifiedName~InviteEndpointsTests"
```

Then the full suite + build:

```bash
dotnet build --no-incremental && dotnet test
```

If `dotnet build` warnings show NRT issues (CS8600, CS8602, CS8625), **fix them** rather than silencing. The whole point of NRTs is to surface them. (Torgersen + Skeet.)

---

## Step 4: REFACTOR while green

Common refactor wins in modern C#:

- **Convert classes to `record`s** where they're DTOs or value objects. `record` gives value equality + `with`-copy + minimal ceremony.
- **Add `required` to constructor-set properties** that can't have a sensible default — moves runtime validation to compile-time.
- **Collapse `if (x == null) throw new ArgumentNullException(nameof(x))` into an NRT-annotated parameter** (`string x` instead of `string? x`); the type system carries the contract.
- **Replace `async Task<T> Foo()` that returns synchronously with `Task.FromResult<T>(...)`** — but only if it's genuinely sync. If it does I/O, keep it `async`.
- **Remove `Result` / `.Wait()` / `Task.Run(() => something)` if you find any** — they're the canonical .NET deadlock causes (Cleary).
- **Push interfaces into the consumer.** If `IInviteService` is used only by `InviteEndpoints`, move the interface declaration next to the endpoint, not next to the implementation. (Fowler — "don't add an interface until you need a second implementation.")

After every refactor, re-run `dotnet test`. Stay green. Stop refactoring when the code is clear.

---

## Step 5: Hand back to `tdd-loop` for the fact commit

Return:

```json
{
  "ac_id": "AC#2",
  "test_files": ["tests/MyApp.IntegrationTests/Endpoints/InviteEndpointsTests.cs"],
  "impl_files": [
    "src/MyApp/Endpoints/InviteEndpoints.cs",
    "src/MyApp/Services/InviteService.cs"
  ],
  "verify_command": "dotnet test --filter \"FullyQualifiedName~InviteEndpointsTests\"",
  "full_suite_verify": "dotnet build --no-incremental && dotnet test",
  "test_shape": "webapp-factory-integration"
}
```

The `test_shape` field (`webapp-factory-integration` / `theory-inline-data` / `cancellation` / `unit`) helps the WhiteBox `code-review` sub-skill pick its own depth.

---

## Anti-patterns (with attribution)

- **`Moq` mock-per-controller suites.** The post-NRT .NET center of gravity is Detroit — integration tests via `WebApplicationFactory` exercise more of what actually breaks in prod. (Lock + Fowler.)
- **MVC controllers as the default shape for JSON APIs.** Minimal APIs are the modern idiom; use MVC only when you need filter pipelines, model binding behaviors, or Razor. (Lock + Fowler.)
- **Disabling NRTs (`<Nullable>disable</Nullable>`) to silence warnings.** The whole point is to surface them. (Torgersen.)
- **`async void` methods (other than event handlers).** Can't be awaited; exceptions go to `SynchronizationContext`; almost always a bug. (Cleary.)
- **`.Result` or `.Wait()` on a `Task`.** Canonical deadlock. The fix is to make the caller `async`. (Cleary.)
- **`Task.Run(() => SomethingSynchronous())` to "make it async".** Doesn't make it async — moves the sync work to a thread-pool thread, costing a thread for the duration. (Cleary.)
- **`DateTime.Now` in production code.** Untestable, ambient. Inject `TimeProvider` (or a `Func<DateTimeOffset>` Clock) and use `FakeTimeProvider` from `Microsoft.Extensions.TimeProvider.Testing` in tests. (Skeet — Noda Time's foundational principle.)
- **`InMemoryDatabase` provider when you'll deploy on Postgres/SQL Server.** It's not relational — joins behave differently, transactions are no-ops, query translation is partial. Use SQLite-in-memory for fast tests with relational fidelity, or Testcontainers for the real database. (Lock.)
- **Asserting on exception messages via `.Message.Contains(...)`.** Brittle; couples test to wording. Use `Assert.ThrowsAsync<TException>(...)` (xUnit) or `FluentAssertions`' `.Should().ThrowAsync<TException>()`. The exception *type* is the contract.
- **Generated mocks for an interface used by exactly one consumer.** Hand-rolled fake with a 20-line class is clearer than 200 lines of `Mock<T>` setup boilerplate. (Cross-stack TDD pattern; James Shore's Nullables ported to C#.)

---

## Output the parent skill consumes

```json
{
  "ac_id": "AC#2",
  "test_files": ["tests/MyApp.IntegrationTests/Endpoints/InviteEndpointsTests.cs"],
  "impl_files": [
    "src/MyApp/Endpoints/InviteEndpoints.cs",
    "src/MyApp/Services/InviteService.cs"
  ],
  "verify_command": "dotnet test --filter \"FullyQualifiedName~InviteEndpointsTests\"",
  "full_suite_verify": "dotnet build --no-incremental && dotnet test",
  "test_shape": "webapp-factory-integration"
}
```

---

## What this skill does NOT do

- Does not write the fact commit (that's `tdd-loop`)
- Does not push the branch or open the PR (that's `tdd-loop`)
- Does not scaffold a fresh .NET project (future `scaffold-aspnet-minimal`)
- Does not run benchmarks — BenchmarkDotNet is a separate concern
- Does not adopt third-party test frameworks (NUnit, MSTest) — xUnit is the chosen default
- Does not write Razor / Blazor view tests — those are a separate concern with bUnit
- Does not configure CI (separate WP, `.github/workflows/*`)
