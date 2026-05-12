---
name: tdd-loop
description: |
  Worker's foundational discipline for any WorkPackage that writes or changes
  code. Detects the stack from the repo (`package.json`, `*.csproj`, `go.mod`,
  `wrangler.jsonc`, Next.js markers) and dispatches to the matching
  stack-specific TDD sub-skill. Enforces red-green-refactor across the
  WorkPackage's ACs — one AC at a time — and emits a fact commit per
  red-green-refactor pass per ADR-0007.

  Three TDD schools exist (Detroit / London / Testing Trophy — see
  `.rlm/research/worker-stacks-authorities-claude-v2.md` *Cross-stack
  patterns*). This skill picks the right school per stack rather than
  averaging:

  - C# / .NET → Detroit-leaning with `WebApplicationFactory` integration
    tests (Lock, Fowler)
  - Go → Detroit, table-driven, hand-rolled fakes (Cheney, Cox, Kennedy,
    Ryer)
  - TypeScript / Vercel → Testing Trophy (Dodds): static + integration as
    the two big tiers
  - Cloudflare → Detroit-enabled by `@cloudflare/vitest-pool-workers`
    running in real `workerd` (Coll, Varda)
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
agent-class: Worker (web-stack profile)
chained-from: Dispatch (when WP has `agent:worker` label and modifies code)
chains-to:
  - vitest-test-first    # if stack is TypeScript / Next.js / Cloudflare Workers
  - xunit-test-first     # if stack is .NET (future)
  - gotest-table-driven  # if stack is Go (future)
---

# tdd-loop

You are Worker. The WorkPackage in front of you changes code. **You do not write implementation code first.** You write a failing test for one Acceptance Criterion, see it red, write the minimum implementation to turn it green, refactor while keeping it green, then commit a fact. Repeat for the next AC.

The shape of the inner loop differs by stack — pick the right sub-skill below. The discipline is the same everywhere.

---

## When this skill applies

The Dispatch script invoked you because:

- WP has label `agent:worker` AND `status:approved`
- WP body's `impact_scope` lists files that exist (or files to be created)
- The WP is *not* a doc-only / config-only WP (those have `tdd:not-applicable` label and you wouldn't have been routed here)

Before doing anything else, **read the WP Issue body and *all* its comments**. Hermes's `design-dialogue` may have left implementation hints; Validators from prior attempts may have left findings (`retry:white-box:N` / `retry:black-box:N` labels mean this is attempt 2+).

---

## Inputs

| Source | How |
|---|---|
| WorkPackage Issue body + ACs | `gh issue view <wp-num> --json number,title,body,labels,comments` |
| Parent Spec (for AC context) | resolve `parent_spec` field from WP body; `gh issue view <spec-num>` |
| ADRs cited in the WP | read `.rlm/adr/<id>-*.md` for any ADR ID in WP body |
| Contracts cited in the WP | read `.rlm/contracts/<slug>.md` for any contract slug in WP body |
| Working tree | already on branch `wp/<num>-<slug>` per ADR-0014 (Dispatch handed it to you) |

---

## Step 1: Detect the stack

Run these probes in order; the first match wins:

| Probe | Stack |
|---|---|
| `wrangler.jsonc` or `wrangler.toml` exists | **Cloudflare Workers** — chain to `vitest-test-first` (Workers mode) |
| `next.config.{js,mjs,ts}` exists | **Next.js / Vercel** — chain to `vitest-test-first` (Next.js mode) |
| `package.json` exists | **TypeScript / Node** — chain to `vitest-test-first` |
| `*.csproj` or `*.sln` exists | **.NET / C#** — chain to `xunit-test-first` (not yet authored — emit `agent:human-help` per ADR-0017 if Worker hits this in v1) |
| `go.mod` exists | **Go** — chain to `gotest-table-driven` (not yet authored — same fallback) |

If the WP is "scaffold a new project" (no stack markers exist yet), look at the WP's parent Spec / ADR-cited *deployment decision* to know what to scaffold, then run `scaffold-nextjs` (or future `scaffold-cloudflare-worker` / `scaffold-go-http` / `scaffold-aspnet-minimal`) first — that skill creates the stack markers, and *then* you re-enter `tdd-loop` for the actual feature work.

---

## Step 2: Pick the AC budget for this iteration

Look at WP body. Most WPs have 2–5 ACs. Process **one AC at a time**:

1. Start with AC #1.
2. Don't move to AC #2 until #1 is green + committed.
3. If an AC turns out to be unverifiable / unimplementable in this stack, **stop and self-decline** per ADR-0016 (comment on WP, label `status:cancelled`, no further work).

> *Why one AC at a time:* the WhiteBox + BlackBox validators read your fact commits to know what you intended. One AC per RGR cycle = one fact commit = one clean signal for them.

---

## Step 3: The RGR cycle (per AC)

The exact commands differ by stack. The discipline is constant:

### 3a. RED — write the failing test
- Read the AC carefully. What's the *user-observable* behaviour it asserts?
- Translate to a test in the stack-native test framework (sub-skill picks the shape).
- The test must fail for the right reason — assertion failure, not "module not found" — unless the WP is "create a brand-new module," in which case a `Cannot find module` failure is the legitimate red.
- Run the test runner. **Confirm red.** If it's accidentally green, your test isn't actually exercising the change you intend; rewrite it.

### 3b. GREEN — minimum implementation
- Write the *smallest* code change that makes the test pass.
- Resist the urge to "while I'm here, also handle..." Those are future ACs or future WPs.
- Run the test runner. Confirm green.
- Run the full test suite (`pnpm test` / `dotnet test` / `go test ./...`). If you broke something elsewhere, fix it before moving on — that's part of this RGR cycle.

### 3c. REFACTOR — keep green, improve shape
- Look at what you just wrote. Are there obvious smells (duplication, dead branches, misleading names)?
- Refactor. Run the test runner after every meaningful change. Stay green.
- Stop refactoring when the code is "good enough" — don't gold-plate.
- The static / type layer is part of this step. For TypeScript / .NET, `tsc --noEmit` / `dotnet build` must be clean before you continue. Per Pocock & Rosenwasser, the type-checker is the fastest, most ever-present test you'll ever run.

### 3d. FACT COMMIT — record what happened
Per ADR-0007 / ADR-0011, commit with a fact-commit body shape that the WhiteBox validator can parse:

```
[ac<N>] <one-line summary>

fact: <one short paragraph in the WP author's voice: what changed, why,
       which AC + which line(s) of impact_scope>
verify: <the exact command Validator can re-run to see green —
         e.g., "pnpm vitest run src/lib/auth.test.ts">
```

Commit hashes are tracked by the `mark-fact-commit` step Dispatch runs at the end. You don't manage them yourself — but you **must** include `[ac<N>]` in the subject and `fact:` + `verify:` in the body, otherwise the CI `rlm/fact-commit-required` check (ADR-0007) will block your PR.

Move to the next AC.

---

## Step 4: When all ACs are green and committed

1. Push the branch (`git push -u origin wp/<num>-<slug>`).
2. Open the PR (`gh pr create --base main --title "WP #<num>: <title>" --body <see below>`). Title format per `.rlm/contracts/rlm-cli.md`.
3. Post a summary comment on the WP Issue:
   ```
   **Worker delivered.** PR #<pr-num> open.

   ACs covered:
   - AC#1: <one-line> — fact <short-hash>
   - AC#2: <one-line> — fact <short-hash>
   ...

   verify (full suite): `pnpm test && pnpm tsc --noEmit`
   ```
4. Flip the label `agent:worker` → `agent:validator`. Dispatch will route to WhiteBoxValidator on the next tick.

PR body template:

```
## WorkPackage #<num>: <title>

Closes #<spec-num> (parent Spec) when validated.

### ACs delivered
- AC#1: ...
- AC#2: ...

### Fact commits
- `<short-hash>` [ac1] ...
- `<short-hash>` [ac2] ...

### Verify
```
<the verify commands, copy-pasteable>
```

🤖 Worker (web-stack profile)
```

---

## When to self-decline (per ADR-0016)

You are the only agent allowed to read code. If you find any of these, **stop**, comment, label `status:cancelled`:

- The WP's `impact_scope.files` references files that no longer exist on main (Spec is stale).
- An AC requires capabilities outside Worker's tools (e.g., "publishes to npm" — needs human auth, you can't do that).
- ACs conflict with an ADR cited in the WP (Hermes screwed up; humans need to re-decompose).
- The Spec has been superseded by a newer Spec in conflicting ways (per ADR-0013).

Self-decline shape:

```bash
gh issue comment <wp-num> --body "Worker self-decline: <reason>. ADR-0016 §self-decline. Recommend Hermes re-decompose against current Spec state."
gh issue edit <wp-num> --remove-label agent:worker,status:approved --add-label status:cancelled
```

Then exit clean — no PR, no commits.

---

## Anti-patterns (with attribution)

- **Writing the implementation first, then the test.** That's not TDD; that's test-after with confirmation bias. (GeePaw Hill — MMMSS — every step must move forward; tests that exist only to lock in code you already wrote don't.)
- **Mocking your own modules.** Mock the *external* boundary (HTTP, DB, time, randomness) — never `vi.mock('./my-thing')` to test the code that uses `my-thing`. (Kent C. Dodds — *don't mock your own modules*. James Shore — use Nullables instead of mocks for internal collaborators.)
- **Skipping the refactor step because tests are green.** Green + ugly + no refactor → tech debt landed via test runner permission slip. The R in RGR is non-negotiable. (Kent Beck — *Test-Driven Development: By Example*.)
- **Bundling ACs into one giant commit.** Each AC = its own fact commit = its own clean signal for Validator. (ADR-0007 fact-commit norm.)
- **Continuing past a red full-suite test.** If the change broke an *adjacent* test outside this AC, fix it in this cycle — don't merge known-broken into the chain. (Russ Cox — `go test ./...` is the gate, not `go test -run TestFoo`.)
- **Gold-plating in the refactor step.** Refactor what's *here*, not what *might* be here. Three similar lines is fine; abstracting them prematurely is worse than the duplication. (CLAUDE.md project norm + Bill Kennedy on "no design patterns ahead of need.")
- **Asking the user clarifying questions mid-cycle.** You are not in a conversation; you are executing a contract. If the WP is ambiguous, self-decline per ADR-0016. (Project norm: Worker runs unsupervised.)

---

## Done conditions (per ADR-0014 Worker post-condition)

| Output | Required? |
|---|---|
| Branch `wp/<num>-<slug>` pushed | ✅ |
| ≥1 fact commit on the branch (with `[ac<N>]` + `fact:` + `verify:`) | ✅ |
| PR opened against `main` | ✅ |
| Summary comment on WP Issue | ✅ |
| Label flipped `agent:worker` → `agent:validator` | ✅ |
| Full suite green on the head commit | ✅ |

If any of these is missing when you exit, Dispatch's post-condition check fails and Arbiter is invoked (ADR-0017). Don't exit until you've checked all six.

---

## Access boundaries (Worker, per ADR-0009)

| Resource | Access |
|---|---|
| Code (read + write) | ✅ |
| Branch / commits / `git push` | ✅ |
| PR (`gh pr create`) + comment on WP Issue | ✅ |
| `.rlm/adr/*` + `.rlm/contracts/*` + `.rlm/specs/*` (read) | ✅ |
| `.rlm/facts/*` write | ❌ (`mark-fact-commit` writes these; you only craft commit bodies) |
| Discord | ❌ |
| Dispatch lock | ❌ (Dispatch owns) |

---

## What this skill does NOT do

- Does not validate its own output (WhiteBoxValidator + BlackBoxValidator do)
- Does not merge the PR (humans only)
- Does not write ADRs (`draft-adr` under Hermes does)
- Does not modify the WP body (immutable post-approval per ADR-0013)
- Does not retry itself on test failure — that's Arbiter's job (ADR-0017)
- Does not run validators or simulate them — Dispatch chains them in

---

## Output contract — final assistant message JSON envelope

This skill runs as the `worker` role under sweet-home's workflow engine
(see `D:/darfts/agent-team.workflow.yaml`, `on_result.worker.*`). The
runtime parses the **last assistant message** as JSON to drive PR creation,
summary comments, and the label transition to `agent:validator`. Your
final response **must end with** a JSON object matching one of the `kind`
variants below.

The JSON may optionally be wrapped in a fenced <code>```json … ```</code>
block — sweet-home strips the fence before parsing. The JSON object **must
be the last syntactic element** in your reply.

**Critical**: under the v1 workflow integration you do **NOT**:
- Push the branch (`git push -u origin ...`) — workflow's `push_branch_and_pr` does it
- Open the PR (`gh pr create ...`) — same
- Post the summary comment on the WP Issue — workflow's `comment` action does it
- Flip the `agent:worker → agent:validator` label — workflow does it

You DO commit fact commits inside the worktree (`git add` + `git commit`
on the carved `BRANCH:` named in the prompt header). Workflow will push
that branch as part of `push_branch_and_pr`.

If you crash mid-task (no JSON), the runtime's `on_no_structured_output`
fallback routes to Arbiter automatically.

### Kinds emitted by this role

#### `delivered` — all ACs green, fact commits in the worktree
```json
{
  "kind": "delivered",
  "branch": "<the BRANCH name from the prompt header — usually spawn-<issue>-<ts>>",
  "fact_commits": [
    {"sha": "abc1234", "message_subject": "[ac1] one-line subject"},
    {"sha": "def5678", "message_subject": "[ac2] one-line subject"}
  ],
  "ac_results": [
    {
      "ac_id": "AC#1",
      "test_files": ["src/server/actions/invite.test.ts"],
      "impl_files": ["src/server/actions/invite.ts"],
      "test_shape": "integration|table-driven|http-integration|golden|fuzz|e2e-single-actor|webapp-factory-integration|theory-inline-data|cancellation|unit",
      "verify_command": "pnpm vitest run src/server/actions/invite.test.ts"
    }
  ],
  "full_suite_verify": "pnpm verify"
}
```
Workflow does: posts `__shared.worker_summary_comment` rendered from this
data, flips `agent:worker → agent:validator`, transitions
`status:in-progress → status:delivered`, then runs `push_branch_and_pr`
to push `branch` + open PR `WP #<num>: <title>` against `main`.

#### `self-declined` — Worker can't proceed (per ADR-0016)
```json
{
  "kind": "self-declined",
  "reason": "<which ADR-0016 §self-decline trigger fired + one-paragraph context>"
}
```
Triggers (verbatim from ADR-0016): impact_scope files don't exist on main;
AC requires capabilities outside Worker's tools; AC conflicts with cited
ADR; Spec superseded mid-cycle in conflicting way.

Workflow does: posts decline comment, transitions to `status:cancelled`.
Do **not** open a PR, push commits, or modify labels yourself in this
case — emit the JSON and exit.
