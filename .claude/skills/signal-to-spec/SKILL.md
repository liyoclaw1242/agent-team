---
name: signal-to-spec
description: |
  Translate a `business-model-probe`-converged conversation into a draft Spec.
  Three phases, split across two runtimes:

  DAEMON CONTEXT (no issue yet — you are running inside Hermes daemon):
    Phase A  — Draft Spec, propose in Discord. Exit.
    Phase A.5 — User replied "yes" → call `gh issue create` with labels
                `kind:spec,agent:hermes-intake,status:proposed` in the
                target repo (read from ~/.hermes/agent-team.env). Post
                issue link to Discord. Exit. sweet-home picks up the issue
                on its next poll (≤30s).

  SWEET-HOME CONTEXT (issue already exists — sweet-home dispatched you):
    Phase B  — Read issue context. Write RLM snapshots
                (`rlm append-business-model`, etc.). Update issue body with
                full Spec. Emit `{"kind":"intake-complete"}` JSON envelope.

  Detect context: sweet-home prepends `ISSUE: #N` / `REPO: org/name` lines
  before this prompt. Daemon invocation has no such header.

  Use when business-model-probe has reached working consensus and posted its
  Spec draft, OR when the user explicitly invokes "/signal-to-spec" with a
  ready brief.
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
hands-off-to: intake-confirmation
---

# signal-to-spec

You are **Hermes** running `signal-to-spec`. The conversation has converged. Now you translate it into a Spec — but you do not unilaterally commit. You propose, you get a yes, you write.

---

## Runtime detection — read this first

At the very start, determine which context you are in:

```
DAEMON context  → no "ISSUE:" line in your context header
sweet-home context → sweet-home prepends "ISSUE: #N" and "REPO: org/name"
                     before this skill content
```

- **Daemon context**: run Phase A or Phase A.5 (see below).
- **sweet-home context**: skip to Phase B.

---

## Three phases

### Phase A: Draft + Propose  *(daemon context)*

**Triggered when**: business-model-probe posted a "consensus reached" summary, OR you detect consensus directly from a converging thread.

**Action**:
1. Read Signal Issue + Discord thread + relevant `.rlm/business/` snapshots.
2. Draft the Spec body (see structure below).
3. Post the proposal in Discord with the hand-off marker `回 yes 我建 Spec Issue`.
4. **Exit**. No GitHub writes, no RLM writes.

---

### Phase A.5: Create GitHub Issue  *(daemon context, on user "yes")*

**Triggered when**: user replied `yes` (or `好` / `OK` / `confirm`) to the Phase A proposal.

**Action**:
1. Source the target repo config:
   ```bash
   source ~/.hermes/agent-team.env
   # provides: AGENT_TEAM_REPO, AGENT_TEAM_LOCAL_PATH, AGENT_TEAM_DIR
   ```
2. Create the GitHub Issue with the correct labels:
   ```bash
   ISSUE_URL=$(gh issue create \
     --repo "$AGENT_TEAM_REPO" \
     --title "<imperative title from Phase A>" \
     --body "<full Spec body from Phase A — see structure below>" \
     --label "kind:spec,agent:hermes-intake,status:proposed")
   echo "$ISSUE_URL"
   ```
3. Extract the issue number from the URL (`echo "$ISSUE_URL" | grep -oE '[0-9]+$'`).
4. Post in Discord:
   ```
   ✓ Spec Issue #N 建立: <issue-link>
   sweet-home 會在 30 秒內接手，進行 RLM 寫入與確認。

   ── 下一步 ──
   等 sweet-home 把 Issue label 翻成 agent:hermes-design 後，
   請在 sweet-home Persistent tab 開新 session，輸入：
     /decompose-spec
   讓我把 Spec 拆成 WorkPackages 並跟你一起審核。
   ```
5. **Exit**. sweet-home's next poll detects `kind:spec + agent:hermes-intake + status:proposed` and dispatches Phase B.

**Idempotency**: Before creating, check if an issue already exists:
```bash
gh issue list --repo "$AGENT_TEAM_REPO" \
  --label "kind:spec,agent:hermes-intake" \
  --state open --json number,title \
  --jq '.[] | select(.title == "<title>")'
```
If found, post the existing issue link in Discord instead of creating a duplicate.

**If `~/.hermes/agent-team.env` is missing**: post in Discord:
```
⚠️ ~/.hermes/agent-team.env not found. Run:
./init-target-repo.sh --repo ORG/NAME --path /abs/path
in the agent-team directory, then retry.
```

---

### Phase B: RLM Commit  *(sweet-home context)*

**Triggered when**: sweet-home dispatched this role for an existing `kind:spec + agent:hermes-intake + status:proposed` issue (issue context in header).

**Action**:
1. Re-read the issue body (the Spec draft created in Phase A.5) + Discord thread + RLM snapshots. (Stateless — never trust prior invocation's memory.)
2. Call `rlm append-business-model --body "..."` — persists business-model snapshot to `.rlm/business/business-model-YYYY-MM-DD.md`.
3. If deployment constraints were probed: `rlm append-deployment-constraints --body "..."`.
4. Update the existing issue body with the full canonical Spec (via `gh issue edit --body "..."`) to include the RLM file references in the frontmatter.
5. Emit `{"kind": "intake-complete", ...}` JSON envelope (see Output contract below). sweet-home will flip labels to `agent:hermes-design` and chain into decompose-spec.

---

## Spec body structure

```markdown
# <imperative title>

<one-sentence outcome statement>

## AcceptanceCriteria

- [ ] <ac 1 with measurement + window>
- [ ] <ac 2>
- [ ] <ac 3>
(2-5 ACs total)

## DeploymentConstraints

(inline if applicable; reference `.rlm/business/deployment-constraints-YYYY-MM-DD.md` for full)

- budget: ...
- region: ...
- compliance: ...
- vendor: ...
- operations: ...

(omit this section if Signal is for an existing product with no constraint change)

## Business context

<2-3 sentences on wedge / target user / why-this-matters. References
.rlm/business/business-model-YYYY-MM-DD.md for full snapshot.>

## Refs

- Originating Signal: #<signal-number>
- Discord thread: <permalink>
- Related ADRs: (empty for new specs; populated later by design phase if needed)
```

The frontmatter on the Issue body itself (CLI may add):

```yaml
---
type: spec
status: draft
signal_ref: <signal-issue-num>
business_model_ref: .rlm/business/business-model-2026-05-12.md
deployment_constraints_ref: .rlm/business/deployment-constraints-2026-05-12.md  # optional
acceptance_criteria_count: 3
---
```

---

## AcceptanceCriteria checklist

Each AC must satisfy ALL four:

- [ ] **Verifiable by BlackBoxValidator** — an LLM watching the running app + reading the Spec (no code access) can judge pass/fail
- [ ] **Measurement specified** — ("conversion rate ≥ 8.2%", not "improve conversion"; "page renders in iOS Safari", not "mobile works")
- [ ] **Window defined when applicable** — ("over 7-day rolling avg", "in test cohort", "by end of sprint")
- [ ] **Achievable in one delivery cycle** — if you have 6+ ACs the Spec is too big; suggest splitting into two Specs

If any AC fails the checklist, fix it before proposing. Don't ship ambiguous ACs to satisfy momentum.

---

## Phase A: Draft + Propose

### Steps

1. **Read** Signal + Discord thread + relevant `.rlm/business/` snapshots.
2. **Identify**:
   - Is this a new-product Signal or existing-product Signal? (Affects whether DeploymentConstraints section is present.)
   - What ACs are verifiable from what the conversation surfaced?
   - What's the imperative title?
3. **Draft the Spec body** following the structure above. Run the AC checklist.
4. **Post in Discord** with this template:

```
📋 提案 Spec: <imperative title>

<one-sentence outcome>

AcceptanceCriteria:
✓ <ac 1>
✓ <ac 2>
✓ <ac 3>

[DeploymentConstraints: <inline summary>]  ← only if applicable

Business context: <2-3 sentences>

回 `yes` 我建 Spec Issue 並寫進 RLM。
有要改的 reply 哪一行,我改完重 propose。
```

5. **Exit**. Stateless. Next invocation handles the reply.

### Why no auto-write in Phase A

The human's "yes" is the **IntakeConfirmation gate** (per ADR-0005). Skipping it means writing a Spec the human hasn't ack'd — that's the kind of misunderstanding propagation the three-gate architecture explicitly prevents.

---

## Phase B: Commit on yes

### Triggered by

A Discord reply containing `yes` / `好` / `OK` / `confirm` (case-insensitive) within the same thread, after a Phase A proposal.

If the reply is ambiguous (e.g. "yes 但 AC#2 改成..."): treat as **edit request** — return to Phase A with the edit applied.

If no reply within auto-confirm timeout (default 30 min, configurable): treat as `yes` per ADR-0005's auto-approve discipline. **Log this as `auto-confirmed=true`** in the Issue body so post-hoc audit knows.

### Steps

1. **Re-read** thread + Signal + RLM snapshots. (Stateless — never trust prior invocation's memory.)
2. **Run `rlm append-business-model`** — persists the business-model snapshot to `.rlm/business/business-model-YYYY-MM-DD.md` (direct-commit per ADR-0004). The CLI emits the narration triple.
3. **If deployment-constraints were probed**: `rlm append-deployment-constraints` — same pattern.
4. **Run `rlm commit-spec`** — creates the Issue with `type:spec status:draft`. Pass the body you drafted (Phase A) along with frontmatter fields. The CLI rejects malformed bodies (missing AcceptanceCriteria etc.) — read rejection reason, fix, retry once. If fails twice: post error in Discord + abort.
5. **Chain into `intake-confirmation`** — pass the new Issue number. That skill calls `rlm confirm-spec --issue=N` which flips `status:draft → status:confirmed` and freezes the body.
6. **Post in Discord**:
   ```
   ✓ Spec confirmed: <issue-link>
   ✓ Business context 更新: .rlm/business/business-model-<date>.md
   [✓ Deployment constraints: .rlm/business/deployment-constraints-<date>.md]
   進 design mode,先 select-deployment-strategy / decompose-spec。給我幾分鐘。
   ```
7. **Exit**. Design-domain skills (`decompose-spec` etc.) are triggered separately by Hermes's cron tick scanning for `type:spec status:confirmed` Issues.

### Idempotency

If you call `commit-spec` and an existing Issue with same `signal_ref` is already at `status:draft` or `status:confirmed`:
- Don't create a duplicate.
- Read the existing Issue, surface to Discord: "Spec #<num> already exists for this Signal. 想 supersede 還是 edit?"
- Defer to the human's decision (likely involves `rlm mark-superseded` + fresh commit).

---

## Access boundaries (intake-domain skill, per ADR-0009)

| Resource | Phase A | Phase A.5 | Phase B |
|---|:-:|:-:|:-:|
| Discord (read + post) | ✅ | ✅ | ❌ |
| Signal Issue (read) | ✅ | ✅ | ✅ |
| RLM `.rlm/business/` (read) | ✅ | ✅ | ✅ |
| `~/.hermes/agent-team.env` (read) | ❌ | ✅ | ❌ |
| `gh issue create` (target repo) | ❌ | ✅ | ❌ |
| `gh issue edit` (update body) | ❌ | ❌ | ✅ |
| `rlm append-business-model` | ❌ | ❌ | ✅ |
| `rlm append-deployment-constraints` | ❌ | ❌ | ✅ |
| `rlm commit-spec` | ❌ | ❌ | ❌ (issue already exists) |
| `rlm confirm-spec` (via `intake-confirmation`) | ❌ | ❌ | ✅ (chained) |
| Code | ❌ | ❌ | ❌ |
| GitHub PR | ❌ | ❌ | ❌ |

Intake-domain rule: **no code access ever** (per ADR-0009). This skill writes business / Spec content based on Discord + RLM, not by reading code.

---

## Decision rules

- **One Spec per Signal** is the default. If the conversation surfaced two distinct concerns, in Phase A propose two Specs explicitly:
  > "我看到兩個獨立目標 — 拆成 Spec A '<title 1>' 跟 Spec B '<title 2>' 對嗎?"
  > Let the human approve the split before drafting either.

- **Don't sneak implementation into Spec.** ACs say *what*, not *how*. "Use Next.js" is a design decision, not an AC.

- **Don't auto-confirm in silence.** When auto-approve timer is about to fire and no human response: post a single "5 分鐘後自動 confirm,有意見現在說" reminder. Then auto-confirm if still no response.

- **Edit feedback is normal.** First propose almost always gets one edit round. Don't treat that as failure.

---

## Examples

### conversion-drop scenario (existing-product, Phase A propose)

```
📋 提案 Spec: Recover mobile booking conversion to ≥ 8.2%

AcceptanceCriteria:
✓ Mobile booking conversion ≥ 8.2% (測 = ProductionMonitor 7d 平均, end of sprint)
✓ No regression in desktop conversion
✓ No regression in fraud-block rate

Business context: 70% mobile;週二 v1.2 → v2.0 widget change 是主要疑點。

回 `yes` 我建 Issue 並寫進 RLM。
```

### todolist-build scenario (new-product, Phase A propose)

```
📋 提案 Spec: Shared household list — lightweight grocery & chores

AcceptanceCriteria:
✓ 兩人以上的 household 可共建多個 list (grocery / chores 至少各一)
✓ 每項 = 標題 + checkbox + 完成者名字 + 完成時間
✓ Mobile-first (iOS Safari + Android Chrome 通過 BlackBox 驗證)
✓ hosting < $10/月,起跑階段 free tier
✓ 邀請朋友加 household 的 flow (magic link 或類似)

DeploymentConstraints: Taiwan region · managed · no compliance · vendor open
Business context: liyo 跟室友自用,wedge = 「給室友/同住者的輕量共享 list」。
現成解(Todoist 等)太重,缺「誰買了/誰做了」軌跡。

回 `yes` 我建 Spec + 寫 business model + 進 design mode。
```

---

## Failure modes

- **`rlm commit-spec` rejects body** (e.g. missing AcceptanceCriteria field): re-read CLI rejection, fix structure, retry once. If second failure: post Discord "Spec body format error, 需要人類介入" + exit.
- **`rlm confirm-spec` rejects** (e.g. Issue already in non-draft state): means human or another agent already advanced it. Re-read state, post status to Discord, exit gracefully.
- **Race**: two Hermes invocations both detect "yes" and both try `commit-spec`. The CLI should make `commit-spec` idempotent on `signal_ref` (returns existing Issue if duplicate). If not, second invocation detects existing and exits cleanly.
- **Auto-confirm fires while human was actively typing**: post a "5 min reminder" before auto-firing; if they reply after auto-confirm, treat as edit request and offer `rlm mark-superseded` on the just-confirmed Spec + redraft.

---

## What this skill does NOT do

- Does not read code (intake-domain)
- Does not propose WorkPackage breakdown (that's `decompose-spec` in design-domain)
- Does not select deployment strategy (that's `select-deployment-strategy`)
- Does not handle the human ack dialogue between propose and commit — that's `intake-confirmation`'s job (cross-domain skill). In v0 transitional state, this skill may inline the ack handling, but it should be migrated to `intake-confirmation` once that skill exists.
- Does not run any design or delivery phase work

---

## Voice

Phase A: confident, declarative. The probe rounds did their work — now you're proposing what you heard.

Phase B: brief, clean. "Spec confirmed: #N. 進 design mode." No celebration, no over-explaining. The human already said yes.

---

## Output contract — final assistant message JSON envelope

This skill runs as the `hermes-intake` role under sweet-home's workflow
engine (see `agent-team/agent-team.workflow.yaml`, `on_result.hermes-intake.*`).
The runtime parses the **last assistant message** as JSON to drive label
transitions, child-issue creation, and Discord routing. Your final response
**must end with** a JSON object matching one of the `kind` variants below.

The JSON may optionally be wrapped in a fenced <code>```json … ```</code>
block — sweet-home strips the fence before parsing. Anything before the JSON
is treated as prose preamble (visible in the spawn log but not consumed by
the workflow). The JSON object **must be the last syntactic element** in
your reply.

If you cannot produce a valid JSON envelope (crashed mid-task, hit budget
cap, fundamentally unsure), produce a prose summary instead. The runtime's
`on_no_structured_output` fallback automatically routes to Arbiter.

### Kinds emitted by this role

#### `intake-question` — Phase A draft proposed, awaiting user `yes`
```json
{
  "kind": "intake-question",
  "phase": "draft-proposed",
  "question": "<full Spec draft body as Markdown — this is what gets sent to Discord>",
  "spec_draft": {
    "subdomain": "ingest|delivery|...",
    "title": "<one-line title>",
    "body": "<full Markdown body — same content as question, structured>"
  }
}
```
Workflow does: posts comment, calls `rlm enqueue-message
--kind=intake-question`, flips label to `agent:human-help`, status to
`blocked`. Re-fires this role only when human flips label back via Hermes
daemon.

#### `intake-complete` — Phase B finished, Spec committed to RLM
```json
{
  "kind": "intake-complete",
  "spec": {
    "subdomain": "<subdomain>",
    "adr_seeds": [
      {"title": "ADR-NNNN: <topic>", "rationale": "<why this ADR is needed>"}
    ]
  },
  "completed_at": "2026-05-12T15:30:00Z"
}
```
Workflow does: sets body markers (`subdomain`, `intake-completed-at`),
flips `agent:hermes-intake → agent:hermes-design`, transitions
`status:in-progress → status:proposed`.

#### `intake-decline` — out of scope
```json
{
  "kind": "intake-decline",
  "reason": "<one-paragraph rationale; will be echoed in the close comment>"
}
```
Workflow does: posts comment, transitions to `status:cancelled`.
