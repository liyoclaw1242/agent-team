---
name: vitest-test-first
description: |
  TypeScript-flavoured TDD sub-skill, chained from `tdd-loop` whenever the
  detected stack is TS / Next.js / Cloudflare Workers. Implements the
  Testing Trophy (Kent C. Dodds) on Vitest: **static + integration are the
  two big tiers, unit only where pure-function complexity earns it, thin
  E2E cap.**

  Pairs the Trophy with Matt Pocock's editor-first discipline (read TS
  error messages, use `satisfies` + `as const`, derive types from runtime)
  and Colin McDonnell's parse-don't-validate (Zod schema at every
  external boundary, `z.infer<>` for the static type — never hand-write
  a parallel `interface` for the same data).

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
chained-from: tdd-loop (when stack is TS / Next.js / Cloudflare Workers)
---

# vitest-test-first

You drive one RGR cycle in TypeScript for one Acceptance Criterion. Your test runner is **Vitest**. Your testing model is the **Testing Trophy** (Kent C. Dodds): static analysis is tier 1, integration is the default for behaviour tests, unit tests only when an underlying pure function has genuine branch complexity, and E2E (Playwright) caps the critical user journey.

You do not mock your own modules. You mock the *external* boundary only — HTTP via MSW, time via `vi.useFakeTimers`, randomness via injection. (Dodds: *don't mock your own modules.*)

---

## When this sub-skill applies

The parent `tdd-loop` chained you because:

- `package.json` exists in the repo root or in a workspace package
- Stack is one of: plain TS / Node, Next.js (App Router), Cloudflare Workers

For each variant the inner shape adjusts slightly:

| Variant | Test runner config | Key difference |
|---|---|---|
| Plain TS / Node | `vitest.config.ts` | Use Node-mode by default. |
| Next.js App Router | `vitest.config.ts` with `environment: 'jsdom'` for component tests | Server Components are awkward to unit-test — prefer testing Server Actions + data-access functions directly, then a Playwright spec for the route. |
| Cloudflare Workers | `vitest.config.ts` with `@cloudflare/vitest-pool-workers` | Tests run inside real `workerd` with bindings. Use `SELF.fetch(...)` and the `cloudflare:test` module. |

If `vitest` is not yet a dep, **install it first** (`pnpm add -D vitest @vitest/coverage-v8`) plus the variant-specific extras (`@testing-library/react` + `@testing-library/jest-dom` + `jsdom` for React; `@cloudflare/vitest-pool-workers` for Workers; `msw` if any test touches HTTP boundaries). Adding the dep itself is part of the WP's setup; it goes in the first fact commit.

---

## Inputs (passed by `tdd-loop`)

- The specific AC under this iteration (text + ID)
- The WP's `impact_scope.files` — where you're allowed to write code
- The detected variant (Plain / Next.js / Cloudflare)
- Any Zod schemas already defined in the repo (`grep -r "z.object" src/`)

---

## Step 1: Translate the AC into the Trophy

Look at the AC and ask: **which tier of the Trophy answers it most cheaply?**

| AC shape | Tier | Test surface |
|---|---|---|
| "User can log in and see their dashboard" | E2E | Playwright spec; `tdd-loop` will hand to a future `playwright-test-first` skill, OR if no Playwright yet, write a Vitest integration test against the Server Action + data layer and defer the Playwright cap to a later WP. |
| "POST /api/x with malformed body returns 400" | Integration | Vitest test that calls the route handler (Next.js) or the Worker (`SELF.fetch`) with a real-ish request and asserts on response. MSW any *outbound* HTTP. |
| "Server Action `createInvite` writes a row and returns the token" | Integration | Vitest test against a real test DB (`drizzle-orm/node-postgres` against a Postgres test instance, or in-memory SQLite via Drizzle for fast feedback). Don't mock the DB layer. |
| "Function `parseInviteToken(s)` returns `null` for malformed input" | Unit | Vitest test against the pure function. Multiple `it.each([...])` rows. This is the *only* place classic isolated unit tests are appropriate — genuinely pure logic. |
| "Type `Household.id` is branded so it can't be passed where a `User.id` is expected" | Static | Add a type-only test via Vitest's `assertType<>()` or `expect-type`. `tsc --noEmit` is the actual checker. |

If the AC fits **two** tiers (e.g., "the API returns 400 AND the user sees a toast"), split mentally: the AC's verifiable surface is the API behaviour; the toast is downstream and belongs in a Playwright cap. Write the integration test for the API now; mention the missing E2E in the fact-commit `verify:` line so the BlackBox validator picks it up.

---

## Step 2: Write the failing test

### 2a. For an integration test (default)

```ts
// src/server/actions/invite.test.ts
import { describe, it, expect, beforeEach } from "vitest";
import { db, resetTestDb } from "@/server/db/test-helpers";
import { createInvite } from "./invite";
import { CreateInviteInputSchema } from "./schemas";

describe("createInvite", () => {
  beforeEach(async () => {
    await resetTestDb();
  });

  it("creates an invite row and returns a valid token", async () => {
    const input = CreateInviteInputSchema.parse({
      householdId: "hh_test",
      email: "user@example.com",
    });

    const result = await createInvite(input);

    expect(result.token).toMatch(/^inv_[a-z0-9]{16}$/);
    const rows = await db.select().from(invites);
    expect(rows).toHaveLength(1);
    expect(rows[0]?.email).toBe("user@example.com");
  });

  it("rejects when the email already has a pending invite", async () => {
    const input = CreateInviteInputSchema.parse({
      householdId: "hh_test",
      email: "dup@example.com",
    });
    await createInvite(input);

    await expect(createInvite(input)).rejects.toThrow(/already invited/);
  });
});
```

Notice:
- The test uses the real DB layer (`db.select().from(invites)`) — no mock.
- Input is parsed through the actual Zod schema — McDonnell's parse-don't-validate is part of the test surface.
- Both happy and negative paths are covered. (`api-contract-test` sub-skill calls this out as the validator-side norm — match it Worker-side too.)
- No `vi.mock("./db")`. The test is responsible for resetting state, not for pretending the DB doesn't exist.

### 2b. For a Cloudflare Worker

```ts
// src/worker.test.ts
import { describe, it, expect } from "vitest";
import { SELF } from "cloudflare:test";

describe("POST /api/invite", () => {
  it("returns 401 without auth", async () => {
    const res = await SELF.fetch("https://example.com/api/invite", {
      method: "POST",
      body: JSON.stringify({ email: "x@y.com" }),
    });
    expect(res.status).toBe(401);
  });

  it("returns 201 + invite payload with auth", async () => {
    const res = await SELF.fetch("https://example.com/api/invite", {
      method: "POST",
      headers: { Cookie: "session=test_session_token" },
      body: JSON.stringify({ email: "x@y.com" }),
    });
    expect(res.status).toBe(201);
    const body = await res.json();
    expect(body).toMatchObject({ token: expect.stringMatching(/^inv_/) });
  });
});
```

`SELF.fetch` hits the real Worker running inside `workerd`. Bindings (D1, KV, DOs) are real-but-isolated-per-test. This is *Detroit testing enabled by the runtime* (Coll, Varda).

### 2c. For a unit test on a pure function

```ts
// src/lib/parse-invite-token.test.ts
import { describe, it, expect } from "vitest";
import { parseInviteToken } from "./parse-invite-token";

describe("parseInviteToken", () => {
  it.each([
    ["inv_abc123def456ghij", "abc123def456ghij"],
    ["", null],
    ["malformed", null],
    ["inv_TOOSHORT", null],
    ["inv_lowercase_only_chars_ok123456", "lowercase_only_chars_ok123456"],
  ])("parses %j → %j", (input, expected) => {
    expect(parseInviteToken(input)).toEqual(expected);
  });
});
```

Note `it.each(...)` for tabular cases — borrowed from Go's table-driven idiom (Cox, Cheney) because it's the same insight: when the function is "pure with multiple branches," one tabular test beats ten near-duplicate `it("...")` blocks.

### 2d. Run it. Confirm RED.

```bash
pnpm vitest run <path-to-new-test-file>
```

If it's accidentally green, your test isn't actually exercising the change. Most common cause: the function exists already and your assertion happens to match its current (wrong) behaviour. Tighten the assertion or pick a different surface.

---

## Step 3: Implement to GREEN

Write the *minimum* code change. For the `createInvite` example:

```ts
// src/server/actions/invite.ts
"use server";

import { db } from "@/server/db";
import { invites } from "@/server/db/schema";
import { eq, and } from "drizzle-orm";
import { CreateInviteInputSchema, type CreateInviteInput } from "./schemas";
import { generateInviteToken } from "@/lib/parse-invite-token";

export async function createInvite(
  input: CreateInviteInput
): Promise<{ token: string }> {
  const parsed = CreateInviteInputSchema.parse(input);

  const existing = await db
    .select()
    .from(invites)
    .where(
      and(eq(invites.email, parsed.email), eq(invites.status, "pending"))
    );
  if (existing.length > 0) {
    throw new Error("already invited");
  }

  const token = generateInviteToken();
  await db.insert(invites).values({
    householdId: parsed.householdId,
    email: parsed.email,
    token,
    status: "pending",
  });
  return { token };
}
```

Notice:
- Re-parsing input even though the test already parsed it — server actions are an external boundary, and the test could lie. Parse-don't-validate at every boundary (McDonnell).
- `CreateInviteInput` is `z.infer<typeof CreateInviteInputSchema>` — schema is the single source of truth (McDonnell).
- No interface for the return type beyond what's inferred. (Pocock: don't hand-write parallel types.)

Run vitest. Confirm green:

```bash
pnpm vitest run src/server/actions/invite.test.ts
```

Then run the full suite + the type checker:

```bash
pnpm vitest run && pnpm tsc --noEmit
```

If `tsc --noEmit` complains, **read the message** before "fixing" it (Pocock). TypeScript errors are usually telling you a real thing. Adding `any` to silence them is learned helplessness.

---

## Step 4: REFACTOR while green

Common refactor wins in TS:

- Replace `interface X { ... }` with `type X = z.infer<typeof XSchema>` where a schema already exists.
- Replace `as const` literals with values that get inferred narrowly without needing annotations.
- Replace `if (!user) throw new Error(...)` with `assert.ok(user, "...")` (or a domain-specific narrowing helper) so the type system carries the non-nullness past the guard.
- Replace inline magic strings with `as const` literals exported from a `constants.ts` (only when used in 3+ places — three similar lines is fine; abstracting too early is worse).
- Replace `vi.mock(...)` with real collaborators if you find one slipped in. (Dodds. Always.)

After every refactor, re-run `pnpm vitest run`. Stay green. Stop refactoring when the code is clear; don't gold-plate.

---

## Step 5: Hand back to `tdd-loop` for the fact commit

You return to `tdd-loop` with:

- `ac_id` — which AC this iteration covered
- `test_file` — the new/changed test file path
- `impl_files` — the new/changed implementation file paths
- `verify_command` — the *exact* command Validator can re-run to see green; for this AC alone, `pnpm vitest run <path>`; for the WP overall, `pnpm vitest run && pnpm tsc --noEmit`

`tdd-loop` crafts the fact-commit message and runs `git add` + `git commit`. You don't.

---

## Anti-patterns (with attribution)

- **Hand-writing an `interface` parallel to a Zod schema.** Always `z.infer<typeof Schema>`. (McDonnell — the *whole point* of Zod 4's design is runtime + static unification.)
- **`vi.mock('./my-thing')` to test the code that uses `my-thing`.** Test through the real module; mock the external boundary (MSW, time, randomness). (Kent C. Dodds.)
- **Reaching for `any` because the error message is confusing.** Read the error. Hover the type. The signal is in the message. (Pocock.)
- **Writing a unit test for what TypeScript already guarantees.** If the type system rejects bad input, you don't also need a runtime test that "rejects bad input" — unless the boundary is external (then Zod is the test). (Hejlsberg implicit; Pocock explicit.)
- **Snapshot-testing the rendered HTML of a Server Component.** Snapshots rot. Test the behaviour through `getByRole` / `getByText` from `@testing-library/react` for client components, or the route through Playwright for the full page. (Dodds — *test how the user uses it.*)
- **Using Jest because that's what you knew.** Vitest is the modern default; Jest is legacy. (Whole TS ecosystem post-2023.)
- **Skipping `tsc --noEmit` because vitest passed.** Vitest doesn't type-check — it runs JS after a fast transpile. `tsc --noEmit` is the static tier of the Trophy and your inner-loop signal. (Rosenwasser, Pocock.)

---

## Output the parent skill consumes

```json
{
  "ac_id": "AC#2",
  "test_files": ["src/server/actions/invite.test.ts"],
  "impl_files": ["src/server/actions/invite.ts", "src/server/actions/schemas.ts"],
  "verify_command": "pnpm vitest run src/server/actions/invite.test.ts",
  "full_suite_verify": "pnpm vitest run && pnpm tsc --noEmit",
  "trophy_tier": "integration"
}
```

The `trophy_tier` field helps BlackBoxValidator pick its own probing depth: an `integration`-tier RGR means there's likely *no* Playwright cap yet for this AC, so the validator's e2e-browser-test may need to write one or note its absence.

---

## What this skill does NOT do

- Does not write the fact commit (that's `tdd-loop`)
- Does not push the branch or open the PR (that's `tdd-loop`)
- Does not iterate across multiple ACs (one AC per invocation; `tdd-loop` loops)
- Does not run Playwright (future `playwright-test-first` skill)
- Does not write `*.csproj` or `go.mod` projects (wrong stack — sibling sub-skills will exist for those)
- Does not configure CI (already handled by `.github/workflows/fact-commit-check.yml`)
