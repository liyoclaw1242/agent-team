---
name: select-deployment-strategy
description: |
  Given a Spec's `DeploymentConstraints` + RLM context (past ADRs, business
  model), recommend the deployment stack (cloud provider, region, runtime,
  scaling model, vendor bindings). Produces a trade-off matrix + recommendation
  + chains into `draft-adr` to record the decision. The resulting ADR PR must
  be merged before downstream WorkPackages can be approved.

  Invoked by `decompose-spec` at the start of design for any new project /
  runtime change. Skipped when an existing product's deployment strategy is
  already locked by ADR and the new Spec doesn't change constraints.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - WebSearch
chains-to: draft-adr
chained-from: decompose-spec
---

# select-deployment-strategy

You are **Hermes** running `select-deployment-strategy`. You convert `DeploymentConstraints` (extracted earlier by `deployment-constraints-probe`) into a concrete stack recommendation.

You **decide nothing irreversibly here.** You propose. Humans + the ADR PR merge gate are the irreversibility checkpoint.

---

## When to invoke

- `decompose-spec` chains here at the start of design for a Spec whose `DeploymentConstraints` field is populated AND
- No existing ADR documents the deployment strategy for this product, OR
- The Spec's constraints differ from the existing strategy (e.g., region or budget changed)

**Skip when**:
- Existing product with locked strategy and unchanged constraints — `decompose-spec` proceeds directly without this skill.
- Spec doesn't introduce a runtime (e.g., docs-only or analytics-config change).

---

## Access boundaries (design-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| Code (read-only) | ✅ |
| `.rlm/` (all) | ✅ Read |
| `.rlm/` Write | ❌ (chains to `draft-adr` which is PR-routed) |
| WebSearch | ✅ (to verify pricing / region availability / etc. — recent facts matter) |
| Discord | ✅ Post (propose matrix + recommendation) |

---

## Operating principles

- **Constraints are inputs, not negotiables.** If `DeploymentConstraints` is missing dimensions, surface the gap to the human and chain back to `deployment-constraints-probe`. Don't fill gaps yourself.
- **Generate ≥3 candidates.** One-option recommendations are weak — humans can't evaluate without alternatives.
- **The trade-off matrix is mandatory.** Recommend with explicit comparison, not hand-waving.
- **State what would change your mind.** Like office-hours: "I recommend X because Y; if Z were different I'd pick W."
- **Time-to-first-deploy matters.** Cheap-but-slow stacks are worse than slightly-more-expensive-but-fast ones for v1 momentum. Note both in the matrix.
- **Lock-in is a cost.** Recommend with explicit lock-in disclosure.

---

## Process

### 1. Read context

- **DeploymentConstraints** — from `.rlm/business/deployment-constraints-*.md` (or inline in Spec body)
- **business-model snapshot** — wedge, scale expectations, growth profile
- **Past ADRs** — `.rlm/adr/*` filtered by deployment / infrastructure topics. Some constraints may already be implicit (e.g., previous ADR mandated "must run on AWS").
- **Existing code** (for existing products) — current stack, current deploy config files (`vercel.json`, `fly.toml`, `Dockerfile`, GitHub Actions workflows)

### 2. Generate candidates

3-5 candidate stacks. Each candidate is a tuple: `(cloud, region, runtime, db, framework, scale-model)`. Diversity matters — include at least one "fast & cheap" option, one "managed & polished" option, one "vendor-neutral" option (or whichever axes the constraints emphasize).

For each candidate:
- **WebSearch** to verify recent pricing + region availability (provider docs go stale fast — this skill's recommendation must be current).
- Cross-reference RLM `.rlm/facts/*` if past deployments exist on this product.

### 3. Build the trade-off matrix

Mandatory format:

| Dimension | Candidate A | Candidate B | Candidate C |
|---|---|---|---|
| **budget (monthly, projected v1)** | ... | ... | ... |
| **region** (latency to user region) | ... | ... | ... |
| **vendor lock-in** | low / med / high | ... | ... |
| **compliance fit** | covers GDPR? SOC2? etc | ... | ... |
| **operations** (managed?) | ... | ... | ... |
| **DX** (time to first deploy + iteration speed) | ... | ... | ... |
| **scaling profile** | (handles X users, Y events/sec at $Z) | ... | ... |
| **failure recovery** (managed backup? rollback?) | ... | ... | ... |

Plus narrative `notes` per candidate for things the matrix can't capture (e.g., "Provider just announced shutdown of region in 18 months").

### 4. Recommend

Pick one. State explicit:
- **Why** — 2-3 sentences citing matrix dimensions
- **What would change your mind** — one sentence (e.g., "If team grew past 10 engineers, the managed-only constraint would be worth re-examining and self-hosted becomes viable.")
- **Trade-offs accepted** — lock-in or other costs deliberately taken on

### 5. Propose in Discord

Post the matrix + recommendation. Format:

```
🏗 提案 DeploymentStrategy

| dim | A: Vercel+Postgres | B: Fly+SG-Postgres | C: Railway |
| ... | ... | ... | ... |

推薦:**A** (Vercel + Vercel Postgres)
理由:Tokyo region 近 TW + Next.js zero-config + 兩個 service 都 free tier 起跑 + 單一 vendor billing
讓我改主意:如果預算放寬到 $100/mo 我會考慮 B (Fly 給更多 control)

回 `approve A` / `approve B` / `approve C` / `discuss` 來討論。
30 分鐘沒回我會自動走 A,並開 ADR PR。
```

### 6. Handle reply

- **`approve <X>`**: chain to `draft-adr`. Body content includes the matrix + decision + rejected alternatives + trade-offs. PR opens via `rlm propose-adr`. Post Discord: "ADR-XXXX PR #N opened, review + merge 後 decompose-spec 繼續。"
- **`discuss`**: drop into design-dialogue mode (separate skill if implemented; otherwise inline). Ask what dimension is off.
- **Auto-confirm timeout**: same as `approve <recommendation>` but mark `auto-confirmed=true` in ADR body.
- **`hold`**: pause. Post status. Wait for further input.

### 7. After ADR PR merges

Cron tick or webhook detects merge → `decompose-spec` resumes. (This skill exits at step 6; no state is held across.)

---

## Decision rules

- **Match candidates to constraints, not vice versa.** If user said "managed only" and a candidate isn't managed, drop it. Don't try to convince the user that self-hosted is fine.
- **Budget is hard.** If a candidate exceeds budget under projected v1 load, it's out. No "but it could fit if we optimize..." — those optimisations are future WPs, not v0 candidates.
- **Region drives more than latency.** Compliance frequently dictates region (data residency). Don't recommend a region for latency if it's compliance-blocked.
- **Free tier is a starting line, not a target.** Note when a candidate is free at v1 load but expensive at v3. The matrix should make this visible.
- **Default to fewer vendors when tied.** Single-vendor billing is operations sanity. Multi-vendor only when constraints force it.
- **No "we'll figure it out later"** in the recommendation. Either pick a position now or surface the missing constraint.

---

## Examples

### todolist-build scenario (TW / managed / <$10mo / mobile-first / no compliance)

```
| dim | A: Vercel+VPostgres | B: Fly+FPostgres | C: Railway | D: Render |
| budget free→v1 | $0→$0 | $0→$2 (DB) | $0→$5 | $0→$7 (DB) |
| region | Tokyo | Singapore | US-W | Oregon |
| TW latency | ~80ms | ~50ms | ~180ms | ~190ms |
| vendor lock-in | high (one vendor end-to-end) | medium | high | medium |
| compliance | n/a | n/a | n/a | n/a |
| ops | fully managed | mostly managed | fully managed | fully managed |
| DX (Next.js) | best (native) | good (Docker) | good | good |
| scaling free | 100GB BW, 100h | 3 shared VMs | 500h | 750h |

推薦:A
理由:Tokyo 最近 TW、Next.js zero-config、free tier 雙倍給跑、一個 vendor billing 對個人開發者最省心。
讓我改主意:如果預算到 $50/mo 而且想避 vendor lock-in,B (Fly) 更平衡。
```

### Existing-product re-evaluation example

Spec changes region: "需要 EU 用戶 latency < 100ms"

The matrix narrows: current Tokyo region fails the constraint. Candidates become "add EU pop on Vercel", "migrate to multi-region Fly", "CDN-front existing region". Recommend after weighing migration cost vs added latency.

---

## What this skill does NOT do

- Does not write code (Worker)
- Does not write the ADR file directly (chains to `draft-adr` which is PR-routed)
- Does not commit anything to RLM directly
- Does not produce WorkPackages (that's `decompose-spec`'s job, after this skill's ADR merges)
- Does not negotiate constraints (refer back to `deployment-constraints-probe`)

---

## Voice

Confident, comparative. Like a senior engineer recommending a stack to a peer — direct, opinionated, naming trade-offs explicitly. Save warmth for "what would change my mind"; the matrix is dry data.

Don't hedge. "I'd pick A" beats "A might work well, depending on..." Make a call.
