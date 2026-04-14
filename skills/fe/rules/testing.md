# Rule: Frontend Testing

## Two Testing Modes

ARCH determines which mode applies via the issue spec's `testing` field:

| Spec Value | When | What FE Does |
|------------|------|-------------|
| `self-test-only` | Business pages, features, one-off UI | Browser self-test only (default if omitted) |
| `unit-required` | Shared hooks, component libraries, utils | Unit tests + browser self-test |

**If the spec doesn't specify `testing`, default to `self-test-only`.**

---

## Mode 1: Browser Self-Test (all tasks)

Every task requires a self-test record before delivery. This is an interactive test using Browser MCP, based on the issue's Acceptance Criteria (AC).

### Process

1. `pnpm build && pnpm start` (production quality)
2. Open Browser MCP, navigate to the affected route
3. Walk through each AC item — operate, observe, screenshot
4. Check browser DevTools: console errors, network failures
5. Write results to `/tmp/self-test-issue-{N}.md`

### Self-Test File Format

```markdown
# Self-Test: {Issue Title}

## Environment
- Branch: agent/{id}/issue-{N}
- Build: pnpm build (pass/fail)
- URL: http://localhost:3000{route}

## Steps (from AC)

### 1. {AC item description}
- Action: {what you did}
- [ ] {expected result}
- Console: {clean / errors}
- Screenshot: `01-{name}.png`

### 2. ...

## Result
- {pass/fail summary}
```

### What to Check Every Time

- [ ] `pnpm build` succeeds without error
- [ ] Page loads without console errors
- [ ] All AC items verified with screenshots
- [ ] No network errors (4xx/5xx) during operations
- [ ] Responsive: check at mobile (320px) if applicable

---

## Mode 2: Unit Tests (hook libraries / component libraries only)

Only when spec says `testing: unit-required`.

### Framework

Vitest + @testing-library/react (follow project's existing setup).

### Rules

1. Test file co-located: `useCart.ts` → `useCart.test.ts`
2. Query priority: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`
3. Test **behavior**, not implementation
4. No snapshot tests as primary assertions
5. Each state (default, loading, error, empty) gets its own test
6. For hooks: test return values and state transitions, not internals

### What Needs Unit Tests

| Target | Example | Test What |
|--------|---------|-----------|
| Shared hooks | `useAuth()`, `useCart()` | State transitions, return values, edge cases |
| UI primitives | `<Button>`, `<Modal>`, `<Input>` | Props, states, keyboard interaction, a11y |
| Pure utils | `formatPrice()`, `parseDate()` | Input/output, edge cases |

### What Does NOT Need Unit Tests

| Target | Why Not |
|--------|---------|
| Business page components | Iterates too fast, self-test covers behavior |
| One-off feature components | Maintenance cost > value |
| Layout/wrapper components | Nothing to assert beyond rendering |
