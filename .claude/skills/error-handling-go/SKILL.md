---
name: error-handling-go
description: |
  Go-specific scenario skill that Worker invokes whenever it writes or
  changes Go code that crosses a package boundary. Enforces the
  "errors-as-values" idiom canonised by Rob Pike (Go co-creator) and
  Dave Cheney (`pkg/errors` author, foundational voice on Go error
  handling), as it actually landed in Go 1.13+ (`%w`, `errors.Is`,
  `errors.As`).

  Specifically:
  - Wrap with `fmt.Errorf("...: %w", err)` at every package boundary
    that adds meaningful context.
  - Use `errors.Is` / `errors.As` for discrimination — never `==` on
    error values, never type assertions.
  - Minimise sentinel errors; reserve them for stable public API
    contracts (`io.EOF`-style). For internal discrimination, prefer
    behaviour assertions on small interfaces (`interface{ Temporary() bool }`).
  - Treat errors as part of the public API — name them deliberately,
    test them like return values.
  - Never `panic` for control flow.

  This skill is *not* a TDD loop on its own — it's an idiom enforcer
  that `tdd-loop` consults whenever the WP touches Go code. The TDD
  cycle itself is driven by `gotest-table-driven` (future sibling
  skill).
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
agent-class: Worker (web-stack profile)
chained-from: tdd-loop (when stack is Go AND the diff touches error-returning code)
---

# error-handling-go

You write Go code that takes errors seriously. **Errors are values** — Rob Pike's framing — and you treat them with the same care as data: name them, wrap them with context as they cross package boundaries, discriminate them with `errors.Is` / `errors.As`, and put them in the public API on purpose.

This skill applies whenever the diff for the current AC touches Go code that returns or handles an `error`. It does not run independently — it composes into `tdd-loop`'s RGR cycle.

---

## When this skill applies

`tdd-loop` chained you because:

- Detected stack is Go (`go.mod` exists)
- The current AC's `impact_scope.files` includes `*.go` files
- The diff would add or modify code that returns `error` or handles one

If only docs (`*.md`) or test data (`testdata/*`) are touched, this skill does not apply — return immediately without enforcement.

---

## The four error patterns Cheney identified — pick one deliberately

Per Dave Cheney's "Don't just check errors, handle them gracefully" + its `pkg/errors` follow-up, every error-returning function makes one of four choices. The skill enforces choosing *deliberately*, not by accident.

### Pattern 1: Sentinel error (rare)

```go
package db

import "errors"

// ErrNotFound is returned when a row lookup yields nothing.
// It is part of the package's public API; callers may compare with errors.Is.
var ErrNotFound = errors.New("db: not found")
```

Use sentinels **only** when:
- The error needs to be discriminated by callers in *other* packages, AND
- The shape of the error is stable (you won't want to add fields later).

`io.EOF` is the canonical good example: every reader caller compares with `== io.EOF` (or now `errors.Is(err, io.EOF)`), and the value has been stable for 15+ years.

If you find yourself adding a sentinel because "the caller might want to know" — stop. Cheney's rule: *minimise sentinels.* Most discrimination is better served by behaviour assertions (pattern 4).

### Pattern 2: Error type (sometimes)

```go
package db

type QueryError struct {
    SQL  string
    Wrapped error
}

func (e *QueryError) Error() string {
    return fmt.Sprintf("db: query %q failed: %v", e.SQL, e.Wrapped)
}

func (e *QueryError) Unwrap() error { return e.Wrapped }
```

Use error types when:
- Callers need to extract structured data from the error (the SQL, an HTTP status code, a retry-after duration).
- One error category needs multiple instances with different fields.

Always implement `Unwrap() error` if you wrap another error, so `errors.Is` / `errors.As` traverse correctly.

### Pattern 3: Opaque error (default)

```go
func (s *Server) handleInvite(w http.ResponseWriter, r *http.Request) {
    user, err := s.auth.RequireUser(r)
    if err != nil {
        return fmt.Errorf("handleInvite: auth: %w", err)
    }
    // ...
}
```

The *default* shape: wrap with `%w` to preserve the chain, add the function/operation name as context, hand back. The caller can `errors.Is` against known sentinels deeper in the chain or `errors.As` to extract typed errors — they don't need to know about your wrapping.

The wrapping context should answer "what was the system trying to do when this happened?", not duplicate the wrapped error's message. `"handleInvite: auth: %w"` is good; `"failed to do auth: %w"` is bad — the `%w` already says "failed."

### Pattern 4: Behaviour assertion (preferred for discrimination)

```go
// In any package that wants to know "is this a retryable error?":
type temporaryError interface {
    Temporary() bool
}

func isRetryable(err error) bool {
    var t temporaryError
    return errors.As(err, &t) && t.Temporary()
}
```

When you need to *discriminate* an error without coupling to a specific package's sentinel or type, define a small interface at the *consumer* (matching Pike's "consumer-defined interfaces are smaller and better") and use `errors.As`.

`net.Error` does this canonically with `Timeout() bool` and `Temporary() bool`. Most "is this transient?" checks should follow the same shape.

---

## The five hard rules

### Rule 1: Wrap with `%w` at every package boundary that adds context

Inside a package, naked `return err` is fine. The moment the error crosses into another package's caller, wrap it with the function name + intent:

```go
// Inside package db:
func (s *Store) GetUser(ctx context.Context, id string) (*User, error) {
    row, err := s.pool.QueryRow(ctx, "SELECT ... WHERE id=$1", id)
    if err != nil {
        return nil, err  // OK inside the same package
    }
    var u User
    if err := row.Scan(&u.ID, &u.Email); err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, ErrNotFound  // sentinel — public API
        }
        return nil, fmt.Errorf("db.Store.GetUser scan: %w", err)
    }
    return &u, nil
}
```

The Validator (`code-review` sub-skill) will flag any `return err` that crosses a package boundary without context.

### Rule 2: Never `==` on error values

```go
// WRONG
if err == sql.ErrNoRows { ... }

// RIGHT
if errors.Is(err, sql.ErrNoRows) { ... }
```

`==` only matches the exact error value. `errors.Is` walks the wrap chain. If `db.Store.GetUser` wraps `pgx.ErrNoRows` (which itself wraps something), only `errors.Is` reaches all the way through.

The single exception: comparing to `nil`. `if err == nil` and `if err != nil` are correct and idiomatic.

### Rule 3: Never type-assert on errors

```go
// WRONG
if qe, ok := err.(*QueryError); ok { ... }

// RIGHT
var qe *QueryError
if errors.As(err, &qe) { ... }
```

Same reason as rule 2 — `errors.As` walks the chain; type assertion only looks at the outermost value.

### Rule 4: `panic` is for impossible states, not for errors

```go
// WRONG
file, err := os.Open(path)
if err != nil {
    panic(err)
}

// RIGHT — propagate
file, err := os.Open(path)
if err != nil {
    return fmt.Errorf("openConfig: %w", err)
}

// RIGHT — only when reaching this line proves a precondition the type
// system can't express has been violated, AND the program cannot
// continue meaningfully:
case Active:
    return s.active(ctx)
case Pending:
    return s.pending(ctx)
default:
    panic(fmt.Sprintf("unreachable: unexpected state %v", s.State))
}
```

`panic` is for the cases where continuing would be more dangerous than crashing. File-not-found is *not* one of those cases. (Rob Pike's Go Proverbs are explicit: errors are values, not panic fodder.)

### Rule 5: Errors are part of the public API — name them, document them, test them

```go
// Package db provides access to the household store.
//
// GetUser returns ErrNotFound when no row matches the given id.
// All other errors are opaque and should be treated as internal.
package db
```

If a sentinel is part of the public API, the package doc says so. If an error type is exported, its godoc explains what it carries. Tests cover both the happy path *and* the named error path:

```go
func TestStore_GetUser_NotFound(t *testing.T) {
    s := newTestStore(t)
    _, err := s.GetUser(ctx, "nonexistent")
    if !errors.Is(err, db.ErrNotFound) {
        t.Fatalf("want ErrNotFound, got %v", err)
    }
}
```

(This composes with `gotest-table-driven` for the actual test shape.)

---

## Step-by-step: applying this skill within an RGR cycle

`tdd-loop` is in the middle of an AC. The TDD sub-skill (future `gotest-table-driven`) has written a failing test. You are writing the implementation.

1. **Identify every error-returning call site in the code you're about to write.** Walk the chain mentally: where does each error originate, what packages does it cross, what callers will discriminate it?

2. **Pick the pattern for each new error you create:**
   - Will external packages need to discriminate it? → sentinel or error type (decide by whether structured data is needed).
   - Is it purely internal context-adding? → opaque, wrap with `%w`.
   - Are you discriminating on cross-package errors? → behaviour interface, `errors.As`.

3. **Implement.** Apply the five rules.

4. **Re-read the diff before handing back to `tdd-loop`.** Specifically:
   - Every cross-package `return err` has been wrapped or is intentional naked propagation.
   - No `==` on errors except against `nil`.
   - No type assertions on errors.
   - No sentinels added "just in case" — each one earns its keep.
   - Public sentinels and types are documented in the package godoc.

5. **Run `go vet ./...`** — it catches a non-trivial subset of these issues automatically (especially `%w` arity mismatches and unreachable returns).

6. **Run `errcheck` if available** (`go install github.com/kisielk/errcheck@latest`). Many error-handling bugs are silently dropped returns — `errcheck` is the canonical tool to flag them.

7. **Hand back to the TDD sub-skill** for the GREEN check + REFACTOR pass.

---

## Anti-patterns (with attribution)

- **`return err` across package boundaries with no context.** The caller sees the error but can't tell *where* it happened. (Cheney — "Don't just check errors.") Worker's `code-review` validator sub-skill flags this.
- **Logging *and* returning the same error.** Double-reported errors clutter logs and make root-cause analysis hard. Either log at the top-level handler (where you swallow the chain) or return; never both. (Cheney.)
- **`panic` instead of returning an error.** The function's caller cannot recover, and the stack trace points to the panic site, not the chain that led there. (Pike — errors are values, not exceptions.)
- **Generated mocks for an `error`-returning interface.** Use a hand-rolled fake or a `nullX` struct (Shore's *Nullables* pattern, ported to Go). `gomock` for `interface { GetUser(...) error }` is overkill. (Kennedy + Cheney.)
- **Sentinel errors for every distinct failure.** Three sentinels in one package usually means none of them earned their keep. Consolidate into one error type with a kind field, or use behaviour assertions. (Cheney — *minimise sentinels.*)
- **`fmt.Errorf("%v", err)` instead of `%w`.** `%v` formats the error message; `%w` wraps it so the chain is traversable. Always `%w` unless you specifically want to break the chain (rare). (Go 1.13 errors package, codified Cheney's `pkg/errors`.)
- **Comparing errors with `strings.Contains(err.Error(), "...")`.** Brittle; couples your code to the wording of someone else's error message. Use `errors.Is` against a sentinel, or `errors.As` against a type, or define a behaviour interface. (Cheney + Cox.)

---

## Done conditions (for the error-handling slice of an AC)

| Check | Required? |
|---|---|
| `go vet ./...` returns 0 | ✅ |
| Every cross-package `return err` is wrapped with `%w` + context OR is intentional naked propagation | ✅ |
| No `==` comparisons on error values (except `== nil` / `!= nil`) | ✅ |
| No `.(*ErrorType)` type assertions on errors — use `errors.As` | ✅ |
| Exported sentinels / error types are documented in package godoc | ✅ |
| Tests cover at least one named error path (per the AC, not exhaustive) | ✅ |
| No `panic` introduced for control flow | ✅ |

If any of these fail, **fix before returning to `tdd-loop`** — don't push idiomatic-Go-violation up to the validator and call it green.

---

## Access boundaries (per ADR-0009)

Same as `tdd-loop` (Worker, web-stack profile). This skill writes Go code; access boundaries don't change.

---

## What this skill does NOT do

- Does not run the test loop (`gotest-table-driven` does, when written)
- Does not write the test itself — only enforces idiom in the code under test
- Does not pick a logging library (`slog` is the Go 1.21+ default; pick that unless the WP overrides)
- Does not introduce `github.com/pkg/errors` — it predates Go 1.13's `%w` and is obsolete for new code (use stdlib `errors` + `fmt.Errorf`)
- Does not handle concurrency-specific error patterns (errgroup, channel-of-errors, context cancellation) — those compose in a future `goroutine-patterns` skill
- Does not modify other languages' code — TS/C#/Cloudflare have separate error idiom skills (or none, when the language's own conventions are well-understood)
