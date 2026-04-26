# Case — CI Pipeline Design

Designing or modifying a CI/CD pipeline. The default CI tool here is GitHub Actions; the patterns translate to GitLab CI / CircleCI / Buildkite with syntactic adjustments.

This case shows ONE full worked example in detail, then notes how to adjust for different stack shapes.

## Worked example: standard service CI

A typical service repo: BE in Go, FE in TypeScript, deployed via Docker images to a target platform. The pipeline has these stages:

```
pull_request:           push to feature branch
  ├─ lint                runs on every PR
  ├─ typecheck (if TS)
  ├─ test (with coverage)
  ├─ security scan
  └─ build image (no push) — sanity check the Dockerfile

push to main:           merge to main
  ├─ all of the above
  ├─ build + push image to registry (tagged with commit SHA + 'latest')
  ├─ deploy to staging   automatic
  └─ run e2e tests       against staging

manual:                 explicit deploy to prod
  ├─ guarded by environment review
  ├─ deploy to prod
  └─ post-deploy smoke tests
```

### Full workflow file

`.github/workflows/ci.yml`:

```yaml
name: CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

# Cancel old runs when new commits are pushed to the same PR
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true

env:
  GO_VERSION: '1.22'
  NODE_VERSION: '20'

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      - name: go vet
        run: go vet ./...
      - name: staticcheck
        run: |
          go install honnef.co/go/tools/cmd/staticcheck@latest
          staticcheck ./...
      - name: gofumpt
        run: |
          go install mvdan.cc/gofumpt@latest
          test -z "$(gofumpt -l .)"

  typecheck:
    runs-on: ubuntu-latest
    if: hashFiles('package.json') != ''
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - run: npm run typecheck

  test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_PASSWORD: test
          POSTGRES_DB: test
        ports: ['5432:5432']
        options: >-
          --health-cmd "pg_isready -U postgres"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
          cache: true
      - name: Run tests with race detector + coverage
        env:
          DATABASE_URL: postgres://postgres:test@localhost:5432/test?sslmode=disable
        run: go test -race -coverprofile=coverage.out -covermode=atomic ./...
      - name: Coverage threshold
        run: |
          coverage=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
          threshold=80
          echo "coverage: ${coverage}%"
          if (( $(echo "$coverage < $threshold" | bc -l) )); then
            echo "::error::coverage ${coverage}% below threshold ${threshold}%"
            exit 1
          fi
      - uses: actions/upload-artifact@v4
        with:
          name: coverage
          path: coverage.out

  security:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
      - name: Trivy filesystem scan
        uses: aquasecurity/trivy-action@master
        with:
          scan-type: 'fs'
          scan-ref: '.'
          severity: 'HIGH,CRITICAL'
          exit-code: '1'
      - uses: actions/setup-go@v5
        with:
          go-version: ${{ env.GO_VERSION }}
      - name: govulncheck
        run: |
          go install golang.org/x/vuln/cmd/govulncheck@latest
          govulncheck ./...

  build-image:
    needs: [lint, test, security]
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write
      id-token: write
    steps:
      - uses: actions/checkout@v4
      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3
      # Only login + push on main; PRs build but don't push
      - name: Login to registry
        if: github.event_name == 'push'
        uses: docker/login-action@v3
        with:
          registry: gcr.io
          username: _json_key
          password: ${{ secrets.GCP_SA_KEY }}
      - name: Build and (conditionally) push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: ${{ github.event_name == 'push' }}
          tags: |
            gcr.io/${{ secrets.GCP_PROJECT }}/cancel-svc:${{ github.sha }}
            ${{ github.event_name == 'push' && format('gcr.io/{0}/cancel-svc:latest', secrets.GCP_PROJECT) || '' }}
          cache-from: type=gha
          cache-to: type=gha,mode=max

  deploy-staging:
    needs: build-image
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    environment: staging
    steps:
      - uses: actions/checkout@v4
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      - uses: google-github-actions/setup-gcloud@v2
      - name: Deploy to staging Cloud Run
        run: |
          gcloud run deploy cancel-svc \
            --image gcr.io/${{ secrets.GCP_PROJECT }}/cancel-svc:${{ github.sha }} \
            --region us-central1 \
            --project ${{ secrets.GCP_PROJECT_STAGING }} \
            --no-traffic
          gcloud run services update-traffic cancel-svc \
            --region us-central1 \
            --project ${{ secrets.GCP_PROJECT_STAGING }} \
            --to-latest
      - name: Smoke test
        run: |
          for i in {1..10}; do
            if curl -fsS https://cancel-svc-staging.example.com/health; then
              echo "smoke test passed"
              exit 0
            fi
            sleep 5
          done
          echo "::error::smoke test failed after 10 attempts"
          exit 1

  e2e:
    needs: deploy-staging
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: ${{ env.NODE_VERSION }}
          cache: 'npm'
      - run: npm ci
      - name: Run e2e against staging
        env:
          E2E_BASE_URL: https://cancel-svc-staging.example.com
        run: npm run test:e2e
```

### Companion: prod deploy workflow

`.github/workflows/deploy-prod.yml`:

```yaml
name: Deploy to Production

on:
  workflow_dispatch:
    inputs:
      sha:
        description: 'Commit SHA to deploy (must be on main, must have passed CI)'
        required: true

jobs:
  deploy-prod:
    runs-on: ubuntu-latest
    environment: production  # requires manual approval per environment policy
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ inputs.sha }}
      - name: Verify SHA is on main
        run: |
          git fetch origin main
          if ! git merge-base --is-ancestor ${{ inputs.sha }} origin/main; then
            echo "::error::SHA is not an ancestor of main"
            exit 1
          fi
      - uses: google-github-actions/auth@v2
        with:
          credentials_json: ${{ secrets.GCP_SA_KEY }}
      - uses: google-github-actions/setup-gcloud@v2
      - name: Deploy to prod Cloud Run
        run: |
          gcloud run deploy cancel-svc \
            --image gcr.io/${{ secrets.GCP_PROJECT }}/cancel-svc:${{ inputs.sha }} \
            --region us-central1 \
            --project ${{ secrets.GCP_PROJECT_PROD }} \
            --no-traffic
          # Gradual rollout: 10% -> wait -> 50% -> wait -> 100%
          for split in 10 50 100; do
            gcloud run services update-traffic cancel-svc \
              --region us-central1 \
              --project ${{ secrets.GCP_PROJECT_PROD }} \
              --to-revisions=LATEST=$split
            echo "traffic at ${split}%; observing..."
            sleep 60
            # Could check error rate here and abort if elevated
          done
      - name: Tag release
        run: |
          git tag -a "deploy/$(date +%Y%m%d-%H%M%S)" ${{ inputs.sha }} \
            -m "Deployed to production"
          git push origin --tags
```

## What to look for in this example

### Concurrency control

```yaml
concurrency:
  group: ci-${{ github.ref }}
  cancel-in-progress: true
```

Cancels old runs when new commits are pushed to the same branch. Saves CI minutes; gives faster feedback. Don't use this for deploy workflows (cancelling mid-deploy = bad).

### Caching

`actions/setup-go` and `actions/setup-node` with `cache: true` / `cache: 'npm'` automatically cache dependencies. Without caching, every PR run downloads everything; with caching, subsequent runs are minutes faster.

### Conditional steps

```yaml
- name: Login to registry
  if: github.event_name == 'push'
```

PRs run lint/test but don't push images (no point — they're throwaway). Only `push to main` pushes. Saves money + speed.

### Permissions

```yaml
permissions:
  contents: read
  packages: write
  id-token: write
```

Default GitHub Actions tokens have broad permissions; explicitly narrow them per job. Principle of least privilege at the CI layer.

### Coverage threshold

```yaml
- name: Coverage threshold
  run: |
    coverage=$(go tool cover -func=coverage.out | grep total | awk '{print $3}' | sed 's/%//')
    threshold=80
    if (( $(echo "$coverage < $threshold" | bc -l) )); then
      echo "::error::coverage ${coverage}% below threshold ${threshold}%"
      exit 1
    fi
```

Mechanically enforces the BE coverage rule from `be/rules/tdd-iron-law.md`. CI enforces what the agent committed to.

### Smoke test after deploy

```yaml
- name: Smoke test
  run: |
    for i in {1..10}; do
      if curl -fsS https://cancel-svc-staging.example.com/health; then ...
```

Loop with retries handles brief unavailability during rollout. Max 50s of retries; if it doesn't come up by then, the deploy is broken.

### Gradual rollout

The prod workflow rolls out at 10% → 50% → 100% with sleep between. Each stage gives time to observe before going further. In real-world tooling, replace `sleep 60` with metric-driven gates ("if error rate is normal, advance").

### Environment protection

```yaml
environment: production
```

The GitHub `production` environment is configured (in repo settings) to require manual approval. This is the manual gate before prod deploys.

## Variants for different stacks

### Variant: monorepo with multiple services

Use a path-filtered matrix:

```yaml
jobs:
  detect-changes:
    runs-on: ubuntu-latest
    outputs:
      services: ${{ steps.detect.outputs.services }}
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - id: detect
        run: |
          changed_services=$(git diff --name-only origin/main...HEAD \
            | grep -oP '^services/\K[^/]+' | sort -u | jq -Rcn '[inputs]')
          echo "services=${changed_services}" >> $GITHUB_OUTPUT

  test:
    needs: detect-changes
    if: needs.detect-changes.outputs.services != '[]'
    strategy:
      matrix:
        service: ${{ fromJson(needs.detect-changes.outputs.services) }}
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: cd services/${{ matrix.service }} && go test -race ./...
```

Only test services that changed. Faster CI on monorepos.

### Variant: pure FE / static site

Replace test/build phases:

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm ci
      - run: npm run lint
      - run: npm run typecheck
      - run: npm test
      - run: npm run build  # produces dist/
      - uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/

  deploy-vercel-preview:
    needs: test
    if: github.event_name == 'pull_request'
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
      - run: npm install --global vercel@latest
      - run: vercel pull --yes --environment=preview --token=${{ secrets.VERCEL_TOKEN }}
      - run: vercel build --token=${{ secrets.VERCEL_TOKEN }}
      - id: deploy
        run: |
          url=$(vercel deploy --prebuilt --token=${{ secrets.VERCEL_TOKEN }})
          echo "url=$url" >> $GITHUB_OUTPUT
      - uses: peter-evans/create-or-update-comment@v3
        with:
          issue-number: ${{ github.event.pull_request.number }}
          body: "🚀 Preview: ${{ steps.deploy.outputs.url }}"
```

PR previews are a Vercel signature feature; lean on it.

### Variant: Cloudflare Workers

Replace the deploy job:

```yaml
deploy-staging:
  needs: build
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: actions/setup-node@v4
    - run: npm ci
    - name: Deploy to Cloudflare staging
      uses: cloudflare/wrangler-action@v3
      with:
        apiToken: ${{ secrets.CLOUDFLARE_API_TOKEN }}
        environment: staging
```

Wrangler handles deployment; minimal CI complexity.

### Variant: K8s deploy via ArgoCD

If using GitOps, CI doesn't directly deploy — it commits image tag updates to a GitOps repo:

```yaml
deploy-staging:
  needs: build-image
  if: github.event_name == 'push' && github.ref == 'refs/heads/main'
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
      with:
        repository: org/gitops-staging
        token: ${{ secrets.GITOPS_TOKEN }}
        path: gitops
    - name: Update image tag in gitops
      run: |
        cd gitops
        sed -i "s|image: gcr.io/.*/cancel-svc:.*|image: gcr.io/proj/cancel-svc:${{ github.sha }}|" \
          apps/cancel-svc/deployment.yaml
        git config user.name "ci-bot"
        git config user.email "ci@example.com"
        git add . && git commit -m "deploy: cancel-svc to ${{ github.sha }}"
        git push
```

ArgoCD watches the GitOps repo and applies the change. CI's job ends at the commit.

## Anti-patterns

- **One mega-workflow** — split lint/test/deploy into clear jobs; failure of one shouldn't block visibility into others
- **Secrets in workflow files** (even repo secrets used loosely) — use environment-scoped secrets where possible; least access
- **No concurrency controls** — wastes CI minutes; old runs continue past their relevance
- **Missing smoke test after deploy** — deploys can succeed at the platform level but not actually serve traffic; verify health
- **No manual gate for prod** — prod auto-deploy from main is a footgun; use environment protection
- **CI green = production-ready** — CI is necessary, not sufficient; observation post-deploy still matters
- **Monorepo with naive matrix that runs everything every time** — wastes CI, causes flake amplification; use path filters
