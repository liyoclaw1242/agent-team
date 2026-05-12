---
name: scaffold-aspnet-minimal
description: |
  Bootstraps a brand-new ASP.NET Core minimal-API project for any
  WorkPackage whose parent Spec/ADR chose .NET as the deployment
  target. Produces a project that satisfies the canonical opinions
  of David Fowler (ASP.NET Core architect; minimal APIs as a sound
  long-term style), Andrew Lock (*ASP.NET Core in Action*, 3rd ed. —
  WebApplicationFactory<TEntryPoint> as the highest-leverage test
  surface), Mads Torgersen (C# lead designer; records + required +
  NRTs as compile-time contracts), Stephen Cleary (async-all-the-way-
  down + cancellation tokens), and Jon Skeet (contract-first typing,
  Noda Time for instants vs zoned times when the domain demands it).

  Default shape:
  - .NET 8+ minimal API (no MVC controllers; no Razor).
  - `<Nullable>enable</Nullable>` + `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>`.
  - xUnit integration test project wired with
    `Microsoft.AspNetCore.Mvc.Testing.WebApplicationFactory<Program>`.
  - EF Core with SQLite-in-memory for fast tests; Postgres
    via Npgsql.EntityFrameworkCore.PostgreSQL for prod.
  - `FluentAssertions` for readable assertion messages.
  - Zod equivalent via record + required members + ASP.NET Core's
    built-in model binding (Torgersen "construct it valid or it
    doesn't compile").
  - Strongly-typed configuration via `IOptions<T>` validated at
    startup.

  This skill is the *first* fact commit in any new-.NET-service WP.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
agent-class: Worker (web-stack profile)
chained-from: tdd-loop (when WP scope is "scaffold new .NET service")
---

# scaffold-aspnet-minimal

You bootstrap a .NET ASP.NET Core minimal-API service. The scaffold must be **opinionated, NRT-strict, and `WebApplicationFactory`-test-ready** the moment it exists.

You do not implement business features. You produce a scaffold + a single fact commit.

---

## When this skill applies

The parent `tdd-loop` chained you because:

- WP body's intent matches "scaffold / bootstrap / new .NET service" (`impact_scope.kind: scaffold`).
- The parent Spec or an ADR cited by the WP names **.NET / C#** as the deployment target.
- The repo root does **not** already contain a `*.sln` or top-level `*.csproj`.

If any of these is false, **stop** and comment.

---

## The canonical .NET defaults

| Choice | Value | Why |
|---|---|---|
| Runtime | .NET 8+ (LTS) | Modern minimal APIs + NRT defaults; supported through Nov 2026. |
| Project shape | Minimal API (no controllers) | Fowler + Lock; controllers only when you need filter pipelines or Razor. |
| Solution layout | `src/MyApp/` + `tests/MyApp.IntegrationTests/` + `tests/MyApp.UnitTests/` | Lock's standard layout. |
| Nullable | `<Nullable>enable</Nullable>` | Torgersen; non-negotiable for new code. |
| Warnings | `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` | Surface NRT warnings as build failures. |
| ORM | EF Core | Standard; works with SQLite-in-memory for tests + Postgres in prod. (Dapper if explicitly requested.) |
| Test framework | xUnit.net | The ASP.NET Core repo's choice. |
| Test fixture | `WebApplicationFactory<Program>` | Lock's highest-leverage test surface. |
| Assertions | FluentAssertions | Readable; project norm. |
| Logging | `Microsoft.Extensions.Logging` + structured logs via Serilog | Standard. |
| Config | `IOptions<T>` validated at startup with `ValidateOnStart()` | Surface bad config at boot, not first request. |

---

## Step 1: Create the solution + projects

```bash
dotnet new sln --name MyApp

dotnet new web --name MyApp --output src/MyApp --use-program-main false
dotnet sln add src/MyApp/MyApp.csproj

dotnet new xunit --name MyApp.IntegrationTests --output tests/MyApp.IntegrationTests
dotnet sln add tests/MyApp.IntegrationTests/MyApp.IntegrationTests.csproj

dotnet new xunit --name MyApp.UnitTests --output tests/MyApp.UnitTests
dotnet sln add tests/MyApp.UnitTests/MyApp.UnitTests.csproj
```

`dotnet new web` produces the minimal-API template (single `Program.cs` with top-level statements). `--use-program-main false` keeps top-level statements (cleaner; required for `WebApplicationFactory<Program>` once we expose `Program` as `partial`).

Add references:

```bash
dotnet add tests/MyApp.IntegrationTests/MyApp.IntegrationTests.csproj reference src/MyApp/MyApp.csproj
dotnet add tests/MyApp.UnitTests/MyApp.UnitTests.csproj reference src/MyApp/MyApp.csproj
```

---

## Step 2: Tighten `src/MyApp/MyApp.csproj`

```xml
<Project Sdk="Microsoft.NET.Sdk.Web">
  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <Nullable>enable</Nullable>
    <ImplicitUsings>enable</ImplicitUsings>
    <TreatWarningsAsErrors>true</TreatWarningsAsErrors>
    <WarningsNotAsErrors></WarningsNotAsErrors>
    <RootNamespace>MyApp</RootNamespace>
    <InvariantGlobalization>true</InvariantGlobalization>
  </PropertyGroup>
</Project>
```

The four critical settings:

| Setting | Effect |
|---|---|
| `<Nullable>enable</Nullable>` | NRTs on; missing-null-check is a warning |
| `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` | The warning becomes a build failure |
| `<InvariantGlobalization>true</InvariantGlobalization>` | Smaller container; consistent string compare; pick this unless you need real culture-aware sorting |
| `<ImplicitUsings>enable</ImplicitUsings>` | Less boilerplate; `using System;` etc. implicit |

---

## Step 3: Install canonical packages

For the main project:

```bash
cd src/MyApp
dotnet add package Microsoft.EntityFrameworkCore
dotnet add package Microsoft.EntityFrameworkCore.Design
dotnet add package Npgsql.EntityFrameworkCore.PostgreSQL
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
dotnet add package Serilog.AspNetCore
cd -
```

For the integration tests:

```bash
cd tests/MyApp.IntegrationTests
dotnet add package Microsoft.AspNetCore.Mvc.Testing
dotnet add package Microsoft.EntityFrameworkCore.Sqlite
dotnet add package FluentAssertions
cd -
```

For the unit tests:

```bash
cd tests/MyApp.UnitTests
dotnet add package FluentAssertions
cd -
```

---

## Step 4: Write `src/MyApp/Program.cs`

```csharp
using System.Text.Json.Serialization;
using Microsoft.EntityFrameworkCore;
using MyApp.Data;
using MyApp.Configuration;
using Serilog;

var builder = WebApplication.CreateBuilder(args);

builder.Host.UseSerilog((ctx, lc) => lc.ReadFrom.Configuration(ctx.Configuration));

builder.Services
    .AddOptions<AppOptions>()
    .Bind(builder.Configuration.GetSection("App"))
    .ValidateDataAnnotations()
    .ValidateOnStart();

builder.Services.AddDbContext<AppDbContext>(opts =>
    opts.UseNpgsql(builder.Configuration.GetConnectionString("Default")));

builder.Services.ConfigureHttpJsonOptions(o =>
{
    o.SerializerOptions.DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull;
});

var app = builder.Build();

app.UseSerilogRequestLogging();

app.MapGet("/", () => Results.Ok(new { status = "ok" }));
app.MapGet("/health", () => Results.Ok(new { status = "healthy" }));

app.Run();

// Required so WebApplicationFactory<Program> can find the entry type.
public partial class Program;
```

Notice:
- Top-level statements (no `Main`); cleaner.
- `public partial class Program;` at the bottom exposes `Program` for `WebApplicationFactory<Program>` — without this, the test project can't reference it (top-level statements generate an `internal` class by default).
- `AddOptions<AppOptions>().ValidateOnStart()` — config validation at boot, not first request. (Lock's signature pattern.)
- `Results.Ok(new { ... })` for minimal-API responses.

---

## Step 5: Create the EF Core context + a placeholder entity

```csharp
// src/MyApp/Data/AppDbContext.cs
using Microsoft.EntityFrameworkCore;

namespace MyApp.Data;

public sealed class AppDbContext(DbContextOptions<AppDbContext> options) : DbContext(options)
{
    public DbSet<ScaffoldPlaceholder> Placeholders => Set<ScaffoldPlaceholder>();
}

public sealed record ScaffoldPlaceholder
{
    public required string Id { get; init; }
    public required DateTimeOffset CreatedAt { get; init; }
}
```

The placeholder entity exists so EF Core has *something* to scaffold a migration against. The first feature WP replaces it.

---

## Step 6: Create the strongly-typed config option

```csharp
// src/MyApp/Configuration/AppOptions.cs
using System.ComponentModel.DataAnnotations;

namespace MyApp.Configuration;

public sealed record AppOptions
{
    [Required]
    [Url]
    public required string PublicUrl { get; init; }

    [Range(1, 10_000)]
    public int CacheSeconds { get; init; } = 60;
}
```

Notice `required` + DataAnnotations = "construct it valid or `ValidateOnStart` blows up at boot." (Torgersen.)

`appsettings.json`:

```json
{
  "App": {
    "PublicUrl": "http://localhost:5000",
    "CacheSeconds": 60
  },
  "ConnectionStrings": {
    "Default": "Host=localhost;Database=myapp;Username=postgres;Password=changeme"
  },
  "Serilog": {
    "MinimumLevel": "Information"
  }
}
```

`appsettings.Development.json` overrides what dev should override (typically nothing in scaffold).

---

## Step 7: Wire the `WebApplicationFactory` fixture

```csharp
// tests/MyApp.IntegrationTests/Infrastructure/TestWebApplicationFactory.cs
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Hosting;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using MyApp.Data;

namespace MyApp.IntegrationTests.Infrastructure;

public sealed class TestWebApplicationFactory : WebApplicationFactory<Program>
{
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Test");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<AppDbContext>>();
            services.AddDbContext<AppDbContext>(opts =>
                opts.UseSqlite("DataSource=:memory:"));

            using var sp = services.BuildServiceProvider();
            using var scope = sp.CreateScope();
            var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
            db.Database.OpenConnection();
            db.Database.EnsureCreated();
        });
    }
}
```

SQLite-in-memory > InMemory provider because SQLite is actually relational. `EnsureCreated` builds the schema directly from your `DbContext` without migrations — fine for tests; real migrations are a per-WP concern.

---

## Step 8: Write the smoke tests

### 8a. Integration smoke

```csharp
// tests/MyApp.IntegrationTests/HealthEndpointTests.cs
using System.Net;
using System.Net.Http.Json;
using FluentAssertions;
using MyApp.IntegrationTests.Infrastructure;
using Xunit;

namespace MyApp.IntegrationTests;

public sealed class HealthEndpointTests(TestWebApplicationFactory factory)
    : IClassFixture<TestWebApplicationFactory>
{
    private readonly TestWebApplicationFactory _factory = factory;

    [Fact]
    public async Task Get_Root_Returns200()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/");
        response.StatusCode.Should().Be(HttpStatusCode.OK);

        var body = await response.Content.ReadFromJsonAsync<StatusPayload>();
        body.Should().NotBeNull();
        body!.Status.Should().Be("ok");
    }

    [Fact]
    public async Task Get_Health_Returns200()
    {
        var client = _factory.CreateClient();
        var response = await client.GetAsync("/health");
        response.StatusCode.Should().Be(HttpStatusCode.OK);
    }

    private sealed record StatusPayload(string Status);
}
```

### 8b. Unit smoke

```csharp
// tests/MyApp.UnitTests/AppOptionsTests.cs
using FluentAssertions;
using MyApp.Configuration;
using System.ComponentModel.DataAnnotations;
using Xunit;

namespace MyApp.UnitTests;

public sealed class AppOptionsTests
{
    [Fact]
    public void Validates_PublicUrl_AsUri()
    {
        var opts = new AppOptions { PublicUrl = "not-a-url", CacheSeconds = 60 };
        var context = new ValidationContext(opts);
        var results = new List<ValidationResult>();

        var ok = Validator.TryValidateObject(opts, context, results, validateAllProperties: true);

        ok.Should().BeFalse();
        results.Should().Contain(r => r.MemberNames.Contains(nameof(AppOptions.PublicUrl)));
    }
}
```

---

## Step 9: Wire scripts in the root

`.editorconfig` (root):

```ini
root = true

[*.cs]
indent_style = space
indent_size = 4
dotnet_diagnostic.CA2007.severity = none    # ConfigureAwait(false) — Cleary says not required in ASP.NET Core; suppress noise.

[*.{csproj,json,yml}]
indent_size = 2
```

`global.json` to pin the SDK:

```json
{
  "sdk": {
    "version": "8.0.0",
    "rollForward": "latestFeature"
  }
}
```

(Adjust version to the latest LTS at scaffold time.)

There's no `package.json`-equivalent for `pnpm verify`-style aggregation; the canonical commands are:

```bash
dotnet build --no-incremental
dotnet test
```

Document them in `README.md` (or skip if the project root already has one).

---

## Step 10: Verify everything works

```bash
dotnet build --no-incremental    # must be 0 warnings, 0 errors (TreatWarningsAsErrors is on)
dotnet test                      # all smoke tests green
```

If `dotnet build` shows NRT warnings, fix them — they're not noise.

---

## Step 11: Hand control back to `tdd-loop`

Return:

```json
{
  "scaffold_complete": true,
  "stack": "dotnet-aspnet-minimal",
  "key_files": [
    "MyApp.sln",
    "src/MyApp/MyApp.csproj",
    "src/MyApp/Program.cs",
    "src/MyApp/Data/AppDbContext.cs",
    "src/MyApp/Configuration/AppOptions.cs",
    "src/MyApp/appsettings.json",
    "tests/MyApp.IntegrationTests/Infrastructure/TestWebApplicationFactory.cs",
    "tests/MyApp.IntegrationTests/HealthEndpointTests.cs",
    "tests/MyApp.UnitTests/AppOptionsTests.cs",
    "global.json",
    ".editorconfig"
  ],
  "verify_command": "dotnet build --no-incremental && dotnet test",
  "next_step": "tdd-loop re-detects stack (now matches .NET variant) and proceeds to AC #1 of feature work"
}
```

`tdd-loop` writes a single fact commit:

```
[scaffold] .NET 8 minimal API + EF Core + xUnit WebApplicationFactory

fact: Scaffolded .NET 8 minimal-API service (NRT strict, TreatWarningsAsErrors)
      with EF Core (Npgsql for prod, SQLite-in-memory for tests), Serilog
      structured logging, IOptions<T> with ValidateOnStart, WebApplicationFactory
      <Program> integration test fixture (Lock pattern), FluentAssertions.
      Choices follow the canonical .NET defaults documented in
      .rlm/research/worker-stacks-authorities-claude-v2.md (Track: C#).
verify: dotnet build --no-incremental && dotnet test
```

---

## Anti-patterns (with attribution)

- **MVC controllers as the default.** Minimal APIs are the modern shape. Use MVC only when you need filter pipelines, Razor, or specific model-binding behaviours. (Fowler + Lock.)
- **`<Nullable>disable</Nullable>` to silence warnings.** Defeats the point. Fix the code. (Torgersen.)
- **InMemory provider for EF Core tests.** It's *not* relational — joins behave differently, transactions are no-ops. Use SQLite-in-memory for fast tests with relational fidelity. (Lock.)
- **`DateTime.Now` in any production code.** Untestable. Inject `TimeProvider` (`Microsoft.Extensions.TimeProvider.Testing` provides `FakeTimeProvider`). (Skeet — Noda Time principle.)
- **Reading `Configuration["X"]` directly anywhere.** Bind to a strongly-typed options record with `IOptions<T>` and `ValidateOnStart`. (Lock.)
- **`ConfigureAwait(false)` everywhere.** Not required in ASP.NET Core (no `SynchronizationContext`). The `.editorconfig` above suppresses the CA2007 warning. (Cleary — context-specific.)
- **`Task.Run(() => SomethingSync())` to "make it async".** Doesn't. Moves sync work to thread pool. (Cleary.)
- **`async void` methods (other than event handlers).** Can't be awaited; exceptions go to `SynchronizationContext`. Almost always a bug. (Cleary.)
- **Scaffolding both an MVC project and minimal APIs to "support both styles."** Pick one. The hybrid is more code surface, not less. (Fowler.)
- **Skipping `<TreatWarningsAsErrors>true</TreatWarningsAsErrors>` because "warnings are advisory."** With NRTs they're not — they're future runtime bugs. Treat them as errors from day one.

---

## Done conditions

| Output | Required? |
|---|---|
| `MyApp.sln` + the three project files | ✅ |
| `Program.cs` is minimal-API shape with `public partial class Program;` exposed | ✅ |
| NRTs on + warnings-as-errors | ✅ |
| `AppDbContext` + `AppOptions` + appsettings | ✅ |
| `TestWebApplicationFactory` + smoke tests | ✅ |
| `dotnet build --no-incremental` returns 0 with zero warnings | ✅ |
| `dotnet test` returns 0 | ✅ |
| Returned structured output to `tdd-loop` | ✅ |

---

## Access boundaries (per ADR-0009)

Same as `tdd-loop` (Worker, web-stack profile). Standard `dotnet` CLI commands; no external secrets.

| Resource | Access |
|---|---|
| `dotnet new` / `dotnet add` / `dotnet build` / `dotnet test` | ✅ |
| Real Postgres / SQL Server credentials | ❌ — placeholder in connection string |
| Deploy (App Service, container registry) | ❌ — Stage 3 |

---

## What this skill does NOT do

- Does not connect to a real DB. Connection string defaults to `localhost`; feature WPs wire production creds.
- Does not deploy. `dotnet publish` and container build are Stage 3 (Dispatch).
- Does not write features. Smoke tests only.
- Does not pick auth strategy. JWT / cookies / Identity is feature-specific.
- Does not adopt Razor / Blazor / SignalR — those need explicit ADRs.
- Does not write `.github/workflows/*` — separate setup WP.
- Does not commit.
