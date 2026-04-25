# Code Quality (Base)

Language-agnostic quality bar. Every role's code-quality rule extends this.

## Dead code

Forbidden:
- Commented-out code blocks. If you might want it later, that's what git history is for.
- Unused imports, unused local variables, unused parameters.
- Functions / classes / types declared but not referenced anywhere.

The validator runs the language's standard dead-code detector (`tsc --noUnusedLocals`, `staticcheck`, `pyflakes`, etc.).

## Naming

- Names describe purpose, not implementation. `userIds` not `arr1`.
- No abbreviations except universally understood ones (`URL`, `ID`, `i` in tight loops).
- Boolean variables/functions: `is*`, `has*`, `should*`, `can*`. Not `flag` or `status` (use the actual semantic name).
- Avoid double negatives. `isEnabled` not `isNotDisabled`.

## Function shape

- Function does one thing. If you'd describe it with "and", split it.
- Soft cap: 50 lines. Past that, justify in PR description.
- Parameters: ≤4 positional. Past that, take an options object / struct.
- Return early; avoid deeply nested conditionals.

## Comments

Comments explain **why**, not **what**.

- Bad: `// increment i`
- Good: `// stripe webhook delivers events out of order; sequence by created_at`
- Best: code structured so the comment isn't needed.

Forbidden:
- `// TODO: ...` without a tracking issue. Use `// TODO(#123): ...` or remove.
- `// HACK` / `// FIXME` left in merged code without an open issue link.

## Error handling

- Never silently swallow errors. Log, propagate, or handle explicitly.
- Error messages include context: what was being attempted, what failed, what the user/caller can do.
- Don't catch broad exception types just to satisfy a linter (`catch (e) { throw e }` is forbidden).

## Imports / dependencies

- New runtime dependencies require justification in PR description.
- Prefer standard library + existing project dependencies over adding new ones.
- Dev/test dependencies are looser but still need to be reviewed.

## Validation

The shared `validate/code-quality.sh` script runs the role's chosen toolchain. Each role's SKILL.md picks up the appropriate language sub-rule (`code-quality/typescript.md`, etc.).
