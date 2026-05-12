---
name: scaffold-nextjs
description: |
  Bootstraps a brand-new Next.js (App Router) project for the Vercel
  deployment stack. Invoked by Worker when a WorkPackage's intent is
  "scaffold a new web app" and an ADR in the parent Spec has chosen
  Vercel + Next.js + Postgres + Drizzle (the canonical web-stack default
  per `.rlm/research/worker-stacks-authorities-claude-v2.md` *Track:
  Vercel*).

  Produces a working project that satisfies the canonical opinions of
  Tim Neutkens (Server Components are the default), Lee Robinson (Zod at
  every Server Action boundary, prefer direct calls over Route Handlers,
  shadcn/ui + Tailwind, Drizzle for edge-friendly typed SQL), Matt Pocock
  (`strict: true`, `noUncheckedIndexedAccess: true`), and Kent C. Dodds
  (Testing Trophy ready — Vitest + Testing Library + MSW + Playwright
  wired from day one).

  This skill is the *first* fact commit in any new-web-app WorkPackage.
  After scaffolding completes, Worker hands control back to `tdd-loop`
  for the actual feature work.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
agent-class: Worker (web-stack profile)
chained-from: tdd-loop (when WP scope is "scaffold new Next.js project")
---

# scaffold-nextjs

You bootstrap a Next.js (App Router) project that a future Worker iteration can immediately start writing tests against. The project must be **opinionated, typed, and Trophy-ready** the moment it exists.

You do not implement business features here. You produce a scaffold and a single fact commit that records what was scaffolded and why each choice was made.

---

## When this skill applies

The parent `tdd-loop` chained you because:

- WP body's intent matches "scaffold / bootstrap / new project" (the `compute-impact-scope` Hermes skill marked `impact_scope.kind: scaffold`).
- The parent Spec or an ADR cited by the WP names **Vercel + Next.js** as the deployment target. (If the ADR named Cloudflare or Go, you wouldn't have been chained — `scaffold-cloudflare-worker` / `scaffold-go-http` would have run instead.)
- The repo root does **not** already contain a `next.config.{js,mjs,ts}` (otherwise you're not scaffolding — you're modifying an existing project, and `tdd-loop` should have routed differently).

If any of these is false, **stop** and post a comment on the WP Issue explaining the mismatch; do not modify the repo. (This is Worker's self-decline path per ADR-0016.)

---

## The canonical Vercel web-stack defaults

| Choice | Value | Why |
|---|---|---|
| Framework | Next.js 15+ (App Router) | Tim Neutkens, current major. |
| Package manager | `pnpm` | Vercel-recommended; faster install, better monorepo behaviour. |
| Language | TypeScript with `strict: true` + `noUncheckedIndexedAccess: true` | Pocock; non-negotiable per `vitest-test-first` skill. |
| Routing | App Router (`app/`) | Tim Neutkens; Pages Router is legacy. |
| Server vs Client | Server Components default; `"use client"` only at leaves with state/effects | Tim Neutkens. |
| Data fetching | Direct DB calls in Server Components / Server Actions; no Route Handlers unless externally consumed | Lee Robinson. |
| Validation | Zod at every Server Action input + Route Handler body + `process.env` parse | Lee Robinson, Colin McDonnell. |
| ORM | Drizzle ORM (edge-friendly, typed SQL builder) — Prisma only if WP explicitly requests it | Lee Robinson SaaS Starter. |
| DB | Vercel Postgres (Neon-backed) | Vercel-blessed; works with Drizzle. |
| Styling | Tailwind CSS v4 + shadcn/ui | Vercel-blessed combo; Lee Robinson SaaS Starter. |
| Auth | NextAuth (Auth.js) with magic-link email, OR custom cookie session for v1 | per WP — defer to the WP body. |
| Testing | Vitest + `@testing-library/react` + `jsdom` + `msw` + Playwright | Trophy-ready; Dodds, Pocock. |
| Lint / format | ESLint (Next preset) + Prettier | Vercel default. |
| Git hooks | None at scaffold time — CI is the gate (`.github/workflows/`). | Avoid CI/hook drift. |

If the WP body explicitly overrides any of these (e.g., "use Prisma instead of Drizzle"), respect it — but **call out the override in the fact commit's `fact:` line** so the Validator knows it was intentional.

---

## Step 1: Run the canonical creator

The Next.js team ships an interactive creator that respects most of the defaults above. Run it non-interactively with explicit flags:

```bash
pnpm create next-app@latest . \
  --typescript \
  --tailwind \
  --eslint \
  --app \
  --src-dir \
  --import-alias "@/*" \
  --use-pnpm \
  --turbopack \
  --no-git
```

The `--no-git` flag matters because **the repo already exists** (the WP branch is already checked out). The creator must not re-init git or it will conflict with the existing branch.

Flags chosen:

| Flag | Why |
|---|---|
| `--typescript` | Pocock + the TS team consensus. |
| `--tailwind` | Vercel-blessed default. |
| `--eslint` | Catches the most common Next.js mistakes. |
| `--app` | App Router, not Pages Router. (Neutkens.) |
| `--src-dir` | `src/app/` keeps the repo root cleaner — preferred by Lee Robinson's templates. |
| `--import-alias "@/*"` | Standard alias used in shadcn/ui and most Vercel templates. |
| `--use-pnpm` | Faster, less duplication, monorepo-friendly. |
| `--turbopack` | Default for `next dev` in Next.js 15+. |

---

## Step 2: Tighten `tsconfig.json`

`pnpm create next-app` ships `strict: true` already (good). Add the Pocock-recommended extras:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true
  }
}
```

`noUncheckedIndexedAccess` is the single highest-value flag the creator doesn't enable by default — it turns every `arr[i]` access into `T | undefined`, forcing you to handle the missing case. Pocock and the TS team both treat this as table stakes for production code.

---

## Step 3: Add the test stack

```bash
pnpm add -D vitest @vitejs/plugin-react @vitest/coverage-v8 jsdom \
  @testing-library/react @testing-library/jest-dom @testing-library/user-event \
  msw
pnpm add -D @playwright/test
pnpm exec playwright install --with-deps chromium
```

Create `vitest.config.ts`:

```ts
import { defineConfig } from "vitest/config";
import react from "@vitejs/plugin-react";
import path from "node:path";

export default defineConfig({
  plugins: [react()],
  test: {
    environment: "jsdom",
    setupFiles: ["./src/test/setup.ts"],
    globals: false,
  },
  resolve: {
    alias: { "@": path.resolve(__dirname, "./src") },
  },
});
```

Create `src/test/setup.ts`:

```ts
import "@testing-library/jest-dom/vitest";
import { afterEach } from "vitest";
import { cleanup } from "@testing-library/react";

afterEach(() => {
  cleanup();
});
```

Create `playwright.config.ts`:

```ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? "http://localhost:3000",
    trace: "on-first-retry",
  },
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : { command: "pnpm dev", url: "http://localhost:3000", reuseExistingServer: !process.env.CI },
});
```

Add test scripts to `package.json`:

```json
{
  "scripts": {
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test",
    "typecheck": "tsc --noEmit",
    "verify": "pnpm typecheck && pnpm test"
  }
}
```

`pnpm verify` is the **canonical inner-loop command** Validator will re-run. It must always be the fastest "is this green?" answer.

---

## Step 4: Add Drizzle + Vercel Postgres

```bash
pnpm add drizzle-orm @vercel/postgres zod
pnpm add -D drizzle-kit
```

Create `src/server/db/schema.ts` with a placeholder table (so the import resolves and the type-checker is happy at the end of scaffold):

```ts
import { pgTable, text, timestamp } from "drizzle-orm/pg-core";

export const _scaffoldPlaceholder = pgTable("_scaffold_placeholder", {
  id: text("id").primaryKey(),
  createdAt: timestamp("created_at").defaultNow().notNull(),
});
```

The first feature WP will replace this with the real domain schema; for now it exists so `drizzle-kit generate` produces *something* and the type-checker doesn't complain about an empty file.

Create `src/server/db/index.ts`:

```ts
import { drizzle } from "drizzle-orm/vercel-postgres";
import { sql } from "@vercel/postgres";
import * as schema from "./schema";

export const db = drizzle(sql, { schema });
```

Create `drizzle.config.ts`:

```ts
import { defineConfig } from "drizzle-kit";

export default defineConfig({
  schema: "./src/server/db/schema.ts",
  out: "./drizzle/migrations",
  dialect: "postgresql",
  dbCredentials: { url: process.env.POSTGRES_URL ?? "" },
});
```

Create `src/env.ts` — parse-don't-validate for env (McDonnell, applied to `process.env`):

```ts
import { z } from "zod";

const EnvSchema = z.object({
  POSTGRES_URL: z.string().url(),
  NEXT_PUBLIC_APP_URL: z.string().url().default("http://localhost:3000"),
});

export const env = EnvSchema.parse(process.env);
export type Env = z.infer<typeof EnvSchema>;
```

Never read `process.env.X` directly anywhere else in the app — import from `@/env`. (Pocock + McDonnell convergence.)

---

## Step 5: Add shadcn/ui

```bash
pnpm dlx shadcn@latest init --yes --defaults --src-dir
```

This creates `components.json` + `src/components/ui/` + `src/lib/utils.ts`. Don't add individual components yet — feature WPs will `shadcn@latest add <component>` when they need them.

---

## Step 6: Write the smoke test

The scaffold's *first fact commit* must include a passing test, otherwise CI's `rlm/fact-commit-required` check is satisfied but the WP delivers a project with zero verification. Add:

```ts
// e2e/smoke.spec.ts
import { test, expect } from "@playwright/test";

test("homepage renders the Next.js default content", async ({ page }) => {
  await page.goto("/");
  await expect(page).toHaveTitle(/Next/i);
});
```

And:

```ts
// src/env.test.ts
import { describe, it, expect } from "vitest";
import { z } from "zod";

describe("env schema shape", () => {
  it("requires POSTGRES_URL as a URL", () => {
    const schema = z.object({ POSTGRES_URL: z.string().url() });
    expect(() => schema.parse({ POSTGRES_URL: "not a url" })).toThrow();
  });
});
```

The Vitest smoke test verifies the env-schema *pattern* without requiring a live DB connection. The Playwright smoke verifies the homepage actually renders.

Run them:

```bash
pnpm verify         # tsc --noEmit && vitest run — must be green
pnpm test:e2e       # playwright test — must be green (skip in CI for scaffold; flag for next WP)
```

---

## Step 7: Hand control back to `tdd-loop`

Return:

```json
{
  "scaffold_complete": true,
  "stack": "next.js-app-router-vercel",
  "key_files": [
    "next.config.ts",
    "tsconfig.json",
    "vitest.config.ts",
    "playwright.config.ts",
    "drizzle.config.ts",
    "src/env.ts",
    "src/server/db/index.ts",
    "src/server/db/schema.ts",
    "src/test/setup.ts",
    "e2e/smoke.spec.ts",
    "src/env.test.ts"
  ],
  "verify_command": "pnpm verify",
  "next_step": "tdd-loop re-detects stack (now matches Next.js variant) and proceeds to AC #1 of feature work"
}
```

`tdd-loop` writes a single fact commit covering the whole scaffold:

```
[scaffold] Next.js App Router on Vercel + Drizzle + Vitest + Playwright

fact: Scaffolded Next.js 15 (App Router, TS strict + noUncheckedIndexedAccess)
      with Tailwind, shadcn/ui, Drizzle ORM (Vercel Postgres), Zod-parsed
      env, Vitest + Testing Library + MSW, Playwright. Choices follow ADR-<id>
      (Vercel target) and the canonical web-stack defaults documented in
      .rlm/research/worker-stacks-authorities-claude-v2.md. impact_scope covers
      repo-wide bootstrap (all new files).
verify: pnpm verify && pnpm test:e2e
```

Then `tdd-loop` proceeds to the *next* AC, which is the first real feature.

---

## Anti-patterns (with attribution)

- **Initialising git inside the creator** (`--no-git` omitted) — clobbers the WP branch. Always `--no-git`.
- **Picking Prisma when the WP didn't ask for it.** Drizzle is the Vercel-blessed edge-friendly default. (Lee Robinson SaaS Starter.) Prisma at the edge has historically had cold-start and binary-size issues; pick Prisma only when the WP explicitly says so.
- **Adding more shadcn/ui components than the smoke test needs.** Components arrive *with the feature WP that uses them*, not at scaffold time. Three unused components in `src/components/ui/` is dead code from day one.
- **Skipping `noUncheckedIndexedAccess`.** It catches an entire class of `undefined`-dereference bugs and you want it on from day one, not retrofitted later when the codebase resists. (Pocock.)
- **Reading `process.env.X` directly anywhere except `src/env.ts`.** Even the test setup. The schema is the contract; bypassing it = silently shipping a missing-env bug to prod. (McDonnell.)
- **Skipping the Vitest + Playwright smoke tests.** A scaffold without a green test isn't deliverable — the CI gate (`rlm/fact-commit-required`) requires a fact commit, and a fact commit without a `verify:` that actually returns 0 is non-compliant per ADR-0007.
- **Asking the user to pick `--use-pnpm` vs `--use-npm`.** pnpm is the chosen default; if the user wants npm/yarn, they say so in the WP body. Don't pause mid-scaffold for clarifying questions. (Worker runs unsupervised.)

---

## Done conditions

| Output | Required? |
|---|---|
| `next.config.ts` + `tsconfig.json` (strict + noUncheckedIndexedAccess) exists | ✅ |
| `vitest.config.ts` + `playwright.config.ts` exist and run | ✅ |
| `drizzle.config.ts` + `src/server/db/*` exist | ✅ |
| `src/env.ts` parses `process.env` through Zod | ✅ |
| `e2e/smoke.spec.ts` + `src/env.test.ts` exist | ✅ |
| `pnpm verify` returns 0 | ✅ |
| Returned structured output to `tdd-loop` for fact-commit crafting | ✅ |

If `pnpm verify` is non-zero at the end, **do not return success** — debug and fix before handing back. A red scaffold is worse than a missing scaffold.

---

## Access boundaries (per ADR-0009)

Same as `tdd-loop` (Worker, web-stack profile):

| Resource | Access |
|---|---|
| Code (read + write across the whole repo) | ✅ |
| `pnpm` / `pnpm dlx` / `npx` / `git` commands | ✅ |
| `.rlm/adr/*` + `.rlm/contracts/*` (read) | ✅ |
| Discord | ❌ |
| `.rlm/facts/*` write | ❌ |
| External secret stores (Vercel API tokens, npm publish creds) | ❌ |

---

## What this skill does NOT do

- Does not connect to a real Vercel Postgres or Neon DB. `POSTGRES_URL` resolves to `""` in scaffold; the first feature WP wires real credentials via Vercel envs.
- Does not deploy. `vercel link` / `vercel deploy` is a Stage 3 (Dispatch deploy step) responsibility, not Worker's.
- Does not write features. The smoke tests are *just* smoke; real ACs are handled by `tdd-loop` cycling through them.
- Does not pick auth strategy. NextAuth vs custom cookie session is a feature decision, made in the relevant feature WP.
- Does not commit. Commit crafting + `git commit` belong to `tdd-loop`.
- Does not modify `.github/workflows/*`. CI workflow lives at the repo root and is set up once per project (separate WP).
