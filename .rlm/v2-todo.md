# v2 TODO — 遺留待補事項

這份文件追蹤架構討論過程中**明示 deferred** 的所有事項。每項紀錄:

- **狀態**:`pre-v1`(實作前必須訂)/ `pre-v2`(實作可開始,但 v2 前要補)/ `v2-feature`(新能力,不擋 v1)
- **來源**:在哪個 ADR / Fresh-eye round 被標記
- **解法草稿**:目前的最有可能方向(沒承諾)

如果開始實作前 / 過程中決定怎麼解,把對應條目搬出此檔到正式 ADR / CONTEXT。

---

## A. 實作前置(pre-v1 必訂)

這些不訂、`rlm` CLI 不能寫第一行。

### A1. `rlm` CLI 實作選型

**狀態**:`pre-v1`
**來源**:Fresh-eye round 2 #G;ADR-0004 全部依賴它
**待決**:
- 語言:Python / Node / Go / Bash?
- 部署位置:repo 內 `tools/rlm/` 隨原始碼 / 獨立 repo?
- 安裝方式:`pip install` / `npm install` / 單一 binary?
- 維護所有 subcommand 行為的 single source of truth(目前散在 ADR-0004 表 + 各 ADR 散文)

**解法草稿**:Python 套件放 `tools/rlm/`,跟 repo 同步演進,測試用 GitHub Action 跑。

### A2. CI fact-commit check 規格

**狀態**:`pre-v1`(load-bearing — ADR-0013 把它列成 SDD 防崩潰的硬閘)
**來源**:Fresh-eye round 4 #7
**待決**:
- GitHub Action workflow 寫在哪(`.github/workflows/fact-commit-check.yml`?)
- 檢查邏輯:PR 內必須含 *至少一筆* `rlm append-fact` 或 `supersede-fact` commit
- 失敗時 PR 怎麼擋:status check 紅燈 / branch protection rule
- 例外:純文檔 PR、純 ADR PR 是否豁免?(我傾向不豁免 —— 文檔 PR 不該有 WP 關聯)

**解法草稿**:GitHub Action 在 PR 上跑,檢查 commit message 或 file path 確認 fact 寫入。

### A3. Skill 名稱實作清單

**狀態**:`pre-v1`(K2 / 後續 Hermes-only 決議都明示 TBD)
**來源**:ADR-0008 / ADR-0016
**待決**:
- Hermes 的 12 個 skill 各自:檔名 / `.claude/skills/<name>/SKILL.md` frontmatter / 預期 prompt body
- Worker 的 web-stack skill profile 含哪些具體 skills(frontend-component / server-endpoint / db-migration / unit-test / code-refactor / deploy-config 之類)

**解法草稿**:第一個 skill 先寫 `business-model-probe`(對話結構最先用到),其他依需求補。

### A4. Supervision event log backend

**狀態**:`pre-v1`(ADR-0012 標明 "must be durable, queryable, survive restarts")
**來源**:Fresh-eye round 2 + round 4 #12
**待決**:
- 後端:SQLite(本地檔) / Postgres / Cloud log service / 純 JSONL append-only file?
- Schema:遵 ADR-0012 的 event spec(timestamp / source / event_type / payload / parent_triple_id)
- 對 Arbiter 必要:它要能讀「上一個 agent 的 triples」,讀取延遲要夠低

**解法草稿**:v1 用 SQLite(`var/supervision.db`),v2 再考慮升級。

### A5. Global Worker lock 實作

**狀態**:`pre-v1`(ADR-0007 + ADR-0014 都依賴)
**來源**:Fresh-eye round 4 #2
**待決**:
- 後端:Redis key with TTL / Postgres row with expiry / file-based mutex (e.g., flock)
- TTL 長度(Worker iteration 上限 + 緩衝);超時自動釋放避免 hang lock
- 觀察點:lock 持有時長進 Supervision event log

**解法草稿**:v1 用 SQLite 同檔的一筆 lock row + TTL(避免額外 infra);v2 看併發需求換 Redis。

### A6. Discord bot 部署 / 認證

**狀態**:`pre-v1`(hermes-agent daemon 要連 Discord 才能跑)
**來源**:ADR-0008 / flow-visualization
**待決**:
- Discord application 註冊、bot token 哪裡存
- Bot 要連的 channel(`#product`)權限設定
- daemon 跑在哪台機器 / 哪個 service(VPS / Fly / 自家 server)
- daemon 重啟 / 自動恢復策略

**解法草稿**:用 hermes-agent 官方 docker image 跑在 1-vCPU VPS,token 走 env var。

---

## B. 結構性缺口(pre-v2 — 實作可開始,但 v2 前要補)

這些不擋第一個 PR 跑起來,但 v2 之前要釘下。

### B1. Token budget 控制平面

**狀態**:`pre-v2`(明示 deferred)
**來源**:ADR-0012 "control plane; not yet ADR'd";ADR-0014 "lands here naturally"
**待決**:
- 寫成新 ADR(ADR-0019 候選):per-WorkPackage token budget,Dispatch enforce,Supervision 觀察 + 告警
- 預算數字(初始假設值)
- 超過時動作:強制終止 Worker / 升 human-help

**為什麼重要**:現在 runaway protection 完全沒有,LLM 失控就無限燒 token。

### B2. WorkPackage `depends_on` schema + Dispatch 排程邏輯

**狀態**:`pre-v2`
**來源**:ADR-0014 "audit hole";Fresh-eye round 1 #B10 + round 2 + round 3
**待決**:
- WorkPackage body 加 `depends_on: [<WP issue numbers>]` 欄位
- Dispatch:選下一個 WP 時跳過 `depends_on` 包含未 `status:delivered` 的 WP
- 級聯處理:被 depend 的 WP 如果 cancel,下游怎麼辦(cancel / pause / 重設計)

**為什麼重要**:同一個 Spec 拆成多個 WP 時的執行順序目前是運氣。

### B3. Stage 1 / Stage 3 retry 行為

**狀態**:`pre-v2`
**來源**:Fresh-eye round 4 #B
**待決**:
- Stage 1(lint/typecheck/unit):失敗算誰?retry budget 算在哪一桶?
- Stage 3(sandbox deploy):infra 問題不該算 Worker 帳;失敗時直接升 `supervision-alert`?retry 還是 fail-fast?

**解法草稿**:Stage 1 失敗 → 算 Worker iteration 內的問題,Worker 自修(不消耗 retry budget,但有總時間上限);Stage 3 失敗 → infra alert,人類接手,不自動 retry。

### B4. `agent:validator` 細分

**狀態**:`pre-v2`(目前隱式運作,但讀者困惑)
**來源**:Fresh-eye round 4 #8
**待決**:
- 拆成 `agent:validator:white-box` / `agent:validator:black-box`?
- 還是維持單一 label + Dispatch in-cycle state 知道自己在哪一階段?
- 如果是後者,要在 Delivery CONTEXT 明寫「label 不是完整狀態,Dispatch 還有 in-cycle 推進指標」

**解法草稿**:保留單一 label(語意是「驗證階段中」),在 Delivery CONTEXT 加註說明 Dispatch 內部知道 stage。

### B5. 手動開 Issue → Signal 流程

**狀態**:`pre-v2`
**來源**:Fresh-eye round 4 #4
**待決**:
- 人類在 GitHub UI 直接開 Issue 沒 `type:*` label 時,誰幫它打 `type:signal`?
- Hermes 的某個 cron skill 掃所有沒 `type:*` 的 Issue?還是要求人開 Issue 時自填 label?

**解法草稿**:Hermes 內建 cron skill `scan-untagged-issues`,5 min 跑一次,把沒 `type:` 的 Issue 視為 candidate signal,Hermes invocation 讀 body 決定要不要打 `type:signal` 並開始 BusinessModelProbe(在 Issue comments 中,或在 Discord 開新 thread)。

### B6. Hermes daemon down 時 Discord 訊息保證

**狀態**:`pre-v2`
**來源**:Fresh-eye round 4 #6
**待決**:
- daemon down 時 Discord 訊息會落地嗎?(Discord 是否會 buffer 訊息直到 bot 上線)
- 上線後第一輪 cron 是否要掃過去 N 小時的訊息補處理?
- 如何偵測 daemon down 並警告?

**解法草稿**:hermes-agent 應該有自動重連;新 Hermes invocation 啟動時掃最近 thread 找未回應的訊息。具體要看 hermes-agent runtime 規格。

### B7. `select-deployment-strategy` skill 跟其他 design skills 的執行順序

**狀態**:`pre-v2`(運作邏輯,不影響 contract)
**來源**:Fresh-eye round 4 #11
**待決**:
- Hermes 對一個 Spec 跑 design phase 時,skills 怎麼選擇順序?
- 通常順序:`select-deployment-strategy` → `decompose-spec` → `compute-impact-scope` → `draft-adr`(必要時)→ `commit-workpackage`
- 或讓 Hermes 自己挑(prompt 引導)?

**解法草稿**:用 Hermes 的 design-orchestrator meta-skill 統一管理 design phase 的 sub-skill 順序。

---

## C. v2 能力(新功能,完全不擋 v1)

### C1. Hermes proposal 機制

**狀態**:`v2-feature`(ADR-0008 明示)
**來源**:ADR-0008 governance 段
**內容**:Hermes 觀察到重複 pattern(例如連續多次某類型的 supersede-fact)時,在 Discord 主動提案新 skill;人類審核 + 寫 code + merge 才生效(autonomy 仍限制在「提案」)。

### C2. Vector search for RLM

**狀態**:`v2-feature`
**來源**:ADR-0004
**內容**:當 RLM 文件量超過 grep 友善範圍時,加 embedding-based retrieval 作為 query view。primary store 不變(markdown + git)。

### C3. v2 alert detectors(Supervision)

**狀態**:`v2-feature`(ADR-0012 明示)
**來源**:ADR-0012
**內容**:三個 v2 alert 類型 ——
- triple-homogeneity loops(同一 reasoning 連發 N 次 → agent 卡住)
- cross-agent semantic disagreement(Validator 通過,Worker 自評懷疑;或不同 stage 結論衝突)
- LLM-judged basis relevance(不只機械驗證 basis 存在,還用另一個 LLM 評估 basis 是否真的支持 reasoning)

### C4. Additional Worker skill profiles

**狀態**:`v2-feature`(ADR-0003 明示)
**來源**:ADR-0003
**內容**:UE5、Unity、Blender、dedicated DB migration specialist、其他領域。每個是新增 skill profile,不是新增 Worker agent class。需要對應 stage 3 sandbox deploy 的差異(UE5 build 30 min 等)。

### C5. v2 → v3 自動化 gate 移除

**狀態**:`v2-feature`(ADR-0005 明示)
**來源**:ADR-0005
**內容**:當某類任務累積足夠歷史證明 agent 零錯誤率,可以考慮移除對應的 human gate。需要先建立歷史資料統計機制。

---

## D. 細節 polish(nice-to-have,不擋實作)

### D1. Deployment 決策→實作路徑 cross-references

**來源**:Fresh-eye round 3 #K
**內容**:Hermes 的 `select-deployment-strategy` skill 跟 Worker 的 deployment-as-code skill 之間應該有明確 cross-reference 在 Design CONTEXT.md 或 ADR-0003。

### D2. Hermes design-domain code-read at scale

**來源**:Fresh-eye round 3 #J
**內容**:design-domain skills 要讀 code 算 ImpactScope。大 repo 怎麼處理?分模組 scan?cached AST?延遲到 v2 vector search 一起。

### D3. flow-visualization 維護

**內容**:架構繼續演進時,`docs/flow-visualization.html` 要對應更新。或寫成自動從 ADR 抽資料的生成腳本(維護成本太高,可能不值得)。

---

## 不在這份檔案的東西(以免越界)

以下事項已經*在 ADR / CONTEXT 中明確解決*,不算 TODO:

- Architect 是否存在 → 不存在(ADR-0008 明示)
- Hermes 跨 BC 還是 Intake-only → 跨 BC(ADR-0008)
- Dispatch 是 daemon 還是 script → script(ADR-0014 Runtime model)
- Supervision 是 agent 還是 infra → 是 LLM agent,但只輸出 alert(ADR-0012 Runtime model)
- Worker 是 generic 還是 specialist → generic + skill profile(ADR-0016)
- 對話先在 Discord 還是先建 Issue → 先 Discord,共識後才 Issue(flow-visualization v2)

---

## 進度追蹤

| 區塊 | 條目數 | 已動工 |
|---|---|---|
| A. 實作前置(pre-v1) | 6 | 5(A1 contract + scaffold,A3 100% 12/12 skill,A4 / A5 / A6 已定) |
| B. 結構缺口(pre-v2) | 7 | 0 |
| C. v2 能力 | 5 | 0 |
| D. polish | 3 | 0 |

當 A 區段全部訂下,可以開始寫第一行 `rlm` CLI。

### 已定決策(2026-05-12)

- **A1 `rlm` CLI 選型**:Python(uv 管 venv + deps)。**部署位置:`tools/rlm/`**(隨 repo 演進)。安裝方式:`uv pip install -e tools/rlm`。Single source of truth = 此 ADR-0004 表 + CLI 內 docstrings。
- **A4 Supervision event log backend**:**Redis(熱資料) + JSONL append-only file(durable archive)**。每個 event 同時寫 Redis stream(供 Arbiter / Supervision 快讀)和 `.local/events.jsonl`(供 audit / replay)。Schema 遵 ADR-0012 event spec。
- **A5 Global Worker lock**:**Redis key + TTL**(`SETNX rlm:worker:lock <dispatch_id>` + `EXPIRE`)。TTL 待 Worker iteration 上限定下後決定(估 30 min)。
- **A6 Discord bot 部署**:已部署(user-managed,跑 hermes-agent daemon),不擋 v1 開發。
- **未定**:A2 CI fact-commit check 細節(check name 暫定 `rlm/fact-commit-required`,定義在 `.rlm/contracts/rlm-cli.md` open questions 第 4 項)。
- **A1 rlm CLI 規格已釘 + scaffold 已建**:
  - **契約**:`.rlm/contracts/rlm-cli.md`(1126 行)—— 鎖定 17 個 subcommand 的 invocation surface、frontmatter / Issue body schemas、caller-identity 機制(`RLM_AGENT_ROLE` env var)、triple emission(Redis stream + JSONL dual-sink)、error model(8 個 stable exit codes)、idempotency keys。
  - **scaffold**:`tools/rlm/`(2749 行 / 45 檔,uv-managed Python)。foundation 完整可跑:errors / discover / identity / frontmatter / triples / idempotency / adapters(gh, git, redis_log)/ routing(pr, commit, issue)/ cli。17 subcommand 已註冊到 Click(`rlm --help` 看得到全部),body 是 `NotImplementedError` 指向契約對應 section。35 個 pytest 全綠 + ruff clean。
  - **剩**:17 個 subcommand 的 body 實作 + 整合 test(需要 gh/redis 環境的 e2e)。
- **A3 已寫**(`.claude/skills/<name>/SKILL.md`,Claude Agent SDK 格式):

  **Intake (4)** — 改編自 gstack/office-hours
  - `business-model-probe`(358 行)— 6 forcing questions + anti-sycophancy + pushback patterns,適配 Discord stateless 流 + 雙模式(new-product / existing-product Signal)
  - `deployment-constraints-probe`(176 行)— 5 dim 封閉題 + 過去 snapshot re-use 啟發
  - `production-monitor`(187 行)— cron poll providers + threshold crossing → Signal Issue + Discord 通知
  - `signal-to-spec`(292 行)— 兩階段(draft+propose,然後 yes 後 commit + 串 `intake-confirmation`)

  **Design (5)** — 改編自 [mattpocock/skills/engineering](https://github.com/mattpocock/skills/tree/main/skills/engineering)
  - `compute-impact-scope`(276 行)— Module/Seam/Adapter 詞彙、deletion test、one-vs-two-adapter heuristic;產 `impact_scope` YAML field
  - `decompose-spec`(264 行)— tracer-bullet vertical slices、AFK/HITL、quiz before approve、dependency-order publish;Hermes 最重的 design skill
  - `select-deployment-strategy`(191 行)— ≥3 候選 + 強制 trade-off matrix + 「what would change my mind」+ 串 `draft-adr`
  - `draft-adr`(273 行)— 三條件 gate(hard-to-reverse + surprising + real trade-off)+ 拒絕邏輯 + 用 `rlm propose-adr` PR-routed
  - `draft-contract`(319 行)— API/event/schema/integration 四型契約,frontmatter + invariants + 版本策略

  **Cross-domain (3)** — 從 ADR-0005 / ADR-0008 / ADR-0013 推
  - `intake-confirmation`(208 行)— 第一個 human gate:接 Spec proposal 的 yes/edit/no/timeout,串 `rlm append-business-model` + `commit-spec` + `confirm-spec` 或回 `signal-to-spec` 重 draft;含 5-min warning 機制
  - `design-approval`(268 行)— 最關鍵 gate:parse `approve N / hold N / approve all / discuss`,topological 順序 call `rlm approve-workpackage`,cascade-block 處理(ADR 未 merged 連帶下游)+ 5-min warning
  - `design-dialogue`(226 行)— Posting protocol:design-domain skill 中段問人類時用,gstack `/plan-ceo-review` 風 decision brief(recommendation + change-my-mind + 30-min auto-decide);fire-and-forget,caller skill 自己 stateless resume

### 結構性改動(2026-05-12)

- 所有 RLM 知識文件搬進 **`.rlm/`** 根目錄(取代原本 `docs/`),原因:跟未來 Worker 寫的 `src/` app code 分得乾淨。`.rlm/` 是 CLI 的 canonical root。
- ADR-0004 的目錄圖已對應更新。所有 cross-reference 更新到新路徑。
