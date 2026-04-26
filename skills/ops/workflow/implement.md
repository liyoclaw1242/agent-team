# Workflow — Implement (IaC / config / pipeline change)

The standard OPS task: change something in infra. Differs from fe/be `implement.md` mainly in the dry-run discipline and the rollback documentation.

## Phase 1 — Read

Required:

1. The issue body in full
2. Parent issue body (`<!-- parent: #N -->`)
3. Sibling tasks if cross-role coordination needed (e.g., a BE task that requires this OPS work)
4. Relevant `arch-ddd/service-chain.mermaid` — if changing service topology
5. Existing IaC for the affected resources — read it before changing

Conditional:

6. Recent OPS PRs touching the same area (drift between code and reality is common in OPS — `git log` recent commits)
7. Active incidents / alerts that might overlap your change
8. Platform documentation if working with a service you haven't used recently — these change

## Phase 2 — Reality check

Before writing IaC, verify:

- Does the resource the spec refers to actually exist in the named state? `kubectl get`, `gcloud describe`, `wrangler tail` etc.
- Are there in-flight changes from other PRs that would conflict?
- Does the codebase's IaC match production reality? (Drift between Terraform and actual cloud state is the most common OPS hazard.)

If reality differs from what the spec assumes, switch to `workflow/feedback.md`. Don't write IaC against an assumption that's wrong.

## Phase 3 — Write the change

Standard order:

1. **Smallest change that satisfies the spec**. Don't refactor adjacent IaC unless the AC require it.
2. **Additive when possible**. Add new resources/configs/policies; don't remove or rename existing unless explicitly required.
3. **One commit per coherent unit**. Per `_shared/rules/git.md` commit format. `chore(ops): ...` or `feat(infra): ...` typical.

For destructive changes (delete resources, tighten IAM, change DNS), see `rules/reversibility.md` for the multi-step pattern.

## Phase 4 — Dry-run + capture

Before opening a PR, capture dry-run output for every production-affecting change:

```bash
# Examples:
terraform plan -out=plan.tfplan -no-color > /tmp/plan-issue-{N}.txt
kubectl apply --dry-run=server -f manifests/ > /tmp/k8s-dryrun-issue-{N}.txt
gcloud run deploy mysvc --no-traffic --source . --dry-run > /tmp/cloudrun-dryrun-issue-{N}.txt
wrangler deploy --dry-run > /tmp/wrangler-dryrun-issue-{N}.txt
```

The dry-run output is your evidence that the change applies cleanly. If dry-run errors, **fix before continuing** — don't open a PR with a known-broken plan.

`actions/plan-change.sh` takes a dry-run output file and embeds a summary into the issue's body, between markers, so reviewers see what the change will do:

```bash
bash actions/plan-change.sh \
  --issue $ISSUE_N \
  --dry-run-file /tmp/plan-issue-$ISSUE_N.txt
```

This goes between `<!-- ops-plan-begin -->` and `<!-- ops-plan-end -->`.

## Phase 5 — Document rollback

Every PR includes a rollback runbook. For most changes, this is straightforward:

```markdown
## Rollback

If this change misbehaves after apply:

1. Revert this PR (`git revert <sha>` and re-merge)
2. Re-apply: `terraform apply` (or platform-specific re-apply command)
3. Verify: `kubectl get pods -l app=cancel-svc` shows previous version healthy
4. Estimated rollback time: 2–3 minutes
```

For destructive changes, the rollback may involve restoring from backup, reseeding data, or coordinating with downstream consumers. Document **all of that** before opening the PR. If you cannot construct a rollback, the change requires explicit human approval — flag in the PR description and in the issue.

For changes that are inherently irreversible (e.g., deleting historical data, certain DNS changes, releasing a public API surface), see `rules/reversibility.md` Phase D.

## Phase 6 — Self-test

The OPS self-test record has additional sections:

```markdown
# Self-test record — issue #150

## Acceptance criteria
- [x] AC #1: cancel-svc deployment uses 3 replicas in prod
  - Verified: terraform plan shows replicas=3; manifest reviewed
- [x] AC #2: HPA scales 3-10 based on CPU 70%
  - Verified: HPA spec in manifest; `kubectl --dry-run=server` succeeds
- [x] AC #3: Liveness/readiness probes added
  - Verified: probes specified, hit /health endpoint

## Dry-run captured
Plan output at /tmp/plan-issue-150.txt; embedded in issue body via plan-change.sh.
- Resources to add: 0
- Resources to change: 1 (Deployment cancel-svc, replicas: 1 -> 3)
- Resources to destroy: 0

## Rollback
Documented in PR description. Tested: rollback rehearsed in staging by running
`kubectl rollout undo deployment/cancel-svc -n staging`; previous ReplicaSet
restored within 30s.

## Validators
- lint (yamllint + shellcheck): pass
- security (checkov): pass; 0 high/critical findings
- secrets-leak (gitleaks): pass; no leaks
- manifest-dryrun (kubectl --dry-run=server): pass

## Change-window awareness
This is a low-risk change (replica count + HPA). Per rules/change-windows.md,
no specific window required; can apply continuously.

## Ready for review: yes
```

## Phase 7 — Deliver

```bash
bash actions/deliver.sh \
  --issue $ISSUE_N \
  --self-test /tmp/self-test-issue-$ISSUE_N.md \
  --pr-title "infra(cancel-svc): scale to 3 replicas with HPA" \
  --pr-body-file /tmp/pr-body.md
```

The action:
1. Verifies self-test gate (file exists, all AC checked)
2. Verifies the issue body has a captured dry-run plan (plan block present)
3. Verifies the PR body includes a `## Rollback` section
4. Pushes branch, opens PR
5. Routes the issue forward to `agent:arch` for review (OPS PRs typically go to arch for review rather than QA, since the verification model is post-apply observation)

## Phase 8 — Apply (after merge)

Once the PR merges, the change is applied. Two patterns:

### Pattern A: GitOps / auto-apply

If the project uses ArgoCD, Flux, or similar, the merge triggers auto-apply. Your job is to **observe**:

- Watch the apply roll through (5-15 min typical for k8s)
- Verify metrics return to baseline
- Verify no new errors appear in logs

If apply succeeds and observation looks healthy, the issue is done.

### Pattern B: Manual apply

Run the apply command yourself (or with another OPS person):

```bash
git checkout main
git pull
cd infrastructure/
terraform apply
# or: kubectl apply -f manifests/
# or: gcloud run deploy ...
# or: wrangler deploy
```

Watch the apply complete; verify health.

In either pattern, **add a journal entry recording the apply**:

```bash
bash _shared/actions/write-journal.sh \
  /path/to/skills/ops $ISSUE_N "applied" "env=prod time=$(date -u +%FT%TZ)"
```

This audit trail is critical for incident response — when something breaks two hours after, the journal answers "what was applied recently and when".

## Anti-patterns

- **Skipping dry-run** — saves 30 seconds, costs hours when the apply fails partway. Always dry-run.
- **Manual changes in production** (kubectl edit, console clicking) — not captured in IaC = drift = future surprises. If you must make a manual change, follow up with a PR that captures the new state.
- **"Apply now, document rollback later"** — writing rollback after applying means you may discover rollback isn't actually possible. Write rollback as part of the PR.
- **Bundling unrelated changes** — feature change + cleanup + config drift in one PR makes review impossible and rollback risky.
- **Changes that "should be safe"** without verification — confidence isn't safety. Stage / canary / dry-run, in order.
