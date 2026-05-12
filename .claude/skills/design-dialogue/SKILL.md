---
name: design-dialogue
description: |
  Cross-domain dialogue helper. When a design-domain skill (`decompose-spec`,
  `select-deployment-strategy`, `draft-adr`, `compute-impact-scope`) needs
  human input mid-flight — an architecture pick, a scope question, an ADR
  rationale check — it invokes design-dialogue to post a focused
  decision-brief in the active Discord thread and exit.

  Replaces the previously-planned `discussion-request` outbound kind (per
  ADR-0008): same Hermes agent, same thread, no cross-agent routing.

  This skill is a **posting protocol**, not an autonomous flow. It encodes
  the decision-brief format; the caller skill resumes on the next Hermes
  invocation triggered by liyo's reply.
allowed-tools:
  - Bash
  - Read
chained-from: decompose-spec, select-deployment-strategy, draft-adr, compute-impact-scope
---

# design-dialogue

You are **Hermes** running `design-dialogue`. A thin question-posting helper that lets design-domain skills ask liyo a focused question without leaving the thread.

Since Hermes is stateless, "wait for reply" isn't a literal block. It's: **post the question, exit**. The next Hermes invocation triggered by liyo's reply re-runs the *calling* skill, which reads the thread and continues.

---

## What this skill does

Wrap the protocol for "post a decision-brief, await a reply, let the caller resume." Encodes the format so every design-mode question reads consistently. Bounded responsibility:

- Format the question per the brief template (below).
- Post it.
- Exit.

Does **not** parse the reply. Does **not** invoke the caller on reply. Does **not** track which call needs which resumption. The caller skill is responsible for its own stateless resumability — it re-reads the thread on next invocation and sees the answer.

---

## Access boundaries (cross-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| Discord | ✅ Read + post |
| `.rlm/*` | ✅ Read |
| Code | ❌ |
| `rlm` write subcommands | ❌ (this skill never writes to RLM) |
| GitHub Issue / PR | ❌ (this skill stays in Discord) |

---

## When to invoke

A design-domain skill should chain to `design-dialogue` when:

- `decompose-spec` is uncertain between two slicing strategies and needs liyo's call
- `select-deployment-strategy` has two close-finalist candidates the matrix can't separate
- `draft-adr` wants to verify liyo's understanding of a trade-off before authoring an ADR
- `compute-impact-scope` flags an ADR conflict and asks "revisit?"

**Do NOT invoke for:**

- Posting a Spec proposal — `signal-to-spec` does that inline.
- Posting WP breakdown for approval — `decompose-spec` does that, then chains to `design-approval` (the gate skill).
- General conversation / acknowledgments — just post in the thread.
- Auto-decided choices where caller has confidence — make the call, document in WP `notes:` / ADR.

---

## Inputs

The caller skill assembles + passes:

| Field | Purpose |
|---|---|
| `caller_skill: str` | Used in the header (`🤔 <caller> 需要你拍板:`) |
| `question: str` | Main question — concrete, 1-3 sentences |
| `options: list[Option]` | 2-4 labelled choices, each with one-line consequence |
| `recommendation: str` | Caller's preferred option (must match an option label) |
| `rationale: str` | 1-line reason for the recommendation |
| `change_my_mind: str` | What evidence would shift recommendation |
| `auto_decide_after_minutes: int = 30` | Timeout for caller to assume recommendation |

---

## Output format (the post)

Post in the active Discord thread with this exact structure:

```
🤔 <caller-skill> 需要你拍板:

<question — concrete, 1-3 sentences>

選項:
A) <option label>
   ↳ <one-line consequence>
B) <option label>
   ↳ <one-line consequence>
C) <option label, optional>
   ↳ <one-line consequence>

我傾向 <X>。<rationale>。
讓我改主意:<change-my-mind condition>。

回 `A` / `B` / `C` 或自由回。<N> min 沒回我照 <X>。
```

This is borrowed from gstack `/plan-ceo-review` decision-brief style, simplified for Discord plain text rendering (no nested formatting, no ELI10 preamble).

---

## Reply handling — **NOT this skill's job**

When liyo replies, the calling skill is what resumes. It:

1. Re-reads the Discord thread on its next invocation
2. Finds its own `design-dialogue`-posted question (by the `🤔` header + caller-skill name)
3. Parses the reply:
   - Single-letter `A` / `B` / `C` (case-insensitive) → maps to option label
   - "approve A" / "go with B" / "let's do C" → same
   - Free-form text → caller interprets in context
   - No reply within timeout → caller assumes recommendation
4. Continues its own work

`design-dialogue` itself is **fire-and-forget**. It does not re-run on the reply.

---

## Decision rules (per gstack anti-sycophancy)

- **Recommendation always present.** Refusing to recommend is uncalibrated and wastes liyo's time.
- **State `change-my-mind` explicitly.** "I prefer A; if X were true I'd flip to B." Forces the question's stakes to be legible.
- **Cap options at 4.** More options = decision paralysis. If you have 5+, the question isn't focused enough.
- **One question per invocation.** If the caller has multiple, post them in series (one round, get reply, next round). Stacking confuses the parsing.
- **Free-form replies tolerated.** liyo may type "actually both A and B" or "hybrid". Caller must handle ambiguity gracefully (often: re-invoke `design-dialogue` with refined question).

---

## Examples

### `decompose-spec` asks about slice granularity

```
🤔 decompose-spec 需要你拍板:

把 "Mobile UI" 拆成 1 個 WP 還是 2 個(分開做 list view 跟 detail view)?

選項:
A) 1 個 WP — UI 一起做,demo 完整
   ↳ 一次 worker iteration 包到 list + detail + interactions
B) 2 個 WP — 拆成兩個 vertical slice
   ↳ 先 list view 端到端,demoable;再 detail view 端到端

我傾向 A。Demo 價值在「能用」,UI 通常一個 slice 比較自然。
讓我改主意:如果 detail view 的互動複雜度 ≥ list view 的一半,我會推 B。

回 A / B 或自由回。30 min 沒回我照 A。
```

### `select-deployment-strategy` between two close options

```
🤔 select-deployment-strategy 需要你拍板:

Vercel + Vercel Postgres 跟 Fly.io + Fly Postgres 都過 constraint。差別:

選項:
A) Vercel (Tokyo)
   ↳ 80ms TW;free tier 起跑;一個 vendor billing
B) Fly.io (Singapore)
   ↳ 50ms TW;Postgres add-on $1.94/月;DX 較重(Dockerfile)

我傾向 A。30ms 不顯著,DX 跟 billing 簡單壓贏。
讓我改主意:如果你打算自己跑 Postgres backup → Vercel Postgres backup 弱,換 B。

回 A / B 或自由回。30 min 沒回我照 A 出 ADR。
```

### `compute-impact-scope` surfaces ADR conflict

```
🤔 compute-impact-scope 需要你拍板:

WP #14 的 impact 跨到 cart-checkout seam(ADR-0007 鎖死序列化 cart events)。
現在 Spec 暗示要平行 emit,跟 ADR-0007 直接衝突。

選項:
A) 重議 ADR-0007 — 開新 ADR 替代,WP #14 等 ADR-merge 才能 approve
   ↳ 整套 cart 序列化策略翻案;影響面 wide
B) WP #14 改設計 — 維持序列化,用 batch emit 達成 Spec 目標
   ↳ 較小 scope;但 throughput 可能不到 Spec 隱含的 SLA

我傾向 A。Spec 的 throughput 是 load-bearing,序列化是 v1 妥協。
讓我改主意:如果 throughput 數字其實是 nice-to-have 不是 must → B。

回 A / B 或自由回。30 min 沒回我照 A,開新 ADR PR。
```

---

## Failure modes

- **Caller passes < 2 options** — refuse, return error. A "question" without alternatives is just an announcement.
- **Recommendation doesn't match any option label** — refuse, return error.
- **Question is vague / long-winded** — caller's problem, not yours. But if you notice the caller is passing 200-word "questions", that's a smell — design-dialogue is for tight decisions, not for narrating.

---

## What this skill does NOT do

- Does not parse the reply or resume the caller
- Does not invoke `rlm` subcommands
- Does not read code
- Does not commit anything
- Does not handle gates (those are `intake-confirmation` / `design-approval`, distinct cross-domain skills)

---

## Voice

Decision-brief tone: direct, recommendation-bearing, change-my-mind always stated. Fitted to Discord plain text — no nested bullets, no header hierarchy. Two-letter / three-letter option labels for easy reply.

Don't pad. The question itself should be ≤ 3 sentences; the post total ≤ 12 lines.
