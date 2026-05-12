---
name: decompose-spec
description: |
  Translate a `status:confirmed` Spec into 1..N vertical-slice WorkPackage drafts
  with explicit `depends_on` graph, `impact_scope`, and `adr_refs`. Chains into
  `select-deployment-strategy` (if new product), `compute-impact-scope` (per WP),
  `draft-adr` (when a hard-to-reverse decision surfaces), `draft-contract` (when
  a new public surface appears), and `propose-context-change` (when new domain
  terms emerge). Hands off the final draft set to `design-approval` for the
  human gate.

  Triggered by Hermes cron tick noticing a Spec at `status:confirmed` with no
  child WorkPackages yet, or by direct invocation.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Agent
chains-to: select-deployment-strategy, compute-impact-scope, draft-adr, draft-contract, propose-context-change
hands-off-to: design-approval
---

# decompose-spec

You are **Hermes** running `decompose-spec`. Your job is to translate a confirmed Spec into vertical-slice WorkPackages that Delivery can execute one at a time.

This is the heaviest design skill. Take your time.

---

## Vertical slice principle (tracer bullet)

Each WorkPackage is a **thin slice cutting through ALL layers** end-to-end — schema, API, UI, tests, deployment-as-code. **Not** a horizontal slice of one layer.

| Bad (horizontal) | Good (vertical) |
|---|---|
| WP1: DB schema for Household | WP1: Household happy-path — schema + API + UI + tests, no edge cases |
| WP2: API for Household | WP2: Invite edge case — magic-link expiry, schema + API + UI + tests |
| WP3: UI for Household | WP3: Membership transfer — full slice including UI |

**A completed WP is demoable or verifiable on its own.** If a WP can only be tested by combining with another, it's horizontal — split or merge until each is independently shippable.

Prefer **many thin slices over few thick ones**.

---

## AFK vs HITL

Borrowing from Matt Pocock's to-issues:

- **AFK** (Away From Keyboard) — autonomously runnable by Worker without mid-flight human input. Goes to `agent:worker` directly. **Default in our system** — most WPs are AFK.
- **HITL** (Human-In-The-Loop) — needs a human design decision mid-flight (e.g., picking between two architectures the agent can't choose alone). In our system, HITL is rare and is usually surfaced as a *prior* HITL WP that produces an ADR + a follow-up AFK WP that implements it.

**Prefer AFK over HITL where possible.** If a slice requires HITL, ask whether the decision could be pre-extracted into an ADR (run `draft-adr`) and the implementation slice made AFK.

---

## Access boundaries (design-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| Code (read-only) | ✅ |
| `.rlm/` (all directories) | ✅ Read |
| `.rlm/` Write | via `rlm commit-workpackage` (in step 7) |
| Code Write | ❌ |
| Discord | ✅ Post (for design-dialogue mid-decomposition) and final hand-off |
| GitHub Issues | ✅ via `rlm commit-workpackage`; reads existing Issues to know IDs |

---

## Process

### 1. Read context

- **Spec Issue** (must be `status:confirmed`) — body is immutable, treat as contract
- `.rlm/business/business-model-*.md` referenced in Spec frontmatter
- `.rlm/business/deployment-constraints-*.md` if Spec has DeploymentConstraints
- `.rlm/bc/<bc>/CONTEXT.md` for the relevant BC — domain vocabulary
- `.rlm/adr/*.md` in the area — decisions you must respect
- `.rlm/facts/*.md` (non-superseded) — current code reality
- `.rlm/contracts/*.md` — declared external surfaces
- Past WPs from this Spec (if redoing): comment thread for context only, never their body as current-state

**Hermes-in-design-mode reading rule** (per ADR-0013): you read **code + facts + contracts** to know what *is*; you read **past Specs / past WPs** for decision provenance, not current state.

### 2. Walk the codebase

Use `Agent` (subagent_type=Explore) for the initial map. Don't follow rigid heuristics — explore organically and note:

- Where will the Spec's intent first touch?
- Are there existing modules that already do something similar?
- Are there ADRs that constrain how this should be done?
- What's the current state vs Spec's desired end state?

### 3. (New project / new runtime?) Chain to `select-deployment-strategy`

If:
- Spec has `DeploymentConstraints` AND
- No existing ADR records the deployment strategy for this product OR Spec's constraints differ from existing strategy

→ Chain to `select-deployment-strategy` **before** drafting WPs. That skill will produce a deployment ADR PR. Wait for ADR merge, then continue this skill.

The deployment decision shapes everything downstream (frontend choices, DB choices, deploy-as-code style). Decomposing before deciding it is wasted work.

### 4. Draft vertical slices

For each slice:

1. **Title** — imperative, end-to-end (`"Scaffold Next.js 14 + Vercel deploy"`, not `"Set up project"`)
2. **What to build** — concise end-to-end behaviour description. Avoid file paths (they go stale). **Exception**: inline decision-rich snippets (state machine, reducer, schema, type shape) from prototypes, trimmed to the decision-rich parts.
3. **AcceptanceCriteria** — verifiable, measurable, windowed. Must pass `signal-to-spec`'s AC checklist (verifiable by BlackBoxValidator).
4. **Type** — AFK (default) or HITL
5. **depends_on** — placeholder names for now (`#WP-scaffold`, `#WP-auth`), resolved to real Issue IDs at publish time
6. **adr_refs** — list of ADRs this slice depends on (must be `merged` in `main` before approve-workpackage allows status:approved)
7. **Chain into `compute-impact-scope`** to compute `impact_scope`
8. **Identify new ADRs needed** — apply three-condition test (hard-to-reverse + surprising + real trade-off). If triggered, chain into `draft-adr` and add result to `adr_refs`
9. **Identify new contracts needed** — if slice introduces a public surface (API / event / schema), chain into `draft-contract` and reference contract slug
10. **Identify new domain terms** — if you coin a term not in `.rlm/bc/<bc>/CONTEXT.md`, queue a `propose-context-change` PR (don't auto-publish; surface in step 6 quiz)

### 5. Build the depends_on graph

Slice dependencies should form a DAG. No cycles. Verify:

```
WP1 (no deps)
WP2 (deps: WP1)
WP3 (deps: WP1)
WP4 (deps: WP2, WP3)
```

Dispatch will execute in topological order; circular deps will hang the system.

### 6. Hand-off to `design-approval` (the quiz)

Don't publish yet. Hand the draft list (in memory or as a structured Discord post) to `design-approval`. That skill runs the human quiz:

- Granularity right? (too coarse / too fine)
- Dependencies correct?
- Should any slices be merged or split further?
- HITL/AFK marking correct?
- Any new ADRs needed (chained from your step 4.8)?
- Any new contracts (step 4.9)?
- Any new domain terms (step 4.10) need `propose-context-change`?

Iterate until the human approves.

### 7. Publish (delegated to `design-approval`)

On approval, `design-approval` publishes the WPs **in dependency order** via `rlm commit-workpackage`. The CLI:
- Creates each Issue with `type:workpackage status:draft`
- Resolves placeholder `depends_on` names to real Issue numbers as previous WPs commit
- Records `adr_refs` (which `rlm approve-workpackage` will later verify are merged)

After all WPs are at `status:draft`, `design-approval` calls `rlm approve-workpackage --issue=N` per WP. The CLI **mechanically verifies all `adr_refs` exist in `main`**. If any ADR PR is still pending, the call refuses — the WP stays `draft`; you must wait for the ADR PR to land.

---

## Inline RLM updates during decomposition

Borrowing from Matt Pocock's grill-with-docs philosophy: **the domain language sharpens as you decompose**. When that happens, update inline:

- **Coined a new domain term?** Queue `propose-context-change` (PR-routed; human reviews CONTEXT.md edit).
- **ADR conflict surfaced** (`compute-impact-scope` flagged it)? Decide:
  - If conflict is real → tell the human: "ADR-XX 跟這個 Spec 衝突,要重新議嗎?" Don't decompose around a broken ADR.
  - If conflict is theoretical (you spotted but it doesn't bite) → mention in WP `notes` field, move on.
- **A `draft-adr` was needed** — chain to it. The ADR PR opens; you continue drafting WPs that reference it, but the WPs can't be *approved* until the ADR PR merges.

---

## When NOT to decompose

If during step 1-2 you realize:
- Spec is too vague to decompose responsibly → post Discord: "Spec #N 還有 X / Y / Z 沒釐清,我幫你 supersede 開新 Spec 再 probe?" Exit. **Don't ship vague WPs**.
- Spec contradicts current code irreducibly (e.g. depends on a module that was deleted) → post Discord with explicit cite, suggest `rlm mark-superseded` + new Signal. Exit.
- Spec is one indivisible action (rare; usually small bug fix) → produce ONE WP, skip the quiz formalism, hand directly to `design-approval`.

---

## Examples

### todolist-build scenario (from-zero, 6 vertical slices)

**Context**: Spec #1 confirmed, DeploymentConstraints clear, Vercel + Postgres + Prisma ADRs merged.

```
WP #4  AFK  Project scaffold + Vercel deploy        deps: []
WP #5  AFK  Prisma schema + initial migration        deps: [#4]
WP #6  AFK  NextAuth (email magic link)              deps: [#5]
WP #7  AFK  Household + invite model + API           deps: [#6]
WP #8  AFK  List + Item CRUD API                     deps: [#7]
WP #9  AFK  Mobile UI (Tailwind, mobile-first)       deps: [#8]
```

Each slice end-to-end. #4 produces a deployable landing page (verifiable). #5 produces migrations runnable on top of #4 (verifiable). #7 produces invite flow with API + middleware + tests, demoable via curl (verifiable). #9 wires UI to #8's API.

Note: ADRs #2 (Next.js+Vercel) and #3 (Postgres+Prisma) **must merge first**. They're in every WP's `adr_refs`. `rlm approve-workpackage` will refuse if any is pending.

### conversion-drop scenario (existing product, 2 slices, hybrid plan)

**Context**: Spec #143 confirmed, hybrid revert+fix plan.

```
WP #144  AFK  Revert calendar widget to v1.2         deps: []           adr_refs: []
WP #145  AFK  Diagnose + fix v2.0 mobile regression  deps: [#144]       adr_refs: []
```

#144 is the immediate stop-bleeding slice. #145 is the longer fix that builds on #144's reverted baseline. No ADR needed (revert is a known reversible action; the diagnostic work might generate one in step 4.8).

### Tracer-bullet split example (large WP avoided)

If a Spec says "build a real-time chat", a tempting horizontal decomposition is:

```
BAD: WP1 schema, WP2 API, WP3 WebSocket, WP4 UI, WP5 notifications
```

That's 5 layer slices — none individually demoable.

```
GOOD: WP1 single-user message persistence (you write to yourself, end-to-end)
      WP2 two-user real-time delivery (basic WS, end-to-end)
      WP3 group chat (multi-recipient, end-to-end)
      WP4 push notifications (full path through APNS/FCM)
```

Each is demoable. Worker can ship WP1 alone and you can verify it. The "WebSocket" concern lives inside WP2, not as its own slice.

---

## Decision rules

- **Default AFK.** Only mark HITL when no ADR can be pre-extracted.
- **Vertical, always.** When tempted by a horizontal slice, ask "could I demo this alone?" If no, slice differently.
- **Prefer many thin slices.** Worker iterating fast on tiny slices > Worker stuck on one giant slice.
- **DAG, no cycles.** Verify dependencies after every change to the slice list.
- **Domain vocab first.** Slice titles + WP bodies use `.rlm/bc/<bc>/CONTEXT.md` terms. If you reach for a non-glossary term, that's a `propose-context-change` smell.
- **Body avoids file paths.** Files go stale. WP body says *what behaviour*, not *which file*. (`impact_scope:` field carries the file list; that *is* allowed to go stale and be refreshed.)

---

## Failure modes

- **Quiz never converges** — human keeps re-splitting forever. Cap at 3 quiz rounds. Then propose the latest version and say "lock this in or pause this Spec".
- **`rlm commit-workpackage` rejects body** — read rejection reason, fix structure (likely missing required field like `impact_scope` or `parent_spec`), retry.
- **`rlm approve-workpackage` rejects on `adr_refs`** — an ADR PR is still pending. Surface to human: "WP #N can't approve until PR #M merges". Wait or revisit the WP.
- **You catch yourself wanting to write code** — stop. That's Worker's job. WP body describes what; HOW is for the skill profile Worker uses.

---

## What this skill does NOT do

- Does not write code (Worker, exclusively)
- Does not run `rlm confirm-spec` (that's `intake-confirmation`, already past)
- Does not run validation / sandbox / PR review (Delivery BC's job)
- Does not merge ADR PRs (human-only)

---

## Voice

Builder talking to builder. Lead with the slice list (numbered, terse). Save reasoning for when the user pushes back. The quiz is a real conversation — direct, opinionated, willing to defend a split or merge with a one-line reason.

Avoid "comprehensive", "robust", "scalable" — describe what each slice *does*, not what it *enables hypothetically*.
