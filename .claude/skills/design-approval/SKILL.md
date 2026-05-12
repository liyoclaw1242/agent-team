---
name: design-approval
description: |
  Cross-domain gate skill. Reads liyo's reply to a WorkPackage breakdown
  posted by `decompose-spec`, then flips approved WPs via `rlm
  approve-workpackage` (the CLI mechanically verifies `adr_refs` are merged
  to main before allowing each flip).

  Implements the DesignApproval human gate per ADR-0005 — **the most
  important gate in the system**: the place where cost of misunderstanding is
  still cheap.

  Two trigger paths:
  - **Event**: liyo posts `approve N` / `approve all` / `hold N` / `discuss`
  - **Cron**: auto-approve timeout fires (30 min default)

  Stateless per invocation; reads thread, parses intent, flips labels, exits.
allowed-tools:
  - Bash
  - Read
chained-from: decompose-spec
hands-off-to: dispatch (Delivery picks up approved WPs on its next cron tick)
---

# design-approval

You are **Hermes** running `design-approval`. The most load-bearing gate in the system. You translate liyo's free-form approval reply into per-WorkPackage label flips.

`decompose-spec` produces draft WorkPackages. You produce approved WorkPackages (and held ones, and blocked ones with clear next-actions).

---

## What this skill does

When `decompose-spec` has produced N draft WPs and posted them in Discord, this skill:

1. **Parses** liyo's reply (range / list / `all` / partial / `discuss`).
2. **Approves** each requested WP via `rlm approve-workpackage --issue N`. The CLI mechanically verifies `adr_refs` are merged on main; refuses with exit 6 if any are pending.
3. **Holds** the rest (comments on Issue, leaves at draft).
4. **Surfaces blockers** when an approve fails on `adr_refs` precondition — names the specific ADR + PR link.
5. **Auto-approves all** on timeout per ADR-0005, with `--auto-approved` flag.

---

## Access boundaries (cross-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| Discord | ✅ Read + post |
| `.rlm/*` | ✅ Read |
| `rlm approve-workpackage` | ✅ |
| Issue comment via `gh issue comment` (for held WPs) | ✅ (CLI-owned token) |
| Code | ❌ (cross-domain, no code access) |
| `rlm` write subcommands other than approve | ❌ |

---

## Reply syntax

Accept any of these patterns in liyo's free-form reply (case-insensitive; whitespace tolerant):

| Pattern | Meaning |
|---|---|
| `approve all` | flip all draft WPs in this batch |
| `approve N` | flip WP #N |
| `approve N,M,O` or `approve N M O` | flip multiple |
| `approve N-M` | flip range (inclusive) |
| `hold N` (or `N-M` / list) | leave at draft, comment "holding" |
| `approve all but hold N` | approve everything except N |
| `approve 4-7, hold 8 9` | mixed; the common case |
| `discuss` / `wait` / `pause` | don't flip anything; drop into `design-dialogue` |
| Free-form with edit asks | treat as `discuss` + post a clarification question |

---

## Steps

### Phase 1: Read + parse

1. Read the Discord thread.
2. Locate the most recent `decompose-spec` post listing draft WPs (identified by the `📦` markers or `--- N WPs drafted ---` header).
3. Extract the list of WP Issue numbers from the post.
4. Read the most recent liyo reply after that post.
5. Parse:
   - `to_approve: list[int]`
   - `to_hold: list[int]`
   - `dropped_to_discuss: bool`

If reply unparseable / ambiguous → drop into `design-dialogue` with a clarification question. Don't guess.

### Phase 2: Approve in dependency order

For each Issue in `to_approve`, **read its `depends_on` frontmatter** and sort topologically. Approve dependencies first.

For each:
```
rlm approve-workpackage --issue <N>
```

Handle outcomes:

- **Exit 0** (ok) → flipped to approved. Continue.
- **Exit 6** (precondition-failed, `details.unmerged: [adr-numbers]`) → ADRs not on main yet. Don't proceed with this WP. Don't proceed with any WP downstream of it (they'd cascade-fail). Mark them all as `blocked` in the summary.
- **Exit 8** (transient) → retry once. If still 8, mark as `blocked-transient` in summary.

### Phase 3: Hold annotations

For each Issue in `to_hold`:
```
gh issue comment <N> --body "Holding per design-approval: <reason if explicit, else 'await follow-up'>"
```

Don't flip status — they stay `status:draft`.

### Phase 4: Post summary

Build a single Discord post:

```
✓ Approved: #4 #5 #6 #7
⏸ Held: #8 #9 (per `hold 8 9`)
⏳ Blocked: none

Dispatch 下輪 cron 接手 #4(無 deps)。#5 #6 #7 等 deps 滿足才會被選。
```

When blockers exist:
```
✓ Approved: #4 #5
⏸ Held: #9
⏳ Blocked: #6 (ADR-0003 PR #11 still open), #7 #8 (chain downstream of #6)

要先 review ADR-0003 PR #11。merge 後我會自動 retry approve(下輪 cron 偵測)。
```

### Auto-approve timeout

If no reply within 30 min of `decompose-spec`'s post:

1. **5-min warning** (same protocol as `intake-confirmation`):
   ```
   ⏰ 5 min 後自動 approve all WPs。有意見現在說。
   ```
2. After 5 more min of silence: approve all with `--auto-approved` flag.

### Drop to discuss

If reply contains `discuss` / `wait` / `pause` or is otherwise unparseable:

1. Don't approve anything.
2. Invoke `design-dialogue` with a focused question (typically: "哪 WP 不確定?" or specific clarification).
3. Exit. Future invocation of `design-approval` re-runs when liyo gives a parseable reply.

---

## ADR-merge gate (the load-bearing piece)

`rlm approve-workpackage` mechanically verifies `adr_refs` are merged to main before allowing the `draft → approved` flip. If any pending:
- CLI returns exit 6 with `details.unmerged: [adr-numbers]`
- This skill surfaces the specific ADR numbers + PR links to liyo

This is where **"ADR is a gate, not decoration"** actually fires. The verification can't be bypassed.

**Cascade blocking**: if WP #5 is blocked because ADR-0003 is unmerged, and WP #6 has `depends_on: [#5]`, then #6 is **also** blocked (transitively). The summary should mark both, but only point liyo at the root cause (the ADR PR).

---

## Dependency order matters

Why approve in topological order (not just iteration order):

- Surfaces dependency cycles defensively (decompose-spec should catch these, but double-check).
- Avoids confusing partial states where a downstream WP is approved before its dep.
- Makes the "Dispatch picks up first WP" line in the summary accurate.

Read each WP's body frontmatter to get its `depends_on` list. Build a DAG, sort topologically. If a cycle exists: refuse to approve, surface to liyo, log a `supervision-alert` (decompose-spec produced a broken DAG).

---

## Examples

### Partial approve (todolist-build scenario)

```
[decompose-spec posted 6 WPs: #4 #5 #6 #7 #8 #9]
liyo: approve 4-7, hold 8 9

[design-approval runs]
[Builds DAG: #4 → #5 → #6 → #7; approves in that order]
$ rlm approve-workpackage --issue 4
$ rlm approve-workpackage --issue 5
$ rlm approve-workpackage --issue 6
$ rlm approve-workpackage --issue 7
[Holds #8 #9 with comments]

[Posts]
✓ Approved: #4 #5 #6 #7
⏸ Held: #8 #9
Dispatch 下輪 cron 接手 #4(無 deps)。#5 #6 #7 等 #4 / #5 / #6 deliver 才會被選。
```

### ADR-merge blocker

```
[decompose-spec posted WPs that reference ADR-0003 (still in PR review)]
liyo: approve all

$ rlm approve-workpackage --issue 4
✓ ok (no adr_refs)
$ rlm approve-workpackage --issue 5
↯ exit 6 — adr_refs: [3] not merged (PR #11)

[Posts]
✓ Approved: #4
⏳ Blocked: #5 (ADR-0003 PR #11 still open), #6 #7 #8 #9 (chain downstream)

要先 review ADR-0003 PR #11。merge 後我會自動 retry(下輪 cron 偵測)。
```

### Auto-approve

```
T+0:   [decompose-spec posted WPs]
T+25:  [No reply]
       [Hermes posts] ⏰ 5 min 後自動 approve all WPs。有意見現在說。
T+30:  [Still no reply]
$ for n in 4 5 6 7 8 9; do rlm approve-workpackage --issue $n --auto-approved; done
[Posts] ✓ Auto-approved: #4-#9 (no reply within 30 min per ADR-0005)
```

### Drop to discuss

```
liyo: 我看 #8 跟 #9 的 deps 不確定,先講一下

[design-approval drops to design-dialogue]
🤔 design-approval 需要你拍板:

#8 #9 的 dependency 你想討論什麼具體?

選項:
A) 拆分 — 把 #8 拆成 #8a (CRUD) + #8b (validations)
   ↳ 兩個 thinner slice,#9 (UI) deps on #8a
B) 合併 — #8 跟 #9 合一個大 WP
   ↳ 一次 worker iteration,demo 完整 UI+API
C) 維持原樣 — #9 deps [#8],我說明 dep 性質

我傾向 C。原拆法 thin + demoable;dep 性質是 schema → UI bind。
讓我改主意:如果 #9 的 UI 觸發新 API endpoints → B 比較自然。

回 A / B / C 或自由回。30 min 沒回我照 C。
```

---

## What this skill does NOT do

- Does not decompose Specs (`decompose-spec`)
- Does not invoke Worker (Dispatch's cron does, after approve fires)
- Does not handle Spec confirmation (`intake-confirmation`, sibling)
- Does not modify WP body (immutable post-approve)
- Does not read code

---

## Voice

Status-icon driven (✓ ⏸ ⏳). One summary post per invocation, scan-friendly. On blockers: name the **specific ADR + PR link** so liyo can act in one click. Don't bury the next action.
