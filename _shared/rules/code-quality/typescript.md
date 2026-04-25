# Code Quality — TypeScript

Extends `base.md` with TypeScript-specific rules. Used by FE and OPS (when writing IaC in TS).

## Type safety

- `any` is forbidden in committed code. Use `unknown` and narrow.
- `as` casts require justification: either a comment explaining why the type system can't see the truth, or a runtime check immediately before the cast.
- Avoid `// @ts-ignore` and `// @ts-expect-error` without an issue link.
- Strict mode flags must be on: `strict: true`, `noUncheckedIndexedAccess: true`, `exactOptionalPropertyTypes: true`.

## Module structure

- One default export per file maximum. Prefer named exports.
- No barrel re-exports (`export * from './foo'`) for application code; reserved for library boundaries.
- Circular imports forbidden — they almost always indicate a missing abstraction.

## Async

- `async` functions either return `Promise<T>` or `Promise<void>`. Never `Promise<any>`.
- Don't `await` in tight loops without batching unless ordering is required.
- `Promise.all` over sequential `await` when calls are independent.
- Unhandled promise rejections fail the test suite (set `unhandled-rejections=strict`).

## React-specific (FE only)

- Functional components only.
- No `useEffect` for derived state — compute during render.
- Hooks at the top level; no conditional hook calls.
- Each component file: component + its types + its tests in adjacent files (`Foo.tsx`, `Foo.test.tsx`).

## Validation

```bash
tsc --noEmit                       # type check
eslint --max-warnings=0 src        # lint, treat warnings as failures
prettier --check src               # formatting
```
