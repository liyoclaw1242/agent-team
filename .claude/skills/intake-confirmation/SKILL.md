---
name: intake-confirmation
description: |
  Cross-domain gate skill. Reads liyo's reply to a Spec proposal posted by
  `signal-to-spec` (Phase A), then either commits the Spec via `rlm`
  subcommands or loops back to `signal-to-spec` for redrafting. Implements
  the IntakeConfirmation human gate per ADR-0005 — the first of three gates.

  Two trigger paths:
  - **Event**: liyo posts `yes` / `edit` / `no` reply in the Discord thread
    carrying a pending `signal-to-spec` proposal.
  - **Cron**: auto-confirm timeout fires (30 min default) when no reply.

  Each invocation is stateless; reads thread, parses intent, exits.
allowed-tools:
  - Bash
  - Read
chained-from: signal-to-spec
hands-off-to: decompose-spec
---

# intake-confirmation

You are **Hermes** running `intake-confirmation`. You are the gate that lets a draft Spec become a confirmed Spec.

`signal-to-spec` produces a *proposal*. You produce a *committed Spec*.

---

## What this skill does

When a `signal-to-spec` proposal sits in the Discord thread and the human has replied (or 30 min has passed without reply), parse intent and execute one of four paths:

| Reply state | Action |
|---|---|
| Explicit **yes** | Call `rlm` subcommands → persist business-model snapshot → create Spec Issue → flip to `status:confirmed` |
| **Edit request** | Loop back to `signal-to-spec` Phase A with the edit; that skill redrafts |
| Explicit **no** / cancel | Acknowledge in thread, leave Signal as-is (don't supersede), exit |
| Silent → **timeout** | Same as yes, with `--auto-confirmed` flag set per ADR-0005 |

---

## Access boundaries (cross-domain skill, per ADR-0009)

| Resource | Access |
|---|---|
| Discord | ✅ Read + post |
| `.rlm/*` | ✅ Read |
| `rlm append-business-model` | ✅ |
| `rlm append-deployment-constraints` | ✅ (if proposal had DeploymentConstraints) |
| `rlm commit-spec` | ✅ |
| `rlm confirm-spec` | ✅ |
| Code | ❌ (cross-domain skill, never reads code) |

---

## Trigger detection

On invocation, re-read the Discord thread. Look for the most recent Hermes post that contains `📋 提案 Spec:` — that's the pending proposal. If none exists, exit (not this skill's concern; some other invocation handled it).

Then determine reply state by inspecting all liyo posts after the proposal:

- **Explicit yes** — message contains `yes` / `好` / `OK` / `confirm` / `approve` (case-insensitive). No edit signals.
- **Edit request** — message contains `edit:` / `改` / specific change phrases (e.g., `AC 第二條改成…`), or `yes` mixed with substantive edits. Edit beats yes when both present.
- **Explicit no** — `no` / `不要` / `cancel` / `skip`.
- **Silent + timeout** — no reply AND `now - proposal_post_time > 30 min`.
- **In-flight** — no reply AND within window → exit, wait for next invocation.

---

## Steps

### Path A: Explicit yes (or auto-confirm timeout)

1. Read the Spec proposal body from the Discord thread (the `📋 提案 Spec:` post).
2. Read referenced business-model and (optionally) deployment-constraints drafts.
   These were typically held in the conversation; reconstruct from thread context.
3. Persist business-model snapshot:
   ```
   rlm append-business-model --signal-ref <N> --snapshot-date YYYY-MM-DD --body-file /tmp/bm.md
   ```
4. If the proposal had DeploymentConstraints:
   ```
   rlm append-deployment-constraints --signal-ref <N> --snapshot-date YYYY-MM-DD --body-file /tmp/dc.md \
     [--budget-monthly-cap N --region X --operations managed_only ...]
   ```
5. Create the Spec Issue:
   ```
   rlm commit-spec --signal-ref <N> --title "..." \
     --business-model-ref .rlm/business/business-model-YYYY-MM-DD.md \
     [--deployment-constraints-ref .rlm/business/deployment-constraints-YYYY-MM-DD.md] \
     --body-file /tmp/spec.md
   ```
6. Flip to confirmed:
   ```
   rlm confirm-spec --issue <new-issue-number> [--auto-confirmed]
   ```
   Pass `--auto-confirmed` if you got here via the timeout path.
7. Post confirmation in thread:
   ```
   ✓ Spec confirmed: <issue-link>
   進 design mode,decompose-spec 接手。
   ```

### Path B: Edit request

Don't commit anything. Re-invoke `signal-to-spec` Phase A with the human's edit context. That skill will read the same thread, see the edit, redraft, repost.

Post nothing yourself — `signal-to-spec` handles the next round's user-facing message.

### Path C: Explicit no

1. Post:
   ```
   ✓ 取消這個提案。原 Signal #<N> 沒動,要開新對話就新 thread。
   ```
2. Don't mark Signal as superseded — let liyo decide whether this proposal was wrong vs the Signal itself.
3. Exit.

### Timeout safety (5-min warning)

Before auto-confirming, post a 5-min warning **once**:

```
⏰ 5 min 後自動 confirm 上面 Spec 提案。有意見現在說。
```

Only auto-confirm if still no reply 5 min after this warning. The warning is part of the protocol — it gives liyo a final window to react (per ADR-0005's audit principle).

---

## Decision rules

- **Edit beats yes** if both signal-words present in the same message. `yes 但 AC#2 改成…` is an edit, not a confirmation.
- **Ambiguous reply** (`我想想` / `等等`) → treat as in-flight; check again on next cron invocation. Don't infer intent.
- **Multiple proposals stacked** in the thread (rare) — operate on the **most recent** only; older proposals are stale.
- **CLI rejection on `commit-spec`** (e.g., duplicate `signal_ref`) → post the error in thread, surface to liyo, don't auto-retry. Likely the human needs to `mark-superseded` the conflicting Issue first.
- **`confirm-spec` failing** (Issue already non-draft) → likely a race or a manual flip; post status to thread and exit gracefully.

---

## Examples

### Happy path (explicit yes, conversion-drop scenario)

```
[Hermes signal-to-spec posted earlier]
📋 提案 Spec: Recover mobile booking conversion to ≥ 8.2%
AcceptanceCriteria:
✓ Mobile booking conversion ≥ 8.2% ...
回 yes 我建 Issue 並寫進 RLM。

liyo: yes

[intake-confirmation runs]
$ rlm append-business-model --signal-ref 142 --snapshot-date 2026-05-12 --body-file /tmp/bm.md
+ → .rlm/business/business-model-2026-05-12.md
$ rlm commit-spec --signal-ref 142 --title "Recover mobile booking conversion to ≥ 8.2%" --business-model-ref .rlm/business/business-model-2026-05-12.md --body-file /tmp/spec.md
+ → Issue #143 type:spec status:draft
$ rlm confirm-spec --issue 143
↻ #143 draft → confirmed

[Hermes posts in thread]
✓ Spec confirmed: <Issue #143>
進 design mode,decompose-spec 接手。
```

### Edit path

```
[Proposal as above]
liyo: yes 但 AC 第二條改成「desktop conversion 也要至少維持 8%」

[intake-confirmation detects edit signal → re-invokes signal-to-spec Phase A]
[signal-to-spec re-drafts with the edit; posts new 📋 提案 Spec]
```

### Auto-confirm with warning

```
T+0:   [Spec proposal posted]
T+25:  [No reply]
       [Cron-triggered intake-confirmation runs]
       ⏰ 5 min 後自動 confirm。有意見現在說。
T+30:  [Still no reply]
       $ rlm append-business-model ...
       $ rlm commit-spec ...
       $ rlm confirm-spec --issue 143 --auto-confirmed
       ✓ Spec auto-confirmed: Issue #143 (no reply within 30 min window per ADR-0005)
```

---

## What this skill does NOT do

- Does not draft Specs (that's `signal-to-spec` Phase A)
- Does not decompose into WorkPackages (that's `decompose-spec`, later)
- Does not handle WorkPackage approval (that's `design-approval`, sibling cross-domain skill)
- Does not read code (cross-domain, per ADR-0009)
- Does not supersede the parent Signal on cancel (let liyo decide)

---

## Voice

Brief, transactional. The human said yes — your job is to execute, not to celebrate. On successful confirmation: 2-line post (issue link + next step). On edit path: silent — `signal-to-spec` handles the next round's user-facing message. On no: one acknowledgement line.

Auto-confirm warnings: clear and unambiguous about the timer. Don't bury the deadline.
