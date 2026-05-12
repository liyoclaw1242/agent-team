# agent-team

AI Agent-Team v1 — sweet-home workflow runtime + Hermes skills pipeline.

完整流程：Discord signal → Spec → WorkPackages → Worker → WhiteBox → BlackBox → PR merge。

---

## 架構概覽

```
Hermes (Persistent tab)     sweet-home workflow runtime
  signal-to-spec ──────────→ hermes-intake (One-Shot)
  decompose-spec ──────────→ [human gate: approve WPs]
                                    ↓ status:approved + agent:worker
                             worker (One-Shot, git worktree)
                                    ↓ kind:delivered
                             whitebox-validator (One-Shot)
                                    ↓ kind:approved
                             blackbox-validator (One-Shot)
                                    ↓ kind:approved
                             status:validated → human merge PR
```

**關鍵設計：**
- Hermes daemon 被 sweet-home **Persistent tab** 的 Claude Code session 替代（v1）
- sweet-home 是 workflow runtime，負責所有 One-Shot dispatch
- 兩者透過 **GitHub Issue labels** 溝通（label state machine）

---

## 前置需求

```bash
which claude && claude --version   # >= 2.x
which gh && gh auth status         # logged in as target repo owner
which node && node --version       # >= 20
which pnpm && pnpm --version
which cargo && cargo --version     # >= 1.85
which uv && uv --version           # for rlm CLI install
```

⚠️ **claude binary 必須在 `/opt/homebrew/bin/` 或 `/usr/local/bin/`**（GUI app PATH）：
```bash
ln -sf ~/.local/bin/claude /opt/homebrew/bin/claude
```
不做這步，sweet-home 的 Persistent tab 和 workflow One-Shot 都找不到 claude。

---

## 首次安裝

### 1. 安裝 rlm CLI（Python 版）

```bash
cd tools/rlm
uv tool install .
which rlm   # should be ~/.local/bin/rlm
```

### 2. 安裝 Hermes skills

```bash
./sync-hermes-skills.sh
# 複製 12 個 skills 到 ~/.hermes/skills/intake/ 和 /design/
```

### 3. 同步 skills 到 Claude Code 全局

```bash
rsync -a .claude/skills/ ~/.claude/skills/
```

### 4. 初始化 target repo

```bash
./init-target-repo.sh --repo ORG/REPO --path /abs/local/path
```

這個腳本：
- 在 target repo 建立所有必要的 GitHub labels（19 個）
- 更新 `.workflow-repos.json`（sweet-home poll 目標）
- 寫入 `~/.hermes/agent-team.env`（skills 讀取 target repo 資訊）

### 5. 建置 sweet-home

```bash
cd ~/Projects/agent-sweet-home
pnpm install
cargo build --manifest-path src-tauri/Cargo.toml --no-default-features
# 或打完整 release build：
pnpm tauri build
cp -R "src-tauri/target/release/bundle/macos/Agent Sweet Home.app" /Applications/
```

---

## 啟動流程

### Terminal 1 — sweet-home workflow runtime

```bash
cd ~/Projects/agent-sweet-home
WORKFLOW_FILE=~/Projects/agent-team/agent-team.workflow.yaml \
    cargo run --manifest-path src-tauri/Cargo.toml --no-default-features
```

或直接開 `/Applications/Agent Sweet Home.app`（需先在 WorkflowView 存好 YAML 路徑）。

### sweet-home WorkflowView

- 確認綠燈 + Applied path 顯示正確的 yaml 路徑
- One-Shot tab 選 target repo 可查看 workflow spawn log

---

## 使用流程

### Phase 1 — Intake（Persistent tab）

1. sweet-home → Persistent tab → `+` 開新 session
2. 輸入 `/signal-to-spec`
3. 跟 Claude 描述要做的功能
4. 確認 Spec 草稿後輸入 `yes`
5. Claude 自動執行 Phase A.5：`gh issue create --label "kind:spec,agent:hermes-intake,status:proposed"`
6. sweet-home ≤30s 內 dispatch hermes-intake One-Shot（Phase B：rlm 寫入）
7. Issue label 翻成 `agent:hermes-design` 後進 Phase 2

### Phase 2 — Design（另一個 Persistent tab）

⚠️ **hermes-design 是 human-gated，不會自動 dispatch**

1. 等 issue label 翻成 `agent:hermes-design + status:proposed`
2. 開新 Persistent session，輸入 `/decompose-spec`
3. 審核 WP breakdown，確認後讓 Claude 用 `gh issue create` 建立 WP issues
4. 建立的 WP labels：`kind:workpackage + status:proposed + agent:hermes-design`

### Phase 3 — Approve WPs（手動）

審核每個 WP 後，逐一 approve：

```bash
gh issue edit <N> --repo ORG/REPO \
  --remove-label "status:proposed,agent:hermes-design" \
  --add-label "status:approved,agent:worker"
```

approve 後 sweet-home 自動 dispatch Worker。

### Phase 4 — Delivery（全自動）

```
Worker → WhiteBox → BlackBox → status:validated
```

全部由 sweet-home One-Shot 自動跑，不需要介入（除非 Arbiter 升級到 human-help）。

### Phase 5 — Merge & Close（手動）

```bash
# merge PR
gh pr merge <PR_NUM> --repo ORG/REPO --squash

# close WP issue
gh issue close <WP_NUM> --repo ORG/REPO --comment "Delivered. PR #N merged."

# 當所有 WP 完成後，close Spec issue
gh issue close <SPEC_NUM> --repo ORG/REPO
```

---

## 已知問題 & 注意事項

### whitebox-validator 必須輸出自己的 JSON envelope

whitebox-validator 跑完 code-review sub-skill 後，**必須**輸出自己的 `{"kind":"approved"/"rejected"}` JSON，而不是讓 code-review 的 JSON 成為最後輸出。SKILL.md 已有說明，但如果 Arbiter 被觸發，手動 reset：

```bash
gh issue edit <N> --repo ORG/REPO \
  --remove-label "agent:arbiter,status:blocked,agent:human-help" \
  --add-label "agent:validator"
```

### on_no_structured_output atomic label 移除問題

`on_no_structured_output` 會嘗試一次移除所有 `agent:*` labels（原子操作）。若其中有任何 label 不存在，整個操作失敗。這是 v1 已知限制，不影響 happy path。

### BlackBox 沒有 sandbox server（v1 限制）

BlackBox 嘗試 curl localhost 測試，但沒有自動啟動 dev server。如果 BlackBox rejected，確認 code review 通過後可手動推進：

```bash
gh issue edit <N> --repo ORG/REPO \
  --remove-label "agent:blackbox-validator" \
  --add-label "agent:blackbox-validator"  # 重新 dispatch
```

或直接手動 merge PR（WhiteBox approved 即可信任）。

### One-Shot tab 顯示空白

需要在 sweet-home sidebar 選中對應的 target repo 才能看到該 repo 的 One-Shot runs。

### rlm CLI 版本

`/opt/homebrew/bin/rlm` = 舊 Node.js 版（已被取代）  
`~/.local/bin/rlm` = 新 Python 版（`uv tool install tools/rlm/`）

確保 `~/.local/bin` 在 PATH 前面。

---

## 重要腳本

| 腳本 | 用途 |
|---|---|
| `init-target-repo.sh --repo ORG/NAME --path /abs/path` | 初始化 target repo（labels + workflow-repos.json + .env） |
| `sync-hermes-skills.sh` | 同步 12 個 Hermes skills 到 `~/.hermes/skills/` |

---

## 相關 repo

| Repo | 用途 |
|---|---|
| `liyoclaw1242/agent-team` | 本 repo：workflow yaml、skills、rlm CLI、init scripts |
| `liyoclaw1242/agent-sweet-home` | Workflow runtime（Tauri app） |
| Target repo（如 `todo-20260512`）| 實際收 Issues 和 PRs 的產品 repo |
