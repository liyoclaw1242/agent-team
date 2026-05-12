---
name: gotest-table-driven
description: |
  Go-flavoured TDD sub-skill, chained from `tdd-loop` whenever the
  detected stack is Go (`go.mod` exists). Implements the firmly-Detroit
  Go testing idiom canonised by Rob Pike (Go co-creator), Russ Cox (Go
  testing toolchain), Dave Cheney (`pkg/errors`, *Practical Go*), Bill
  Kennedy (Ultimate Go), and Mat Ryer (Grafana; `matryer/is`; server-as-
  struct).

  Specifically:
  - **Table-driven tests** as the canonical shape for any function with
    branching (`[]struct{ name, in, want, wantErr string }`).
  - **Hand-rolled fakes** for collaborators, not mocking frameworks.
    Define interfaces at the *consumer*, keep them tiny (Pike, Cheney,
    Kennedy).
  - **`testdata/` + golden files** with a `-update` flag for any
    parser/printer/formatter output (Cox).
  - **`go test -race ./...`** before exiting an RGR cycle.
  - **Example tests** (`ExampleFoo`) that double as godoc when a
    function's contract is well-suited to a single canonical use.
  - **Fuzz tests** (`func FuzzFoo(f *testing.F)`) for any byte/string
    parser (Cox; Go 1.18+).
  - Pair with `error-handling-go` whenever the AC touches error paths.

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
chained-from: tdd-loop (when stack is Go)
---

# gotest-table-driven

You drive one RGR cycle in Go for one Acceptance Criterion. Your test runner is the stdlib `testing` package — no framework. Your testing model is **firmly Detroit**: real collaborators where bearable, small consumer-defined interfaces, hand-rolled fakes when isolation is genuinely needed, table-driven tests as the default shape.

You do not use `gomock`, `testify/mock`, or any mock-generation framework. (Kennedy + Cheney + Ryer convergence: mocking frameworks are culturally suspect; hand-rolled fakes are clearer and rarely longer.)

---

## When this sub-skill applies

The parent `tdd-loop` chained you because:

- `go.mod` exists at the repo root
- The current AC's `impact_scope.files` includes `*.go` files

If `go.mod` is missing entirely, the parent should have routed to a future `scaffold-go-http` first. Don't try to bootstrap a module yourself; return immediately with a clear note.

---

## Inputs (passed by `tdd-loop`)

- The specific AC under this iteration (text + ID)
- The WP's `impact_scope.files` — where you're allowed to write code
- The `error-handling-go` skill's findings if the diff touches error paths (run that skill in parallel for the implementation side; this skill drives the test side)

---

## Step 1: Translate the AC into the right test shape

Go has four canonical test shapes. Pick deliberately:

| AC shape | Test shape |
|---|---|
| "Function `parseInvite` returns the token, or an error for malformed input" | **Table-driven** test with multiple `tc.in` / `tc.want` / `tc.wantErr` rows. |
| "Server handles POST /api/invite with status 201 + body shape X" | **HTTP integration** test via `net/http/httptest.NewServer` + the server-as-struct's `routes()`. |
| "Function `FormatLogLine(e)` produces output matching the golden fixture for each known shape" | **Golden file** test in `testdata/`, with a `-update` flag to regenerate. |
| "Function `ParseHeader(b []byte)` never panics regardless of input" | **Fuzz test** (`func FuzzParseHeader(f *testing.F)`). |
| "The package's main canonical use looks like: ..." | **Example test** (`func ExampleNew()`) that doubles as godoc. |

A single AC sometimes wants both a table-driven *and* a golden test (parser AC that asserts both behaviour and exact output). Write both — they're cheap.

---

## Step 2: Write the failing test

### 2a. Table-driven (the default)

```go
// internal/invite/parse_test.go
package invite_test

import (
    "errors"
    "testing"

    "example.com/agent-team/internal/invite"
)

func TestParseToken(t *testing.T) {
    t.Parallel()

    tests := []struct {
        name    string
        in      string
        want    string
        wantErr error
    }{
        {"valid token", "inv_abc123def456ghij", "abc123def456ghij", nil},
        {"empty string", "", "", invite.ErrMalformed},
        {"missing prefix", "abc123def456ghij", "", invite.ErrMalformed},
        {"too short", "inv_TOOSHORT", "", invite.ErrMalformed},
        {"mixed case", "inv_AbC123DeF456GhIj", "AbC123DeF456GhIj", nil},
    }
    for _, tc := range tests {
        tc := tc
        t.Run(tc.name, func(t *testing.T) {
            t.Parallel()
            got, err := invite.ParseToken(tc.in)
            if !errors.Is(err, tc.wantErr) {
                t.Fatalf("err: want %v, got %v", tc.wantErr, err)
            }
            if got != tc.want {
                t.Errorf("want %q, got %q", tc.want, got)
            }
        })
    }
}
```

Notice:
- `t.Parallel()` at both the outer and inner test — Cox's testing tips, lets `go test` actually overlap.
- `tc := tc` capture before the closure — without this, all parallel subtests see the same loop variable. (Pre-Go-1.22 idiom; can drop on Go 1.22+, but it costs nothing to keep.)
- `errors.Is` for error comparison, never `==`. (Per `error-handling-go` rule 2.)
- Subtest names are human-readable strings (`t.Run("valid token", ...)`); the test report becomes self-documenting.

### 2b. HTTP integration

For a server-as-struct (Mat Ryer's pattern):

```go
// internal/server/server_test.go
package server_test

import (
    "io"
    "net/http"
    "net/http/httptest"
    "strings"
    "testing"

    "example.com/agent-team/internal/server"
)

func TestServer_PostInvite(t *testing.T) {
    t.Parallel()

    srv := server.New(server.Config{
        Store:  newFakeStore(),  // hand-rolled fake, see §3
        Now:    func() time.Time { return time.Unix(1700000000, 0) },
    })
    ts := httptest.NewServer(srv.Handler())
    defer ts.Close()

    req, _ := http.NewRequest("POST", ts.URL+"/api/invite",
        strings.NewReader(`{"email":"x@y.com"}`))
    req.Header.Set("Cookie", "session=test_session")
    resp, err := http.DefaultClient.Do(req)
    if err != nil {
        t.Fatalf("request: %v", err)
    }
    defer resp.Body.Close()

    if resp.StatusCode != http.StatusCreated {
        body, _ := io.ReadAll(resp.Body)
        t.Fatalf("status: want 201, got %d (body=%s)", resp.StatusCode, body)
    }
}
```

Notice:
- `httptest.NewServer` is the standard idiom — no framework needed.
- Dependencies pass into `server.New` (Config struct). Time, store, randomness — explicit, never globals. (Ryer's *run(ctx, ...) error* + server-as-struct shape.)
- The fake store is hand-rolled (see Step 3). No `gomock`.

### 2c. Golden file

```go
// internal/format/format_test.go
package format_test

import (
    "bytes"
    "flag"
    "os"
    "path/filepath"
    "testing"

    "example.com/agent-team/internal/format"
)

var update = flag.Bool("update", false, "update golden files")

func TestFormatLogLine(t *testing.T) {
    cases := []string{"basic", "with-error", "with-request-id"}
    for _, name := range cases {
        name := name
        t.Run(name, func(t *testing.T) {
            input, err := os.ReadFile(filepath.Join("testdata", name+".in"))
            if err != nil {
                t.Fatalf("read input: %v", err)
            }
            var buf bytes.Buffer
            if err := format.LogLine(&buf, input); err != nil {
                t.Fatalf("format: %v", err)
            }

            goldenPath := filepath.Join("testdata", name+".golden")
            if *update {
                if err := os.WriteFile(goldenPath, buf.Bytes(), 0o644); err != nil {
                    t.Fatalf("write golden: %v", err)
                }
                return
            }
            want, err := os.ReadFile(goldenPath)
            if err != nil {
                t.Fatalf("read golden: %v", err)
            }
            if !bytes.Equal(buf.Bytes(), want) {
                t.Errorf("output mismatch.\n  want: %s\n  got:  %s\n  (run with -update to regenerate)",
                    want, buf.Bytes())
            }
        })
    }
}
```

Run `go test -update ./internal/format/...` once to seed `*.golden`; subsequent runs assert exact equality. Cox's tip — never paste expected output by hand; the test code itself regenerates it.

### 2d. Fuzz test

```go
// internal/header/parse_test.go
func FuzzParseHeader(f *testing.F) {
    seed := [][]byte{
        []byte(""),
        []byte("Content-Type: application/json"),
        []byte("X-Request-ID: abc\r\nContent-Length: 0"),
    }
    for _, s := range seed {
        f.Add(s)
    }
    f.Fuzz(func(t *testing.T, in []byte) {
        // Property: parsing must never panic.
        // (Behavioural correctness is checked by table-driven tests above;
        // fuzz is specifically for "doesn't blow up on bad input".)
        _, _ = header.Parse(in)
    })
}
```

Run with `go test -fuzz=FuzzParseHeader -fuzztime=30s ./internal/header/...`. The corpus auto-grows in `testdata/fuzz/`; commit the corpus alongside the test.

### 2e. Run it. Confirm RED.

```bash
go test ./...
```

If it's accidentally green, the function exists already and matches your expected output — tighten the case or pick a different surface.

---

## Step 3: Hand-rolled fakes for collaborators

When the unit-under-test depends on a collaborator (a Store, a Mailer, a Clock), define a small interface at the *consumer* and write a tiny fake — *not* a mock.

```go
// internal/invite/invite.go
package invite

type Store interface {
    InsertInvite(ctx context.Context, inv Invite) error
    LookupPending(ctx context.Context, email string) (*Invite, error)
}

type Service struct {
    store Store
    now   func() time.Time
}
```

The interface is defined in the package that *consumes* it (Pike's small-interface rule). The Store implementation in `internal/db/` doesn't need to know this interface exists.

The test-side fake:

```go
// internal/invite/fake_store_test.go
package invite_test

type fakeStore struct {
    invites map[string]invite.Invite  // keyed by email
    insertErr error                   // injected error for tests
}

func newFakeStore() *fakeStore {
    return &fakeStore{invites: map[string]invite.Invite{}}
}

func (f *fakeStore) InsertInvite(ctx context.Context, inv invite.Invite) error {
    if f.insertErr != nil {
        return f.insertErr
    }
    f.invites[inv.Email] = inv
    return nil
}

func (f *fakeStore) LookupPending(ctx context.Context, email string) (*invite.Invite, error) {
    if inv, ok := f.invites[email]; ok {
        return &inv, nil
    }
    return nil, nil  // not-found is a nil pointer, not an error, per package contract
}
```

This is roughly 20 lines and reads like the code under test. A `gomock`-generated mock for the same interface would be ~150 lines of generated code that no human will ever read. (Kennedy's data-oriented-design framing.)

This is the **Go port of James Shore's Nullables pattern** (see cross-stack TDD elders in `.rlm/research/worker-stacks-authorities-claude-v2.md` *Cross-stack patterns*). A `nullX` variant that produces no side effects but is callable in tests is preferred over mock frameworks across all the Worker's stacks.

---

## Step 4: Implement to GREEN

Write the *minimum* code change. Compose with `error-handling-go` for the error paths: if the implementation returns errors that cross package boundaries, ensure `%w` wrapping and the four error pattern choices are deliberate.

```go
// internal/invite/parse.go
package invite

import (
    "errors"
    "regexp"
)

// ErrMalformed is returned by ParseToken when the input does not match
// the canonical inv_<16-char> shape.
var ErrMalformed = errors.New("invite: malformed token")

var tokenRE = regexp.MustCompile(`^inv_([A-Za-z0-9]{16})$`)

func ParseToken(s string) (string, error) {
    m := tokenRE.FindStringSubmatch(s)
    if m == nil {
        return "", ErrMalformed
    }
    return m[1], nil
}
```

Notice:
- `ErrMalformed` is a sentinel — it's part of the public API (callers may `errors.Is` against it). Documented in package godoc. Earned its place.
- No defensive returns for cases the regex already handles.

Run the test runner. Confirm green. Then the full suite:

```bash
go test -race ./...
```

`-race` is the gate Cox emphasises. Many Go bugs are race conditions that don't surface in `go test ./...` alone.

Also run `go vet ./...`. It catches `%w` arity mismatches, unreachable returns, copy-by-value of locks — issues that often slip past tests.

---

## Step 5: REFACTOR while green

Common refactor wins in Go:

- **Inline single-use helpers.** A `helperFoo` called from one place is just inline code with a misleading name. (Pike — simplicity through subtraction.)
- **Replace `interface{}` with concrete types.** `interface{}` is a smell unless you're literally implementing something like `encoding/json`.
- **Collapse two-line `if err != nil { return err }` chains into a return chain** if no context needs adding. But the moment you cross a package boundary, wrap with `%w` (per `error-handling-go`).
- **Move structurally-coupled types into the same package.** Don't pre-emptively split.
- **Replace generated mocks with hand-rolled fakes** if you find one slipped in.
- **Replace `gomock` / `mockgen` directives in `go:generate` lines** — delete them and write hand-rolled fakes. (Kennedy.)

After every refactor, re-run `go test -race ./...`. Stay green. Stop refactoring when the code is clear; don't gold-plate.

---

## Step 6: Hand back to `tdd-loop` for the fact commit

Return:

```json
{
  "ac_id": "AC#2",
  "test_files": ["internal/invite/parse_test.go"],
  "impl_files": ["internal/invite/parse.go"],
  "testdata_files": [],
  "verify_command": "go test -race ./internal/invite/...",
  "full_suite_verify": "go vet ./... && go test -race ./...",
  "test_shape": "table-driven"
}
```

The `test_shape` field (`table-driven` / `http-integration` / `golden` / `fuzz` / `example`) helps the WhiteBox `code-review` sub-skill pick its own depth — a `fuzz` shape means the validator may also want to run the fuzzer for a longer `fuzztime`.

---

## Anti-patterns (with attribution)

- **Using a mocking framework (`gomock`, `testify/mock`, `mockery`).** Hand-rolled fakes (Nullables port) are clearer and rarely longer. (Kennedy, Cheney, Ryer convergence.)
- **`assert.Equal(t, want, got)` from `testify`.** Native `if got != want { t.Errorf(...) }` reads fine, doesn't pull in a dep, and produces better failure messages with custom formatting. (Ryer ships `matryer/is` for cases where you really want a one-line assertion — and it's *terser* than testify, so the slope toward over-mocking is shallower.)
- **One subtest per `Test*` function.** Use `t.Run("name", func(t *testing.T) {...})` for sub-cases; the test report becomes hierarchical and grep-able. (Cox.)
- **Asserting on `err.Error()` substring (e.g., `strings.Contains(err.Error(), "not found")`).** Brittle. Use `errors.Is(err, ErrNotFound)` (cross-ref `error-handling-go` rule 2).
- **Skipping `-race` because tests are slow.** Race detector overhead is ~2-10×; that's the cost of catching the bugs that ruin production. Always `-race` in CI. (Cox + the Go team.)
- **Putting business logic in `main()`.** Move it into `run(ctx context.Context, args []string, stdin io.Reader, stdout, stderr io.Writer) error`. `main` becomes a trivial wrapper. The test can then exercise `run` directly. (Ryer.)
- **Generating tests from struct tags / reflection.** Almost always a sign you should be writing the table by hand. (Pike's "a little copying is better than a little dependency.")
- **Treating `panic` in test setup as acceptable.** Use `t.Fatalf` from inside the test. `panic` in a test makes the entire test binary die instead of failing the one test.
- **Skipping `go vet ./...` before commit.** It catches `%w` arity, unreachable code, mismatched printf verbs — things that *will* fail review. Run it; cost is ~50ms.

---

## Output the parent skill consumes

```json
{
  "ac_id": "AC#2",
  "test_files": ["internal/invite/parse_test.go"],
  "impl_files": ["internal/invite/parse.go"],
  "testdata_files": [],
  "verify_command": "go test -race ./internal/invite/...",
  "full_suite_verify": "go vet ./... && go test -race ./...",
  "test_shape": "table-driven"
}
```

---

## What this skill does NOT do

- Does not write the fact commit (that's `tdd-loop`)
- Does not push the branch or open the PR (that's `tdd-loop`)
- Does not enforce error idiom in the implementation — `error-handling-go` does, in parallel
- Does not scaffold a fresh module (future `scaffold-go-http`)
- Does not run benchmarks — Go bench is a separate concern; use only if an AC specifically references performance
- Does not adopt third-party assertion libraries (testify, gocheck, ginkgo) — stdlib + `cmp.Diff` from `github.com/google/go-cmp/cmp` is enough
