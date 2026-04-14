# Case: Vercel Preview vs Production 環境管理

## 環境模型

Vercel 每個專案有三種部署：

| 環境 | 觸發條件 | URL 格式 | 用途 |
|------|---------|----------|------|
| **Preview** | PR 開啟/push | `{branch}-{project}.vercel.app` | QA 測試、Design 視覺審查 |
| **Production** | push to main (或手動) | `{custom-domain}` 或 `{project}.vercel.app` | 正式上線 |
| **Development** | `vercel dev` (本地) | `localhost:3000` | FE/BE 本地開發 |

## Preview 自動部署

Vercel GitHub Integration 預設行為：
- PR 開啟 → 自動部署 Preview
- PR 有新 push → 重新部署（覆蓋同 branch 的 Preview）
- PR 合併/關閉 → Preview 保留但不再更新（會自動過期）
- push to main → 自動部署 Production

**不需要額外 CI 步驟**，Vercel GitHub App 自動處理。但需要確認：

```bash
# 確認 GitHub Integration 已連接
# Vercel Dashboard → Project → Settings → Git → Connected Git Repository
```

## Preview URL 發現

Vercel bot 會自動在 PR 留言，格式：

```
Visit Preview: https://{project}-{hash}-{team}.vercel.app
```

QA/CI 取得 URL 的方式：

```bash
# 方法 1: 從 PR comment 抓（最可靠）
gh pr view {N} --repo {SLUG} --json comments \
  --jq '[.comments[].body] | map(select(test("vercel\\.app"))) | last' \
  | grep -oE 'https://[a-zA-Z0-9._-]+\.vercel\.app'

# 方法 2: 從 GitHub Deployments API 抓
gh api repos/{OWNER}/{REPO}/deployments \
  --jq '[.[] | select(.environment == "Preview")] | first | .statuses_url' \
  | xargs gh api --jq '.[] | select(.state == "success") | .target_url'

# 方法 3: Vercel CLI
vercel ls --scope {team} | grep {branch-name}
```

## 環境變數管理

Vercel 環境變數分三個 scope：

```bash
# 查看目前設定
vercel env ls

# 加環境變數（指定 scope）
vercel env add DATABASE_URL preview          # 只用在 Preview
vercel env add DATABASE_URL production       # 只用在 Production
vercel env add NEXT_PUBLIC_APP_URL preview   # Preview 用的公開變數
```

### 典型配置

| 變數 | Preview | Production | 說明 |
|------|---------|------------|------|
| `DATABASE_URL` | test/staging DB | production DB | **絕對不能共用** |
| `NEXT_PUBLIC_API_URL` | Preview API URL | Production API URL | 前端 API base |
| `NEXTAUTH_URL` | Preview URL | Production URL | Auth callback |
| `NEXTAUTH_SECRET` | 可以共用 | 同左 | 加密用 |
| `SEED_DATA` | `true` | **不設定** | Preview 自動灌測試資料 |

### Monorepo 注意事項

每個 app 是一個 Vercel 專案，環境變數各自獨立：

```
repo/
  apps/
    web/    → Vercel Project: "my-app-web"     (有自己的 env vars)
    api/    → Vercel Project: "my-app-api"     (有自己的 env vars)
    admin/  → Vercel Project: "my-app-admin"   (有自己的 env vars)
```

## Preview 的資料隔離

Preview 環境必須使用獨立的測試資料庫，不能連 production DB。

### 方案 A: 獨立 DB instance（推薦）

```
Production → Neon/PlanetScale main branch
Preview    → Neon/PlanetScale dev branch（或獨立 instance）
```

Neon 支援 database branching，每個 Preview 可以有自己的 DB branch。

### 方案 B: 同 instance 不同 schema/database

```
Production → myapp_production
Preview    → myapp_preview（定期重建）
```

### 方案 C: SQLite（小專案）

Preview 用 SQLite + seed data，Production 用 PostgreSQL。
適合 MVP 階段，不適合需要驗證 DB 行為一致性的場景。

## Preview 與 Production 的差異控制

原則：**Preview 和 Production 用同一份 code、同一個 build，只差環境變數。**

不要做的事：
```typescript
// ✗ 不要在 code 裡判斷環境來改行為
if (process.env.VERCEL_ENV === 'preview') {
  // skip auth check...  ← 這會讓 Preview 測不到 auth bug
}
```

可以做的事：
```typescript
// ✓ 用環境變數控制外部服務的連接
const dbUrl = process.env.DATABASE_URL;  // Preview 和 Prod 各自設不同值
const apiBase = process.env.NEXT_PUBLIC_API_URL;
```

## CI 中跑 E2E（搭配 Preview）

Vercel 部署完成後觸發 E2E：

```yaml
# .github/workflows/e2e.yml
name: E2E Tests
on:
  deployment_status:

jobs:
  e2e:
    if: github.event.deployment_status.state == 'success' && github.event.deployment_status.environment == 'Preview'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
      - run: pnpm install
      - run: npx playwright install chromium
      - run: pnpm exec playwright test
        env:
          PREVIEW_URL: ${{ github.event.deployment_status.target_url }}
```

關鍵：用 `deployment_status` event，不是 `pull_request`。這樣確保 Vercel 部署完成後才跑測試。

## 常見問題

### Preview 部署失敗但 Production 正常

見 `cases/vercel-monorepo-deploy.md` — 通常是 `vercel link` 到錯誤專案。

### Preview URL 在 PR comment 找不到

1. 檢查 Vercel GitHub App 是否已安裝：Settings → Integrations
2. 檢查 repo 是否有 `vercel.json` 設了 `github.silent: true`（會關閉 PR 留言）
3. 手動用 `vercel ls` 查找部署 URL

### 環境變數更新後 Preview 沒反映

Vercel 環境變數更新後需要重新部署：
```bash
# 觸發重新部署
vercel --force
# 或在 PR 推一個空 commit
git commit --allow-empty -m "chore: trigger redeploy" && git push
```

### Preview 的 API 打到 Production DB

**這是 P0 事故。** 立即檢查：
```bash
vercel env ls | grep DATABASE_URL
```
確認 Preview scope 的 `DATABASE_URL` 指向測試 DB，不是 production。
