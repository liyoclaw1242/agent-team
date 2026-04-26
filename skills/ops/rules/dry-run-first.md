# Rule — Dry-Run First

Every production-affecting change is dry-run before apply. The dry-run output is captured into the issue body via `actions/plan-change.sh`. Reviewers can see what the change will do before approving the merge.

## Why this rule

Production changes have two failure modes:

1. **Apply fails partway** — half-applied state, often worse than original
2. **Apply succeeds but does something unexpected** — the change technically applied but had effects you didn't anticipate

Dry-run catches the first; reviewers reading the dry-run output catch the second. Skipping dry-run gambles on both.

## What "dry-run" looks like per platform

### Terraform / OpenTofu

```bash
terraform plan -out=plan.tfplan -no-color > /tmp/plan-$ISSUE.txt
```

Output shows: `Plan: N to add, M to change, K to destroy`. Reviewers care about the destroy count and any change to security-relevant resources (IAM, networking).

### Kubernetes

```bash
# Server-side dry-run is the strict version (validates against cluster state)
kubectl apply --dry-run=server -f manifests/ > /tmp/k8s-dryrun-$ISSUE.txt
# Or client-side for syntax-only:
kubectl apply --dry-run=client -f manifests/
```

Use server-side for production changes — it catches admission-controller rejections, namespace mismatches, RBAC issues that client-side misses.

### Cloud Run / GCP services

```bash
gcloud run services replace service.yaml --validate-only > /tmp/cloudrun-dryrun-$ISSUE.txt
```

Validates the YAML against the API; doesn't deploy.

### Cloudflare Workers

```bash
wrangler deploy --dry-run --outdir dist > /tmp/wrangler-dryrun-$ISSUE.txt
```

Builds the bundle locally; doesn't deploy. Catches build-time issues.

### Vercel

```bash
vercel build > /tmp/vercel-build-$ISSUE.txt
# Or for the full pre-deploy check:
vercel deploy --prebuilt --dry-run-strict
```

Note: Vercel doesn't have a clean "dry-run" mode for arbitrary changes; `vercel build` validates the build artefact. For most config changes, the `vercel.json` shape is what matters; lint via `vercel json validate` if available.

### Helm

```bash
helm install --dry-run --debug myrelease ./chart > /tmp/helm-dryrun-$ISSUE.txt
# Or for upgrades:
helm upgrade --dry-run --debug myrelease ./chart
```

### Custom deploy scripts

If the deploy is via a custom script (`./deploy.sh`), the script should support a `--dry-run` flag. If it doesn't, that's a script-improvement task — flag it but proceed with manual review of what the script will do.

## What goes in the issue body

`actions/plan-change.sh` reads the dry-run output and embeds a summary in the issue body, between markers:

```markdown
<!-- ops-plan-begin -->
## Plan summary

**Tool**: terraform plan (output at /tmp/plan-issue-150.txt)

**Changes**:
- Add: 0 resources
- Change: 1 resource (kubernetes_deployment.cancel_svc — replicas 1 → 3)
- Destroy: 0 resources

**Security-relevant changes**: none

**Full plan output**:
```
[truncated; full output in PR description]
```
<!-- ops-plan-end -->
```

Reviewers see the plan summary on the issue. Full output goes to the PR description.

## When dry-run isn't possible

Some changes inherently can't be dry-run:

- **DNS changes**: there's no preview; the change is live
- **Object creation in some platforms**: e.g., creating a GCP project
- **Operations against external services with no test mode**

For these, the discipline shifts to:

1. **Stronger reviewer scrutiny** — at least one other person reviews before apply
2. **Smaller blast radius** — make the smallest possible change first
3. **Test mode where possible** — many platforms have test/sandbox modes; use them
4. **Explicit acknowledgement** — the PR description states "this change cannot be dry-run; risk acknowledged: ..."

Do not skip dry-run for "simple" changes — every change you think is simple has surprised someone before.

## When dry-run shows unexpected changes

The plan shows changes you didn't intend (state drift, dependency updates, autocompute fields):

- **Stop, don't apply**
- **Investigate why the unexpected change appears** — usually one of:
  - State drift (manual changes to cloud state not reflected in IaC)
  - Provider version updated and changed defaults
  - Dependent resource changed shape and triggered downstream updates
- **Decide**: include the unexpected change deliberately (with mention in PR), or fix the IaC to not include it

Never ship a PR whose plan output you don't fully understand.

## Validation

`validate/manifest-dryrun.sh` runs an appropriate dry-run for the detected stack and exits non-zero if it fails. This goes through `validate/check-all.sh` aggregator, so the implement deliver gate fails if dry-run fails.

## Anti-patterns

- **"It's a small change, dry-run is overkill"** — never. Always.
- **Capturing dry-run output but not reading it** — dry-run that's not reviewed is theatre. Read it; understand every line.
- **Dry-running against a different environment than where you'll apply** — terraform plan against dev with intent to apply against prod misleads. Dry-run against the actual target environment.
- **Skipping plan-change.sh** — the embed in issue body is what reviewers see. Without it, reviewers have to chase down the plan output themselves.
