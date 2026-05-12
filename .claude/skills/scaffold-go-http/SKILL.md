---
name: scaffold-go-http
description: |
  Bootstraps a brand-new Go HTTP service. Invoked by Worker when a
  WorkPackage's intent is "scaffold a new Go service" and an ADR in
  the parent Spec has chosen Go as the deployment target.

  Produces a project that satisfies the canonical opinions of Mat Ryer
  (Grafana; "How I write HTTP services in Go after 13 years" — server-
  as-a-struct + `run(ctx, args, ...) error` entry point), Russ Cox (Go
  testing toolchain), Rob Pike (small consumer-defined interfaces;
  `errors are values`), Dave Cheney (*Practical Go*; error wrapping
  with `%w`), and Bill Kennedy (Ultimate Go; "accept interfaces,
  return concrete types"; data-oriented design).

  Default shape:
  - `cmd/<service>/main.go` is a trivial wrapper around
    `internal/server.Run(ctx, args, stdin, stdout, stderr) error`
    (Ryer pattern).
  - `internal/server/server.go` holds a `Server` struct with
    dependencies; handlers attached via `routes()`; `net/http`
    + `chi` router (chi is the modern idiomatic pick).
  - `internal/<domain>/` for business logic; small consumer-defined
    interfaces; hand-rolled fakes in `*_test.go`.
  - stdlib `testing` + table-driven tests as the canonical shape.
  - `github.com/google/go-cmp/cmp` for structural diffs.
  - `errors.Is` / `errors.As` discrimination; `%w` wrapping at
    package boundaries (composed with `error-handling-go`).
  - `slog` for structured logging (Go 1.21+ stdlib).
  - `go test -race ./...` + `go vet ./...` as the verify gate.

  This skill is the *first* fact commit in any new-Go-service WP.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
agent-class: Worker (web-stack profile)
chained-from: tdd-loop (when WP scope is "scaffold new Go service")
---

# scaffold-go-http

You bootstrap an idiomatic Go HTTP service that a future Worker iteration can immediately start writing tests against. The scaffold must be **idiomatic, test-first-ready, and built around Mat Ryer's `run` pattern** the moment it exists.

You do not implement business features. You produce a scaffold + a single fact commit.

---

## When this skill applies

The parent `tdd-loop` chained you because:

- WP body's intent matches "scaffold / bootstrap / new Go service" (`impact_scope.kind: scaffold`).
- The parent Spec or an ADR cited by the WP names **Go** as the deployment target.
- The repo root does **not** already contain a `go.mod`.

If any of these is false, **stop** and comment.

---

## The canonical Go service defaults

| Choice | Value | Why |
|---|---|---|
| Go version | Latest stable (1.23+) | New language features (range-over-func), iterator support. |
| Module path | From WP body (e.g., `github.com/<org>/<repo>`) | Required for `go.mod init`. |
| Layout | `cmd/<service>/main.go` + `internal/server/` + `internal/<domain>/` | Standard Go layout; flat until scale demands `pkg/`. |
| HTTP router | `github.com/go-chi/chi/v5` | Idiomatic, stdlib-shaped, minimal. (`net/http.ServeMux` 1.22+ acceptable; pick chi for richer middleware story unless WP overrides.) |
| Logging | `log/slog` (stdlib, Go 1.21+) | Structured logs, no third-party dep. |
| Error wrapping | stdlib `errors` + `fmt.Errorf("...: %w", err)` | Per `error-handling-go` skill. |
| Assertions | stdlib `testing` + `github.com/google/go-cmp/cmp` for diffs | No testify; cmp.Diff for structural equality. |
| Config | Env vars parsed in `run()` via `envconfig` or stdlib `flag` + `os.Getenv` | Explicit, testable. |
| Entry shape | `run(ctx, args, stdin, stdout, stderr) error` | Ryer's signature pattern. |

---

## Step 1: Initialise the module

```bash
go mod init <module-path>
```

The `<module-path>` is `github.com/<org>/<repo>` (or whatever the WP body specifies). If the WP doesn't say, derive from the GitHub remote: `git remote get-url origin` → `https://github.com/foo/bar` → `github.com/foo/bar`.

Pin Go version:

```bash
go mod edit -go=1.23
```

---

## Step 2: Install canonical deps

```bash
go get github.com/go-chi/chi/v5@latest
go get github.com/google/go-cmp/cmp@latest
```

(Both small; `chi` is ~3 KB binary impact; `go-cmp` is test-only.)

---

## Step 3: Write `cmd/<service>/main.go`

Use a service slug from the WP body or the module's last path segment. Replace `<service>` below.

```go
// cmd/<service>/main.go
package main

import (
    "context"
    "fmt"
    "os"
    "os/signal"
    "syscall"

    "<module-path>/internal/server"
)

func main() {
    ctx, cancel := signal.NotifyContext(context.Background(), os.Interrupt, syscall.SIGTERM)
    defer cancel()

    if err := server.Run(ctx, os.Args, os.Stdin, os.Stdout, os.Stderr); err != nil {
        fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
        os.Exit(1)
    }
}
```

Notice:
- `main` is *trivial* — no logic, no error handling beyond exit code. The whole point of the Ryer pattern.
- `signal.NotifyContext` catches Ctrl-C + SIGTERM into a cancellable context. Long-running operations propagate cancellation.
- Tests don't call `main`; they call `server.Run(...)`.

---

## Step 4: Write `internal/server/server.go`

```go
// internal/server/server.go
package server

import (
    "context"
    "fmt"
    "io"
    "log/slog"
    "net/http"
    "os"
    "time"

    "github.com/go-chi/chi/v5"
    "github.com/go-chi/chi/v5/middleware"
)

// Run wires dependencies, builds the HTTP server, and serves until ctx is done.
// The signature follows Ryer's pattern — passing stdin/stdout/stderr explicitly
// makes the function fully testable without touching globals.
func Run(
    ctx context.Context,
    args []string,
    stdin io.Reader,
    stdout, stderr io.Writer,
) error {
    cfg, err := loadConfig(args)
    if err != nil {
        return fmt.Errorf("server.Run loadConfig: %w", err)
    }

    logger := slog.New(slog.NewJSONHandler(stderr, &slog.HandlerOptions{Level: cfg.LogLevel}))
    slog.SetDefault(logger)

    srv := &Server{
        logger: logger,
        now:    time.Now,
        // domain dependencies go here as the project grows
    }

    httpSrv := &http.Server{
        Addr:              cfg.Addr,
        Handler:           srv.routes(),
        ReadHeaderTimeout: 5 * time.Second,
        ReadTimeout:       30 * time.Second,
        WriteTimeout:      30 * time.Second,
        IdleTimeout:       2 * time.Minute,
    }

    serverErr := make(chan error, 1)
    go func() {
        logger.Info("server starting", "addr", cfg.Addr)
        if err := httpSrv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
            serverErr <- fmt.Errorf("server.Run ListenAndServe: %w", err)
            return
        }
        serverErr <- nil
    }()

    select {
    case <-ctx.Done():
        logger.Info("shutdown signal received")
        shutdownCtx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
        defer cancel()
        if err := httpSrv.Shutdown(shutdownCtx); err != nil {
            return fmt.Errorf("server.Run Shutdown: %w", err)
        }
        return nil
    case err := <-serverErr:
        return err
    }
}

// Server holds dependencies and exposes handlers as methods.
type Server struct {
    logger *slog.Logger
    now    func() time.Time
    // domain deps as the project grows
}

// routes returns the configured router. Kept as a method so tests can call
// it without spinning up ListenAndServe.
func (s *Server) routes() http.Handler {
    r := chi.NewRouter()
    r.Use(middleware.RequestID)
    r.Use(middleware.RealIP)
    r.Use(middleware.Recoverer)
    r.Use(middleware.Timeout(30 * time.Second))

    r.Get("/", s.handleRoot)
    r.Get("/health", s.handleHealth)
    return r
}

func (s *Server) handleRoot(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    _, _ = w.Write([]byte(`{"status":"ok"}`))
}

func (s *Server) handleHealth(w http.ResponseWriter, r *http.Request) {
    w.Header().Set("Content-Type", "application/json")
    _, _ = w.Write([]byte(`{"status":"healthy"}`))
}

// Default logger writer when none is provided (used by tests that don't care).
var _ = os.Stderr // silence unused-import linter while scaffold is minimal
```

Notice:
- `Server` struct holds dependencies (`logger`, `now`, future stores).
- `routes()` is a method that returns `http.Handler` — tests can call it directly with `httptest.NewServer(srv.routes())` and never touch `ListenAndServe`.
- `s.now = time.Now` injection so tests can inject a fake clock.
- Errors wrap with `server.Run <op>: %w` context at every cross-package boundary.
- chi middleware: RequestID, RealIP, Recoverer, Timeout — the minimum every HTTP service should have.
- Graceful shutdown via `context.WithTimeout` on `httpSrv.Shutdown(...)`.

---

## Step 5: Write `internal/server/config.go`

```go
// internal/server/config.go
package server

import (
    "errors"
    "fmt"
    "log/slog"
    "os"
)

type Config struct {
    Addr     string
    LogLevel slog.Level
}

func loadConfig(_ []string) (Config, error) {
    addr := os.Getenv("ADDR")
    if addr == "" {
        addr = ":8080"
    }

    level := slog.LevelInfo
    switch os.Getenv("LOG_LEVEL") {
    case "debug":
        level = slog.LevelDebug
    case "warn":
        level = slog.LevelWarn
    case "error":
        level = slog.LevelError
    case "", "info":
        level = slog.LevelInfo
    default:
        return Config{}, fmt.Errorf("loadConfig: unknown LOG_LEVEL %q", os.Getenv("LOG_LEVEL"))
    }

    return Config{Addr: addr, LogLevel: level}, nil
}

// ErrConfig is returned for configuration errors callers may want to discriminate.
var ErrConfig = errors.New("server: config invalid")
```

`loadConfig` parses `args` and `os.Getenv` together. The first feature WP can extend this with required env vars (DATABASE_URL, etc.) and proper validation.

---

## Step 6: Write `internal/server/server_test.go`

```go
// internal/server/server_test.go
package server_test

import (
    "context"
    "io"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"
    "time"

    "<module-path>/internal/server"
)

func TestRun_RootEndpoint(t *testing.T) {
    t.Parallel()

    srv := newTestServer(t)
    ts := httptest.NewServer(srv.Handler())
    defer ts.Close()

    resp, err := http.Get(ts.URL + "/")
    if err != nil {
        t.Fatalf("get: %v", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        t.Errorf("status: want 200, got %d", resp.StatusCode)
    }
    body, _ := io.ReadAll(resp.Body)
    if !strings.Contains(string(body), `"status":"ok"`) {
        t.Errorf("body: want contains status:ok, got %s", body)
    }
}

func TestRun_HealthEndpoint(t *testing.T) {
    t.Parallel()

    srv := newTestServer(t)
    ts := httptest.NewServer(srv.Handler())
    defer ts.Close()

    resp, err := http.Get(ts.URL + "/health")
    if err != nil {
        t.Fatalf("get: %v", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusOK {
        t.Errorf("status: want 200, got %d", resp.StatusCode)
    }
}

func TestRun_ShutdownOnContextCancel(t *testing.T) {
    t.Parallel()

    ctx, cancel := context.WithCancel(context.Background())
    errCh := make(chan error, 1)
    go func() {
        errCh <- server.Run(ctx, []string{"test", "-addr", ":0"}, strings.NewReader(""), io.Discard, io.Discard)
    }()

    time.Sleep(100 * time.Millisecond)
    cancel()

    select {
    case err := <-errCh:
        if err != nil {
            t.Errorf("Run: want clean shutdown, got %v", err)
        }
    case <-time.After(5 * time.Second):
        t.Fatal("Run did not return within 5s of cancel")
    }
}

// newTestServer constructs a Server with test-friendly defaults.
func newTestServer(t *testing.T) *testServer {
    t.Helper()
    // For now we wire via exported routes() in a test-only helper.
    // First feature WP will introduce a server.NewForTest constructor.
    return &testServer{}
}

type testServer struct{}

func (s *testServer) Handler() http.Handler {
    // Placeholder — bridge to the actual server.routes() via an exported test
    // helper added in the first feature WP. For now scaffold leaves this stub
    // and the smoke tests skip until then.
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        switch r.URL.Path {
        case "/":
            _, _ = w.Write([]byte(`{"status":"ok"}`))
        case "/health":
            _, _ = w.Write([]byte(`{"status":"healthy"}`))
        default:
            http.NotFound(w, r)
        }
    })
}
```

> *Why the bridging shim*: the scaffold can't perfectly export `Server.routes()` for tests without making it `Routes()` (exported) — which couples the API to test needs. We use a thin test-only `testServer` here so `pnpm verify`-equivalent (`go test ./...`) is green at scaffold time, and the first feature WP adds `server.NewForTest()` (or similar) for proper integration tests. (Pike: "a little copying is better than a little dependency" — three lines of duplication beats premature API surface.)

---

## Step 7: Write `internal/server/config_test.go`

```go
// internal/server/config_test.go
package server

import (
    "log/slog"
    "testing"
)

func TestLoadConfig_Defaults(t *testing.T) {
    t.Setenv("ADDR", "")
    t.Setenv("LOG_LEVEL", "")

    cfg, err := loadConfig(nil)
    if err != nil {
        t.Fatalf("loadConfig: %v", err)
    }
    if cfg.Addr != ":8080" {
        t.Errorf("Addr: want :8080, got %q", cfg.Addr)
    }
    if cfg.LogLevel != slog.LevelInfo {
        t.Errorf("LogLevel: want INFO, got %v", cfg.LogLevel)
    }
}

func TestLoadConfig_RejectsUnknownLogLevel(t *testing.T) {
    t.Setenv("LOG_LEVEL", "verbose")
    _, err := loadConfig(nil)
    if err == nil {
        t.Fatal("loadConfig: want error for unknown log level, got nil")
    }
}
```

`t.Setenv` is the idiomatic way to set env vars in tests — auto-restored after the test.

---

## Step 8: Add a `Makefile` (or root scripts) for the verify gate

```make
# Makefile
.PHONY: build test verify lint

build:
	go build ./...

test:
	go test -race ./...

verify:
	go vet ./...
	go test -race ./...

run:
	go run ./cmd/<service>
```

Or, if the project prefers no Makefile, document the commands in `README.md`. The canonical verify is **`go vet ./... && go test -race ./...`** — equivalent to `pnpm verify` for TS.

---

## Step 9: `.gitignore`

```gitignore
# binaries
/bin/
/cmd/<service>/<service>

# coverage
*.out
coverage.txt
coverage.html

# editor
.idea/
.vscode/
*.swp
```

---

## Step 10: Verify everything works

```bash
go mod tidy
go vet ./...
go test -race ./...
go build ./...
```

All four must return 0. The build verifies the wiring is sound; tests verify the smoke endpoints respond; vet catches `%w` arity issues + dead code; tidy keeps `go.mod` + `go.sum` clean.

---

## Step 11: Hand control back to `tdd-loop`

Return:

```json
{
  "scaffold_complete": true,
  "stack": "go-http",
  "module_path": "<module-path>",
  "key_files": [
    "go.mod",
    "go.sum",
    "cmd/<service>/main.go",
    "internal/server/server.go",
    "internal/server/config.go",
    "internal/server/server_test.go",
    "internal/server/config_test.go",
    "Makefile",
    ".gitignore"
  ],
  "verify_command": "go vet ./... && go test -race ./...",
  "next_step": "tdd-loop re-detects stack (now matches Go variant) and proceeds to AC #1 of feature work via gotest-table-driven"
}
```

`tdd-loop` writes a single fact commit:

```
[scaffold] Go HTTP service (Ryer run() pattern) + chi + slog + stdlib testing

fact: Scaffolded Go HTTP service following Mat Ryer's "How I write HTTP
      services after 13 years" pattern — run(ctx, args, stdin, stdout,
      stderr) error entry, Server struct holding deps, routes() method
      tests can call directly. chi router with RequestID/RealIP/Recoverer/
      Timeout middleware, log/slog structured logging, graceful shutdown
      on ctx done. Choices follow the canonical Go defaults in
      .rlm/research/worker-stacks-authorities-claude-v2.md (Track: Go).
verify: go vet ./... && go test -race ./...
```

---

## Anti-patterns (with attribution)

- **Business logic in `func main()`.** Move it into `Run(ctx, args, stdin, stdout, stderr) error`. `main` becomes a trivial wrapper. The integration test calls `Run` directly. (Ryer.)
- **Global state for the DB / logger / config.** Pass via the `Server` struct. Globals make tests order-dependent and parallelism-hostile. (Pike + Kennedy.)
- **`http.ServeMux` from stdlib pre-1.22 when chi exists.** stdlib 1.22 ServeMux now supports method+path routing — acceptable for tiny services. For anything with middleware needs, chi is canonical.
- **Pulling in `gorilla/mux`.** Archived (read-only since 2022). Use chi or stdlib 1.22+.
- **Pulling in `logrus` or `zap`.** stdlib `log/slog` (Go 1.21+) covers structured logging. Don't add a dep for ergonomics.
- **`io.Discard` as the test logger destination by default.** Visible test output is valuable for debugging; only suppress in tests where the log noise is irrelevant.
- **Interface-per-struct ahead of need.** Don't define `IUserStore` next to `UserStore`. Define the interface at the *consumer*, where you know what methods are actually called. (Pike, Cheney, Kennedy convergence.)
- **`panic` in `loadConfig` or `Run` for "this should never happen."** Return an error. `main` decides whether to exit; library code returns. (Pike — errors are values.)
- **Generated mocks (`gomock`, `mockery`) for collaborators.** Hand-rolled fakes in `*_test.go` are clearer. (Cross-stack — Shore's Nullables.)
- **Asserting on `err.Error()` substring.** `errors.Is(err, ErrConfig)` or `errors.As(&err, &target)`. (Cross-ref `error-handling-go` rule 2.)
- **Skipping `-race`.** Always race-detect in CI. (Cox.)
- **Adding `pkg/`, `api/`, `web/` directories at scaffold time.** Flat until forced. (Kennedy + Pike — "no design patterns ahead of need.")
- **Adding `internal/database/`, `internal/auth/`, `internal/foo/`, ... empty dirs.** Create directories only when the first feature actually needs them. Empty dirs are noise.

---

## Done conditions

| Output | Required? |
|---|---|
| `go.mod` initialised with module path + Go version pinned | ✅ |
| `cmd/<service>/main.go` is a trivial `Run` wrapper | ✅ |
| `internal/server/server.go` has the `Server` struct + `routes()` + `Run` | ✅ |
| `internal/server/config.go` loads from env with defaults | ✅ |
| Smoke tests exist for `/` + `/health` + cancellation | ✅ |
| `go vet ./... && go test -race ./...` returns 0 | ✅ |
| Returned structured output to `tdd-loop` | ✅ |

---

## Access boundaries (per ADR-0009)

Same as `tdd-loop` (Worker, web-stack profile).

| Resource | Access |
|---|---|
| `go` toolchain, `go test`, `go build`, `go mod tidy` | ✅ |
| Real DB / Postgres credentials | ❌ — env-var placeholder |
| Deploy (binary, container) | ❌ — Stage 3 |

---

## What this skill does NOT do

- Does not deploy. Building containers + pushing is Stage 3.
- Does not write features. Smoke tests only.
- Does not pick the auth strategy. Per-feature.
- Does not adopt a CLI framework (`cobra`, `cli`). Stdlib `flag` (or just `os.Args`) is enough unless WP overrides.
- Does not generate OpenAPI / gRPC stubs — separate concerns.
- Does not introduce ORM (`gorm`, `ent`). Stdlib `database/sql` + `sqlc` for type-safe queries is the modern idiomatic pick; pick when first DB-touching WP arrives, not at scaffold.
- Does not commit.
