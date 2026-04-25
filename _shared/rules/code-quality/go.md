# Code Quality — Go

Extends `base.md` with Go-specific rules. Used by BE.

## Errors

- Errors are values. Always check `if err != nil`.
- Wrap with context using `fmt.Errorf("doing X: %w", err)` to preserve the chain.
- Sentinel errors (`var ErrNotFound = errors.New(...)`) for cases callers need to branch on; use `errors.Is` to compare.
- Don't return `nil` error and zero value together for "not found" — return a sentinel.

## Concurrency

- Don't start a goroutine without a way to stop it. Pass `context.Context` or use a done channel.
- Each goroutine that can fail needs an error-reporting path.
- Use `sync/errgroup` for fan-out with error aggregation.
- Mutex names match the field they protect: `mu` next to `state`; `userMu` next to `users`.

## Interface design

- Interfaces are defined where they are consumed, not where they are implemented.
- Small interfaces (`io.Reader` not `Filesystem`).
- Accept interfaces, return concrete types.

## Naming

In addition to base rules:
- Receiver names: 1–2 letters, consistent within a file (`s *Server` not `srv *Server` then `s *Server`).
- Test functions: `TestThing_WhenCondition_ReturnsExpected`.
- Package names: short, lowercase, no underscores. `userrepo` not `user_repo`.

## Validation

```bash
go vet ./...
staticcheck ./...
go test -race -cover ./...
gofumpt -l -d .
```
