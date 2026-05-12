---
name: scaffold-cloudflare-worker
description: |
  Bootstraps a brand-new Cloudflare Workers project. Invoked by Worker
  when a WorkPackage's intent is "scaffold a new edge service" and an
  ADR in the parent Spec has chosen Cloudflare as the deployment
  target.

  Produces a project that satisfies the canonical opinions of Kenton
  Varda (`workerd` architect — "bindings, not connections"; SQLite-in-
  Durable-Objects as the modern stateful primitive), Sunil Pai (PartyKit
  / Agents SDK; programming-model-first), Brendan Coll
  (`@cloudflare/vitest-pool-workers` — tests run inside the real
  `workerd`), Rita Kozlov (storage choice as architectural decision,
  not interchangeable), Matt Pocock (`strict: true` +
  `noUncheckedIndexedAccess`), and Colin McDonnell (Zod-parsed env +
  request bodies).

  Default shape:
  - Hono router (idiomatic for HTTP Workers).
  - Bindings declared in `wrangler.jsonc` — D1, KV, R2, Durable Objects
    chosen *deliberately* per Kozlov's mental model.
  - Vitest + `@cloudflare/vitest-pool-workers` — tests run inside
    real `workerd` with real bindings + isolated per-test storage.
  - Playwright wired against `wrangler dev` for E2E.
  - Zod for inbound request validation + env parsing.
  - Wrangler-generated TypeScript types for bindings (`pnpm exec
    wrangler types`).

  This skill is the *first* fact commit in any new-Workers WorkPackage.
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
agent-class: Worker (web-stack profile)
chained-from: tdd-loop (when WP scope is "scaffold new Cloudflare Worker")
---

# scaffold-cloudflare-worker

You bootstrap a Cloudflare Workers project that runs on the real `workerd` runtime locally + in production, with a test setup that exercises bindings inside the same runtime. The scaffold must be **opinionated, typed, and Detroit-test-ready** the moment it exists.

You do not implement business features. You produce a scaffold + a single fact commit recording what was scaffolded.

---

## When this skill applies

The parent `tdd-loop` chained you because:

- WP body's intent matches "scaffold / bootstrap / new edge service / new Worker" (the `compute-impact-scope` Hermes skill marked `impact_scope.kind: scaffold`).
- The parent Spec or an ADR cited by the WP names **Cloudflare Workers** as the deployment target. (If the ADR named Vercel or a Go/C# service, you wouldn't have been chained.)
- The repo root does **not** already contain a `wrangler.jsonc` or `wrangler.toml`.

If any of these is false, **stop** and comment on the WP Issue explaining the mismatch.

---

## The canonical Cloudflare web-stack defaults

| Choice | Value | Why |
|---|---|---|
| Runtime | `workerd` (Cloudflare's open-source runtime) | Varda; what runs in production. |
| Package manager | `pnpm` | Speed + monorepo behaviour. |
| Language | TypeScript with `strict: true` + `noUncheckedIndexedAccess: true` | Pocock; non-negotiable. |
| HTTP framework | Hono | Idiomatic for Workers; tiny; type-safe routing. (itty-router acceptable; pick Hono unless WP overrides.) |
| Storage primitives | Bindings only — never URL+credentials in code | Varda's "bindings, not connections." Choose per Kozlov's mental model (see below). |
| Validation | Zod at request body + env | McDonnell + project-wide norm. |
| Testing (unit/integration) | Vitest + `@cloudflare/vitest-pool-workers` | Coll — tests run in real `workerd`. |
| Testing (E2E) | Playwright against `wrangler dev` | Standard Workers e2e. |
| Type generation | `wrangler types` produces `worker-configuration.d.ts` from `wrangler.jsonc` bindings | Auto-typed bindings; never hand-write a `Env` interface. |
| Lint / format | ESLint + Prettier | Standard. |

### Storage choice (Kozlov's matrix)

Decide *before* scaffolding — this WP's parent Spec should already cite an ADR that picked one. The scaffold creates the binding stub for the chosen primitive:

| Primitive | When to pick |
|---|---|
| **Durable Object + SQLite** | Per-entity strong consistency (rooms, users, documents, sessions). The DO is a "computer" — code + state colocated. Varda's modern primitive of choice. |
| **D1** | Globally read-heavy relational data (catalog, public profiles). Strongly consistent within a region; replicated. |
| **KV** | Eventually-consistent config and session data. Don't use as a primary DB. |
| **R2** | Blobs / files / binary assets. S3-compatible. |
| **Hyperdrive** | Pooled connection to an external Postgres/MySQL when migration to D1/DO isn't possible. |

If the ADR didn't pick one, **stop** and post a comment — scaffolding without knowing the storage primitive ships dead bindings.

---

## Step 1: Run the canonical creator

```bash
pnpm create cloudflare@latest . -- \
  --type=hello-world \
  --framework=none \
  --lang=ts \
  --git=false \
  --deploy=false \
  --no-open
```

Flags chosen:

| Flag | Why |
|---|---|
| `--type=hello-world` | Minimal starting point; we'll layer Hono on top deliberately. |
| `--framework=none` | We pick Hono explicitly rather than using the Vercel-style framework prompt. |
| `--lang=ts` | TS only. |
| `--git=false` | Repo already exists; don't re-init. |
| `--deploy=false` | Deployment is Stage 3 (Dispatch); not scaffold's concern. |
| `--no-open` | Suppress browser auto-open in interactive mode. |

This yields `wrangler.jsonc`, `src/index.ts`, `tsconfig.json`, `package.json`.

---

## Step 2: Tighten `tsconfig.json`

The creator's `tsconfig.json` ships `strict: true`. Add Pocock-recommended extras:

```json
{
  "compilerOptions": {
    "strict": true,
    "noUncheckedIndexedAccess": true,
    "noImplicitOverride": true,
    "exactOptionalPropertyTypes": true,
    "moduleResolution": "Bundler",
    "types": ["@cloudflare/workers-types/2024-12-30", "@cloudflare/vitest-pool-workers"]
  }
}
```

The `types` array pins to the compatibility date you'll write in `wrangler.jsonc` — keeping the TS surface aligned with what `workerd` actually supports on that date.

---

## Step 3: Install Hono + Zod + test deps

```bash
pnpm add hono zod
pnpm add -D @cloudflare/vitest-pool-workers vitest @cloudflare/workers-types
pnpm add -D @playwright/test
pnpm exec playwright install --with-deps chromium
```

---

## Step 4: Write `wrangler.jsonc` with the chosen storage binding

Replace the creator's `wrangler.jsonc` with an explicit, commented version. Example for **Durable Object + SQLite** (the modern stateful default):

```jsonc
{
  "$schema": "node_modules/wrangler/config-schema.json",
  "name": "<project-slug>",
  "main": "src/index.ts",
  "compatibility_date": "2024-12-30",
  "compatibility_flags": ["nodejs_compat"],

  // Durable Object class for per-entity state with SQLite-in-DO.
  // Varda: SQLite-in-DOs is the modern stateful primitive.
  "durable_objects": {
    "bindings": [
      { "name": "ROOM", "class_name": "Room" }
    ]
  },
  "migrations": [
    { "tag": "v1", "new_sqlite_classes": ["Room"] }
  ],

  "observability": { "enabled": true }
}
```

For **D1** instead:

```jsonc
{
  "d1_databases": [
    {
      "binding": "DB",
      "database_name": "<project-slug>-db",
      "database_id": "PLACEHOLDER-CREATE-VIA-WRANGLER"
    }
  ]
}
```

(The user runs `pnpm exec wrangler d1 create <name>` once to get the real `database_id`; the scaffold leaves a placeholder so the WP's first deploy step prompts for it.)

For **KV**:

```jsonc
{
  "kv_namespaces": [
    { "binding": "CACHE", "id": "PLACEHOLDER-CREATE-VIA-WRANGLER" }
  ]
}
```

The scaffold only includes the binding(s) the parent ADR chose. Don't add "while we're here" bindings — dead bindings are confusion magnets.

---

## Step 5: Generate the binding types

```bash
pnpm exec wrangler types
```

This generates `worker-configuration.d.ts` declaring an `Env` interface that matches your `wrangler.jsonc`. Reference it in `src/index.ts`:

```ts
import { Hono } from "hono";

const app = new Hono<{ Bindings: Env }>();

app.get("/", (c) => c.text("ok"));

app.get("/health", (c) => c.json({ status: "ok" }));

export default app;
```

(Hono is type-aware — `c.env.ROOM` / `c.env.DB` etc. are typed automatically once the `Bindings` type is set.)

---

## Step 6: Write `src/env.ts` for env-var parsing (when applicable)

Workers' "env" is bindings (which `wrangler types` handles), but you also often have *string secrets* (API keys, signing secrets). Parse those through Zod just like the Vercel scaffold:

```ts
// src/env.ts
import { z } from "zod";

export const SecretsSchema = z.object({
  SIGNING_SECRET: z.string().min(32),
  // Add others as the project grows.
});

export type Secrets = z.infer<typeof SecretsSchema>;

export function parseSecrets(env: Record<string, unknown>): Secrets {
  return SecretsSchema.parse(env);
}
```

Then in your Hono handler, call `parseSecrets(c.env)` at the boundary — once per cold start, cached if needed.

---

## Step 7: Write `vitest.config.ts` for `vitest-pool-workers`

```ts
import { defineWorkersConfig } from "@cloudflare/vitest-pool-workers/config";

export default defineWorkersConfig({
  test: {
    poolOptions: {
      workers: {
        wrangler: { configPath: "./wrangler.jsonc" },
        isolatedStorage: true,
        miniflare: {
          compatibilityDate: "2024-12-30",
          compatibilityFlags: ["nodejs_compat"],
        },
      },
    },
  },
});
```

`isolatedStorage: true` is the key — each test gets a fresh DO/D1/KV state. Without this, tests leak into each other and become flaky.

---

## Step 8: Write the smoke tests

### 8a. Vitest smoke (in-workerd)

```ts
// src/index.test.ts
import { describe, it, expect } from "vitest";
import { SELF } from "cloudflare:test";

describe("worker", () => {
  it("returns ok on /", async () => {
    const res = await SELF.fetch("https://example.com/");
    expect(res.status).toBe(200);
    expect(await res.text()).toBe("ok");
  });

  it("returns health status on /health", async () => {
    const res = await SELF.fetch("https://example.com/health");
    expect(res.status).toBe(200);
    expect(await res.json()).toEqual({ status: "ok" });
  });
});
```

`SELF.fetch(...)` hits the real Worker running inside `workerd` — *not* a mocked fetch. (Coll + Varda — tests must run in the same runtime as production.)

### 8b. Playwright smoke (against `wrangler dev`)

```ts
// e2e/smoke.spec.ts
import { test, expect } from "@playwright/test";

test("health endpoint responds 200", async ({ page }) => {
  const response = await page.request.get("/health");
  expect(response.status()).toBe(200);
  expect(await response.json()).toEqual({ status: "ok" });
});
```

```ts
// playwright.config.ts
import { defineConfig } from "@playwright/test";

export default defineConfig({
  testDir: "./e2e",
  use: {
    baseURL: process.env.PLAYWRIGHT_BASE_URL ?? "http://localhost:8787",
  },
  webServer: process.env.PLAYWRIGHT_BASE_URL
    ? undefined
    : {
        command: "pnpm exec wrangler dev --port=8787",
        url: "http://localhost:8787",
        reuseExistingServer: !process.env.CI,
      },
});
```

`wrangler dev` runs the Worker on `workerd` locally — same runtime as production. Playwright targets that.

---

## Step 9: Wire `package.json` scripts

```json
{
  "scripts": {
    "dev": "wrangler dev",
    "deploy": "wrangler deploy",
    "test": "vitest run",
    "test:watch": "vitest",
    "test:e2e": "playwright test",
    "typecheck": "tsc --noEmit",
    "types": "wrangler types",
    "verify": "pnpm typecheck && pnpm test"
  }
}
```

`pnpm verify` is the canonical inner-loop signal — same shape as the Vercel scaffold.

---

## Step 10: Hand control back to `tdd-loop`

Verify everything works:

```bash
pnpm types          # regenerate worker-configuration.d.ts
pnpm verify         # tsc --noEmit && vitest run (against real workerd)
```

Don't run `pnpm test:e2e` at scaffold time — Playwright requires `wrangler dev` running, which is best left to feature WPs.

Return:

```json
{
  "scaffold_complete": true,
  "stack": "cloudflare-workers",
  "storage_primitive": "durable-object-sqlite",
  "key_files": [
    "wrangler.jsonc",
    "worker-configuration.d.ts",
    "tsconfig.json",
    "vitest.config.ts",
    "playwright.config.ts",
    "src/index.ts",
    "src/env.ts",
    "src/index.test.ts",
    "e2e/smoke.spec.ts"
  ],
  "verify_command": "pnpm verify",
  "next_step": "tdd-loop re-detects stack (now matches Cloudflare variant) and proceeds to AC #1 of feature work"
}
```

`tdd-loop` writes a single fact commit covering the whole scaffold:

```
[scaffold] Cloudflare Workers (workerd) + Hono + DO+SQLite + Vitest-pool-workers

fact: Scaffolded Cloudflare Worker (TS strict + noUncheckedIndexedAccess)
      with Hono routing, Durable Object + SQLite for per-entity state
      (per ADR-<id> storage decision), Zod-parsed secrets, Vitest pool
      running in real workerd with isolated per-test storage, Playwright
      against wrangler dev. Choices follow the canonical Cloudflare
      defaults in .rlm/research/worker-stacks-authorities-claude-v2.md.
verify: pnpm verify
```

---

## Anti-patterns (with attribution)

- **Embedding URLs / credentials in code instead of bindings.** Defeats the entire Workers security + DX model. (Varda — "bindings, not connections.")
- **Picking the storage primitive at scaffold time without an ADR.** Picking D1 when the right answer was DO+SQLite makes the entire app harder to migrate later. (Kozlov's matrix is *deliberate*, not interchangeable.)
- **Using `fetch('https://my-d1-rest-api/')` instead of the D1 binding.** Same DX as bindings = less mental load + free typing.
- **Mocking the Workers runtime in tests instead of using `vitest-pool-workers`.** The whole point is real runtime; mocks lie. (Coll + Varda.)
- **Skipping `wrangler types` regeneration after editing `wrangler.jsonc`.** Bindings change → types must regenerate, otherwise `c.env.X` may type-check against a stale shape. Make it part of `prebuild` or `pretest` if it gets forgotten.
- **Importing `node:fs` / `node:net` / other Node-only modules.** Workers run on `workerd`, not Node. `nodejs_compat` flag enables a subset; raw `fs` / `net` / `child_process` *do not* work. The scaffold's tsconfig + `wrangler.jsonc` deliberately reflect this; don't fight it.
- **Treating a Worker as if it had long-lived in-memory state.** Workers are ephemeral. State lives in DO / D1 / KV / R2. (Varda.)
- **Reaching for WebSockets without Durable Objects.** WebSockets need coordination state — DO is the natural home. (Pai — DO-per-entity is the pattern.)
- **Adding `app.MapGet(...)` style helpers from other frameworks.** Hono is the chosen routing API; don't reinvent it. If the WP needs MVC-shape controllers, that's an ADR-level pivot, not a scaffold detail.

---

## Done conditions

| Output | Required? |
|---|---|
| `wrangler.jsonc` with the chosen storage binding(s) | ✅ |
| `worker-configuration.d.ts` generated from `wrangler types` | ✅ |
| `vitest.config.ts` using `defineWorkersConfig` with `isolatedStorage: true` | ✅ |
| `playwright.config.ts` targeting `wrangler dev` on port 8787 | ✅ |
| `src/env.ts` Zod-parses string secrets (if any) | ✅ when applicable |
| Smoke tests exist + `pnpm verify` returns 0 | ✅ |
| Returned structured output to `tdd-loop` | ✅ |

If `pnpm verify` is non-zero, **fix before returning success**.

---

## Access boundaries (per ADR-0009)

Same as `tdd-loop` (Worker, web-stack profile). One additional capability:

| Resource | Access |
|---|---|
| `pnpm exec wrangler types` (regenerate binding types) | ✅ — pure local file generation |
| `pnpm exec wrangler dev` (local Workers runtime) | ✅ |
| `pnpm exec wrangler deploy` | ❌ — deploy is Dispatch's Stage 3 responsibility |
| `pnpm exec wrangler d1 create / kv:namespace create / r2:bucket create` | ❌ — creating real Cloudflare resources requires auth + creates billable infra; that's a setup step in the WP body for a human to run once, not a scaffold action |

---

## What this skill does NOT do

- Does not create real Cloudflare resources (D1 databases, KV namespaces, R2 buckets) — placeholder IDs in `wrangler.jsonc`, real IDs supplied by humans once per project
- Does not deploy. `wrangler deploy` is Stage 3 (Dispatch)
- Does not write features. Smoke tests only; feature ACs come from `tdd-loop` cycling
- Does not pick auth strategy. Workers auth varies wildly (session in DO, JWT, signed cookies) — a per-feature decision
- Does not modify `.github/workflows/*`
- Does not configure Workers AI / Queues / Cron Triggers — those bind on-demand per feature
- Does not commit
