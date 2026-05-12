---
name: playwright-test-first
description: |
  E2E sub-skill for Worker. Writes Playwright specs that cap the
  critical user journey for any web-stack WP whose AC requires
  user-visible flow assertions. Sits at the "thin E2E cap" tier of
  Kent C. Dodds' Testing Trophy and the "preview-driven development"
  norm of Vercel (Rauch, Robinson) — applies regardless of whether
  the underlying stack is Next.js, plain Node, or Cloudflare Workers.

  Distinct from the Validator's `e2e-browser-test` sub-skill:
    - `playwright-test-first` runs *during* Worker's RGR cycle to
      drive implementation against a real browser journey, and is
      committed to the repo as part of the WP's test suite.
    - `e2e-browser-test` runs *after* Worker is done, executes the
      committed Playwright suite against a sandbox deploy, and
      classifies failures as implementation-defect vs ac-ambiguity.

  In other words: Worker writes the spec here, Validator runs it
  there. The spec is the *artifact*, not the act of testing.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
agent-class: Worker (web-stack profile, sub-skill)
chained-from: tdd-loop (when AC requires user-visible flow assertion)
---

# playwright-test-first

You write a Playwright spec that captures one Acceptance Criterion as a real browser scenario, runs it red, then drives the implementation through `vitest-test-first` (TS) or sibling sub-skills until the spec passes. The spec is committed to the repo as the lasting artifact — it becomes the Validator's BlackBox surface in the next stage.

You are responsible for the **outer loop** (the user-observable flow). Inner-loop unit/integration tests live under `vitest-test-first` / `xunit-test-first` / `gotest-table-driven`. You don't replace them — you cap them.

---

## When this sub-skill applies

The parent `tdd-loop` chained you because:

- The current AC's text contains user-flow language ("user can…", "after submitting…", "the page shows…", "mobile users see…"), AND
- The repo has Playwright wired (or this is the first WP that needs E2E and the scaffold step already ran).

If the AC is API-only ("returns 401", "responds with X JSON shape"), **don't chain here** — return immediately. Use the stack-specific test-first skill instead; API-shape ACs are integration-tier, not E2E-tier (Dodds — don't promote tests up the Trophy without reason).

---

## Inputs (passed by `tdd-loop`)

- The specific AC under this iteration (text + ID)
- The WP's `impact_scope.files` — both the UI files and any server-side files the journey touches
- Whether Playwright is already wired (check `playwright.config.ts` + `e2e/` dir)
- The target dev URL (`http://localhost:3000` for Next.js default)

---

## Step 1: Translate the AC into a single user journey

A good Playwright spec has:

- **One protagonist** (one logged-in user, or one anonymous visitor). Multi-actor scenarios are possible but expensive; reserve them for ACs that explicitly require two perspectives.
- **A single critical path** — the user navigates, performs an action, observes the result. No branching.
- **One assertion that *is* the AC.** Other intermediate checks exist for evidence (screenshots between steps), but the spec's verdict comes from one assertion.

If the AC has multiple verbs/expectations, the *most user-facing* one is the assertion; the rest become inner-loop integration tests under `vitest-test-first`.

### Identifying the assertion surface

| AC fragment | Assertion target |
|---|---|
| "user sees their household name" | `await expect(page.getByRole('heading', { name: householdName })).toBeVisible()` |
| "the invite link works" | `await page.goto(inviteUrl); await expect(page).toHaveURL(/\/household\/.+/)` |
| "mobile UI shows the menu icon" | Run with `devices['iPhone 14']` context; `await expect(page.getByRole('button', { name: /menu/i })).toBeVisible()` |
| "the form rejects invalid emails" | `await page.getByRole('textbox', { name: /email/i }).fill('not-an-email'); await page.getByRole('button', { name: /submit/i }).click(); await expect(page.getByText(/invalid email/i)).toBeVisible()` |
| "after checkout, the order appears in the order history" | Multi-step but single-actor; verify on `/orders` page after checkout returns. |

Use **Testing Library-style queries** (`getByRole`, `getByLabel`, `getByText`) over CSS selectors. They survive markup refactors and they match how the *user* finds the element. (Dodds — `getByRole` / `getByLabelText` are deliberately user-centric.)

CSS-selector queries (`page.locator('.btn-primary')`) are brittle and tie tests to implementation details. Avoid them unless the element has no accessible role.

---

## Step 2: Write the failing spec

### 2a. Single-actor anonymous flow

```ts
// e2e/signup.spec.ts
import { test, expect } from "@playwright/test";

test("user can sign up with email and land on the dashboard", async ({ page }) => {
  await page.goto("/signup");

  await page.getByRole("textbox", { name: /email/i }).fill("new-user@example.com");
  await page.getByRole("button", { name: /sign up/i }).click();

  // KEY ASSERTION — this is the AC
  await expect(page).toHaveURL(/\/dashboard/);
  await expect(page.getByRole("heading", { name: /welcome/i })).toBeVisible();
});
```

### 2b. Authenticated flow with storage state

For ACs that start "as a logged-in user…", capture auth state once and reuse:

```ts
// e2e/auth.setup.ts
import { test as setup } from "@playwright/test";

setup("authenticate", async ({ page }) => {
  await page.goto("/signin");
  await page.getByRole("textbox", { name: /email/i }).fill("seed-user@example.com");
  await page.getByRole("textbox", { name: /password/i }).fill("test-password");
  await page.getByRole("button", { name: /sign in/i }).click();
  await page.waitForURL(/\/dashboard/);
  await page.context().storageState({ path: "e2e/.auth/user.json" });
});
```

Wire it into `playwright.config.ts`:

```ts
projects: [
  { name: "setup", testMatch: /auth\.setup\.ts/ },
  {
    name: "chromium",
    use: { ...devices["Desktop Chrome"], storageState: "e2e/.auth/user.json" },
    dependencies: ["setup"],
  },
];
```

Then the test reads:

```ts
test("authenticated user can create a household", async ({ page }) => {
  await page.goto("/household/new");
  await page.getByRole("textbox", { name: /name/i }).fill("My household");
  await page.getByRole("button", { name: /create/i }).click();

  await expect(page).toHaveURL(/\/household\/[a-z0-9_-]+/);
  await expect(page.getByRole("heading", { name: "My household" })).toBeVisible();
});
```

### 2c. Multi-actor scenario (rare; expensive)

```ts
test("two users in one household see each other's lists", async ({ browser }) => {
  // Actor 1: user1 creates a list
  const c1 = await browser.newContext({ storageState: "e2e/.auth/user1.json" });
  const p1 = await c1.newPage();
  await p1.goto("/list/new");
  await p1.getByRole("textbox", { name: /name/i }).fill("Groceries");
  await p1.getByRole("button", { name: /create/i }).click();

  // Actor 2: user2 visits /list and sees user1's list
  const c2 = await browser.newContext({ storageState: "e2e/.auth/user2.json" });
  const p2 = await c2.newPage();
  await p2.goto("/list");

  // KEY ASSERTION
  await expect(p2.getByRole("link", { name: "Groceries" })).toBeVisible();

  await c1.close();
  await c2.close();
});
```

Multi-actor specs cost ~2-3× single-actor specs in runtime. Use only when an AC genuinely requires two perspectives — collaboration features, real-time updates, permission boundaries. Don't decompose API-shape ACs into multi-actor flows.

### 2d. Mobile / device-specific

```ts
import { test, expect, devices } from "@playwright/test";

test.use({ ...devices["iPhone 14"] });

test("mobile menu opens and shows nav links", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: /menu/i }).click();
  await expect(page.getByRole("link", { name: /sign in/i })).toBeVisible();
});
```

If the AC says "iOS Safari" or "mobile" specifically, `devices['iPhone 14']` (or the relevant device) is non-negotiable — desktop Chromium with a narrow viewport is *not* the same as iOS Safari, and ACs that mention the latter typically care about touch events, viewport meta, safe-area insets.

### 2e. Run it. Confirm RED.

```bash
pnpm playwright test e2e/<your-new-spec>.spec.ts
```

Expected failure modes for a "right" red:
- "Element not found" — the page route or the UI element doesn't exist yet.
- "Navigation timeout" — the redirect after action doesn't happen.
- "Expected URL to match … received …" — the redirect goes somewhere wrong.

If the spec is accidentally green, it's not exercising the change. Tighten the assertion (`{ exact: true }` for text matches; specific URL patterns; specific role+name pairs).

---

## Step 3: Drive implementation via the inner-loop sub-skill

You don't implement the feature here. You hand control back to `tdd-loop`, which:

1. Calls `vitest-test-first` (TS/Next.js/Cloudflare) or `xunit-test-first` (.NET) or `gotest-table-driven` (Go) to do integration-tier tests for the Server Actions / endpoints / functions the journey calls into.
2. Implements those layers green.
3. Returns to *this* skill to verify the Playwright spec now passes against the dev server.

The outer loop drives the inner loop. The user journey is the goal; integration tests are the steps to get there.

---

## Step 4: Run the spec green against the local dev server

```bash
# In one terminal:
pnpm dev

# In another:
pnpm playwright test e2e/<your-spec>.spec.ts
```

Or in CI / headless one-shot mode (the dev server is auto-started per `playwright.config.ts`):

```bash
pnpm test:e2e -- e2e/<your-spec>.spec.ts
```

If the spec is green locally but the inner-loop full suite has regressions:

```bash
pnpm verify && pnpm test:e2e
```

Fix the regressions before committing — green E2E with red unit tests = you broke something adjacent.

---

## Step 5: Capture useful failure context

Playwright captures rich failure context for free — but you should configure traces and screenshots intentionally:

```ts
// playwright.config.ts (already in the scaffold-nextjs default, double-check)
export default defineConfig({
  use: {
    trace: "on-first-retry",
    screenshot: "only-on-failure",
    video: "retain-on-failure",
  },
});
```

This means: in CI, when a test fails, the next retry captures a trace; the validator's `e2e-browser-test` sub-skill can read this trace to classify implementation-defect vs ac-ambiguity. Don't disable these — they're the audit trail.

---

## Step 6: Hand back to `tdd-loop` for the fact commit

Return:

```json
{
  "ac_id": "AC#3",
  "test_files": ["e2e/signup.spec.ts"],
  "impl_files": [],
  "verify_command": "pnpm playwright test e2e/signup.spec.ts",
  "full_suite_verify": "pnpm verify && pnpm test:e2e",
  "test_shape": "e2e-single-actor",
  "trophy_tier": "e2e"
}
```

The `impl_files` is empty *for this skill alone* — the actual implementation files come from the inner-loop sub-skill that ran in between. `tdd-loop` aggregates both lists for the fact commit.

---

## Anti-patterns (with attribution)

- **`page.locator('.css-selector')` over `getByRole` / `getByLabel`.** CSS selectors couple tests to markup; they fail spuriously on every minor refactor. Use role/label queries — they reflect what the user sees. (Dodds — Testing Library's whole point.)
- **`page.waitForTimeout(2000)` to "let the page settle".** Brittle, slow, hides real race conditions. Use `page.waitForURL(/...regex.../)`, `await expect(...).toBeVisible()`, `page.waitForResponse(/api/...)` — Playwright auto-waits on these. (Playwright docs + Vercel preview-driven culture.)
- **Asserting on intermediate text that's unrelated to the AC.** "The page contains 'Welcome' AND 'Signup successful' AND the button is enabled" — pick the one that's the AC's verdict; the rest are noise. (Dodds — *test how the user uses it*, not "everything you can think of.")
- **Snapshot-testing entire DOM trees.** Snapshots rot the moment a className changes. Specific role/text/URL assertions don't. (Dodds.)
- **Multi-actor scenarios where one-actor would do.** They cost more, fail more, and the assertion is usually the *same observable state* a single user could check. Decompose unless the AC genuinely requires both perspectives. (Project norm: smallest sufficient evidence.)
- **Running Playwright against a production URL during Worker's RGR cycle.** Playwright targets `localhost:3000` (or `wrangler dev`) during development. Validator's `e2e-browser-test` targets the sandbox deploy URL — that's *its* boundary, not yours.
- **Reusing the same Playwright spec for both Worker's RGR cycle and Validator's verification.** The spec *file* is reused (committed to the repo); but Worker runs it against local dev, Validator runs it against the sandbox. Same artifact, different environment. Don't write two specs.
- **Skipping `getByLabelText` for form inputs and using placeholder text.** Placeholders disappear on focus and aren't proper labels. Use `getByLabel`. (Accessibility + test stability convergence.)
- **Adding `data-testid` attributes everywhere.** Role/label queries handle ~90% of cases. `data-testid` is the *last* resort — and even then, it tightly couples test to markup. Prefer making the markup more accessible. (Dodds — "if you need `data-testid`, your markup is probably under-labeled.")

---

## Done conditions

| Output | Required? |
|---|---|
| One Playwright spec file committed under `e2e/` | ✅ |
| Spec is green when run against `pnpm dev` | ✅ |
| `pnpm verify && pnpm test:e2e` returns 0 | ✅ |
| Returned structured output to `tdd-loop` | ✅ |
| (Optional) Auth setup project wired if AC needs authenticated state | ✅ when applicable |

---

## Access boundaries (per ADR-0009)

Same as `tdd-loop` (Worker, web-stack profile). Playwright can start a real browser, navigate to local URLs, take screenshots. No production environment access, no auth credentials beyond test fixtures.

| Resource | Access |
|---|---|
| Local dev server (`pnpm dev`, `wrangler dev`) | ✅ |
| Browser automation via Playwright | ✅ |
| Screenshots / traces / videos under the repo | ✅ |
| Production / preview deploy URLs | ❌ (Validator's territory) |
| Real auth credentials | ❌ (test fixtures only — seed users with `seed-user@example.com` shape) |

---

## What this skill does NOT do

- Does not implement the underlying feature — inner-loop sub-skills do
- Does not validate the implementation classification (implementation-defect vs ac-ambiguity) — that's BlackBoxValidator's `e2e-browser-test`
- Does not run against production / preview deploys — Validator does
- Does not write API contract tests — `api-contract-test` (under BlackBox) for that, or `vitest-test-first` for API-shape Server Actions
- Does not configure visual regression / Chromatic — separate concern, defer until requested
- Does not handle WebSocket / streaming protocols beyond what Playwright supports out-of-the-box
- Does not write the fact commit (that's `tdd-loop`)
