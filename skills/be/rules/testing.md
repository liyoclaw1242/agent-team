# Rule: Testing (TDD)

## Core Principle

Test-Driven Development is mandatory. Every feature and bug fix follows the **Red → Green → Refactor** cycle.

## The Cycle

1. **Red** — Write a failing test that defines the expected behavior. Run it. Confirm it fails for the right reason.
2. **Green** — Write the minimum code to make the test pass. No more.
3. **Refactor** — Clean up the implementation. Tests must stay green throughout.

Repeat for each behavior unit (one endpoint, one function, one edge case).

## Rules

- **Test first, always.** Code without a preceding failing test is not allowed.
- **One behavior per cycle.** Don't write 10 tests then implement — one Red→Green→Refactor at a time.
- **Cover all paths.** Each cycle targets one of: happy path, error path, edge case, boundary condition.
- **No snapshot tests** as primary assertions.
- **Tests are documentation.** Test names describe behavior, not implementation (`"returns 404 when user not found"`, not `"test findUser"`).

## Validation

```bash
# Go
go test ./... -cover

# Node.js
pnpm test -- --coverage
```

Minimum coverage: 80% on new/modified files.
