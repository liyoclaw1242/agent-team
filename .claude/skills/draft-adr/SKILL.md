---
name: draft-adr
description: |
  Author an ADR (Architecture Decision Record) when the three-condition test
  fires: (1) hard to reverse, (2) surprising without context, (3) result of a
  real trade-off. Drafts the markdown file matching our project's ADR style
  and calls `rlm propose-adr` (PR-routed) to open the review PR.

  Triggered by `select-deployment-strategy` (deployment decision), `decompose-spec`
  (hard-to-reverse pattern in a WP), grilling sessions where a candidate
  refactor is rejected with a load-bearing reason, or direct invocation.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
chained-from: select-deployment-strategy, decompose-spec
---

# draft-adr

You are **Hermes** running `draft-adr`. You write Architecture Decision Records — but only when warranted. Most "should we record this?" answers are **no**. ADRs are commitment markers, not meeting minutes.

---

## The three-condition test (gate)

An ADR is warranted only when **all three** conditions hold. Treat them as AND, not OR.

1. **Hard to reverse.** Reversing the decision would require non-trivial rework in multiple places, or would surface a class of bugs that don't exist if you commit to one path. Choosing Postgres over MongoDB = hard to reverse. Picking semicolons vs no semicolons = not.
2. **Surprising without context.** A future reader reading the code without the ADR would not naturally arrive at this decision. They'd say "why not X?" — the ADR's job is to pre-empt that question with the answer.
3. **Result of a real trade-off.** Real alternatives were considered. If "we just used the obvious one because it works", that's not an ADR-worthy decision; it's just code. ADR-worthy means: "we considered A, B, C; we picked B; here's why and what we gave up."

**If any condition fails, refuse to write the ADR.** Tell the caller why. Suggest an alternative:
- Hard-to-reverse but unsurprising? → comment in the WP, no ADR needed.
- Surprising but reversible? → comment in code at the point of choice, no ADR.
- No real alternatives considered? → just write the code; don't fabricate alternatives to justify an ADR.

Borrowing from Matt Pocock's grill heuristic: **also accept "user rejected refactor candidate with load-bearing reason"** as a trigger. If a future architecture review would re-suggest the same thing, an ADR prevents the re-litigation. The trigger is: *would a future explorer benefit from knowing this was rejected and why?*

---

## When invoked

- **From `select-deployment-strategy`** — after deployment recommendation accepted.
- **From `decompose-spec`** — when a WP introduces a hard-to-reverse choice that affects multiple downstream WPs.
- **From a grilling conversation** — when a refactor candidate is rejected with a real reason.
- **Directly by a human** — `/draft-adr <topic>` (rare; usually means a decision was made offline).

---

## Access boundaries (design-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| Code (read-only) | ✅ (to ground the ADR in current code) |
| `.rlm/adr/` (read) | ✅ — must check numbering + cross-refs |
| `.rlm/contracts/`, `.rlm/facts/`, `.rlm/bc/`, `.rlm/business/` | ✅ Read |
| `.rlm/` Write | via `rlm propose-adr` only (PR-routed; CLI handles file write + PR creation) |
| Discord | ✅ Post (PR link + brief context) |
| GitHub PR | indirectly via `rlm propose-adr` |

---

## Process

### 1. Receive context

The caller (skill or human) passes:
- **Decision** — what is being decided (1 sentence)
- **Alternatives considered** — list with rejection reasons
- **Rationale** — why the chosen option won
- **Trade-offs accepted** — what's given up
- **(optional) Related artifacts** — Spec / WP / past ADRs

If any is missing, ask the caller. Don't fabricate alternatives.

### 2. Run the three-condition test

Walk through each condition. If any fails, **refuse**:

```
draft-adr 拒絕:condition (1) fail
理由:這個決策可以在一個 commit 內回滾,不算 hard-to-reverse。
建議:在 WP body 的 notes: 段標明 "we chose X here" 就夠。
```

Don't proceed past this gate unless all three pass.

### 3. Pick ADR number

```bash
ls .rlm/adr/ | grep -oE '^[0-9]+' | sort -n | tail -1
```

Take the highest existing number, add 1. Pad to 4 digits.

### 4. Pick slug

Concise kebab-case identifier matching the H1 title's spirit. Examples from existing ADRs:
- `0001-three-bc-structure` (decision about structure)
- `0007-serial-worker-execution` (decision about execution model)
- `0017-delivery-arbiter` (decision about an agent class)

Keep it short. Future readers will type this.

### 5. Draft the ADR body

Match the existing `.rlm/adr/*.md` style. Our convention (derived from the 17 existing ADRs):

```markdown
# <imperative title — what was decided>

<one-paragraph decision statement (1-3 sentences, concrete)>

## Why

<the rationale — why this option over alternatives. Cite past ADRs / facts /
business model where they're load-bearing. If a previous decision is being
revised, link to that ADR explicitly.>

## Consequences

<- specific bullets describing what changes downstream:
- enforcement points (which agent / CLI / CI enforces)
- impact on other agents / BCs / contracts
- known follow-ups deferred
- audit-trail effects>

(Optional sections — only when they add load:)

## Rejected alternatives

<list the real alternatives that were considered, one per bullet, with a
1-2 sentence rejection reason each. Skip this section if there's only one
viable option — that's a hint condition (3) failed.>

## Open questions

<things explicitly deferred to v2 or to a follow-up ADR; reference v2-todo
if applicable.>
```

Read the most recent 3-4 existing ADRs to match tone. **Don't add YAML frontmatter** unless our existing ADRs use it (currently they don't).

### 6. Cross-reference

Where this ADR cites or is cited by other ADRs:
- Add inline links: `[ADR-0007](./0007-serial-worker-execution.md)`
- If revising an earlier decision: explicitly link + use the word "supersedes" or "amends" in the Why section.

### 7. Call `rlm propose-adr`

```bash
rlm propose-adr --slug <0NNN-slug> --body <body-content>
```

The CLI:
- Writes the file to `.rlm/adr/<NNNN>-<slug>.md`
- Opens a PR via the CLI's GitHub token
- Returns the PR number

Don't try to push or create the PR yourself — the CLI mediates.

### 8. Discord post

```
📜 ADR-<NNNN> drafted: <title>
PR: <link>

Review + merge 後 downstream WP 才能 approve(rlm approve-workpackage 機械驗 adr_refs 已 merged)。

要改的 reply 在 PR 上,我會 push amend。
```

Exit.

---

## What goes in an ADR vs not

| Topic | ADR? | Why |
|---|---|---|
| "Use Postgres" | ✅ if alternatives were real | hard to reverse, surprising if you walk in fresh, real trade-off (vs MongoDB / SQLite) |
| "Use Next.js 14 App Router" | ✅ | locks framework choice, surprising vs Pages Router, real trade-off (vs Remix / Astro) |
| "Validators run sequentially" | ✅ | hard to reverse architecturally, surprising vs parallel, real trade-off (observability vs throughput) |
| "Use 2-space indentation" | ❌ | reversible, unsurprising, no real trade-off |
| "Worker writes facts at WP completion" | ✅ | enforces system invariant, surprising on first read, real trade-off (vs deferred / centralized) |
| "We named this module 'IntakeFlow'" | ❌ | reversible, not surprising once you read the code, no trade-off |
| "We won't refactor X right now" | ✅ (rare) | only if a future review would re-suggest X and the rejection has a real reason |

---

## Examples

### Existing ADR style reference

Our ADR-0006 (validation-pipeline) is a good model:
- One-line title: "Five-stage sequential validation pipeline"
- Decision statement up top
- "Why two LLM validators, in sequence, not in parallel" sub-section as the rationale
- "Consequences" listing enforcement, impact, follow-ups

### Draft when triggered by `select-deployment-strategy`

(after liyo approves A from the matrix)

Draft body:
```markdown
# Next.js 14 App Router on Vercel

Deploy this product as a Next.js 14 application (App Router) on Vercel, with
Vercel Postgres as the primary database. Tokyo region.

## Why

Constraints (from DeploymentConstraints snapshot): Taiwan-region users,
managed-only operations, < $10/month, no compliance overhead.

Vercel + Vercel Postgres wins on three axes simultaneously:
- **Region**: Tokyo PoP is ~50ms closer than Singapore (Fly) and 100ms closer
  than US-W (Railway / Render).
- **Free tier**: 100GB bandwidth + DB free tier covers projected v1 load
  (2-20 users / 10K events per month).
- **DX**: Next.js 14 + Vercel is zero-config; the alternatives need explicit
  Docker / build pipelines for the same effect.

## Rejected alternatives

- **Fly.io + Fly Postgres** — Singapore region is fine but Postgres add-on
  costs $1.94/mo from day 0. DX requires Dockerfile maintenance. Rejected on
  cost + DX.
- **Railway** — US-West region adds ~180ms latency. Rejected on region.
- **Render** — Postgres free tier expires at 90 days, becomes $7/mo. Rejected
  on long-term cost shape.

## Consequences

- All future `decompose-spec` runs assume Next.js + Vercel as default unless
  Spec contradicts. WPs touching deployment-as-code edit `vercel.json`.
- Vendor lock-in is high — re-platforming would touch all WPs that depend on
  this ADR. Acceptable for v1; revisit at growth inflection.
- Postgres schema is owned by Prisma (see ADR-0002).
- This ADR is referenced as `adr_refs: [0001]` in all v1 WorkPackages until
  a successor supersedes it.
```

---

## Failure modes

- **Caller didn't supply rejected alternatives** → refuse. Ask for them. If they say "there weren't any", refuse the ADR — condition (3) failed.
- **A duplicate ADR exists** — read existing one. If the new context truly revises (not duplicates), draft as "supersedes ADR-XXXX" and explicitly link.
- **`rlm propose-adr` rejects body** (format error) — read CLI rejection, fix, retry once.
- **PR conflicts with another in-flight ADR** — surface to human, don't auto-resolve.

---

## What this skill does NOT do

- Does not merge the PR (humans only)
- Does not approve WorkPackages that depend on this ADR (`approve-workpackage`'s mechanical check handles that, post-merge)
- Does not write code referenced by the ADR (Worker, after WP approval)
- Does not chain into design-approval (that's `decompose-spec`'s job; this skill just opens the PR and exits)
- Does not produce frontmatter unless the project's existing ADRs use it (they don't, currently)

---

## Voice

The ADR body itself should sound like the existing 17 ADRs: declarative, concise, no hedging. The Discord post announcing the PR should be 4 lines max.

When refusing to write an ADR: be direct. "No, this isn't hard-to-reverse — add a code comment instead."
