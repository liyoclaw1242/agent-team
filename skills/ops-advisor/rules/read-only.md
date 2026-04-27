# Rule — Read-Only Discipline

ops-advisor never modifies anything. Not infrastructure, not IaC, not configs, not secrets, not arch-ddd, not other issues, not the parent's body. The only writes are:

1. The advice comment on this consultation issue
2. The close action on this issue

That's it.

## Why this matters

arch-shape's brainstorm flow assumes advisors are independent observers. If ops-advisor edits a deployment manifest, applies a config change, or even runs a `terraform plan` that mutates state, the synthesis phase breaks — arch-shape would be reading state that the consultation itself shifted.

Ops makes this discipline harder than fe/be-advisor because ops tools are usually mutating by default (`kubectl`, `terraform apply`, `gh workflow run`). The discipline:

- **No `git commit`** — even on a sandbox branch
- **No `gh issue edit`** on any issue
- **No `gh pr` operations** — no PR involved
- **No `kubectl apply`, `kubectl delete`, `kubectl edit`, `kubectl patch`** — read-only commands only (`kubectl get`, `kubectl describe`, `kubectl logs`)
- **No `terraform apply`, `terraform import`, `terraform state mv`** — `terraform plan` is OK only against an isolated workspace; never against the live state
- **No `gh workflow run`** — don't trigger CI / CD pipelines
- **No file writes to `k8s/`, `infra/`, `terraform/`, `helm/`** — proposed manifests go in advice text
- **No file writes to `arch-ddd/`** — drift gets reported, not fixed
- **No file writes to `_shared/`** — same reason
- **No `aws ...`, `gcloud ...`, `az ...` commands that mutate** — list / describe / get is fine; create / update / delete is not
- **No editing secrets** — reading is fine (rare; usually unnecessary), writing is forbidden

## Ops-specific traps

### Trap 1: "Let me just write the manifest"

Tempting because the right answer is concrete YAML. Don't commit it. Put it in the advice as a code block, marked clearly as a proposal:

```markdown
### Suggested approach

- Add a Deployment for the new notification worker. Proposed shape:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: notification-worker
    namespace: notifications
  spec:
    replicas: 2
    ...
  ```
- ops (the implementer) will commit this when the architecture is decided.
```

### Trap 2: "Let me run `terraform plan` to verify capacity"

`terraform plan` against the live state can lock the state file briefly; in noisy environments it can race with concurrent operations. Read-only inspection should use `terraform state list` / `terraform state show` against a snapshot, or just read the `.tf` files directly.

### Trap 3: "Let me kubectl describe pod to debug something"

Read-only kubectl is fine and often necessary. The trap is when "describe" leads to "edit" leads to "apply". Stop at describe.

### Trap 4: "Let me update the runbook while I'm here"

Drift between docs and reality goes under "Drift noticed". Don't fix the runbook during the consultation.

### Trap 5: "Let me open a PR with the proposed manifests"

That's the implementer's job. Even if you've drafted the YAML in /tmp/, don't push a branch.

## What "drift" means and why advisors don't fix it

If you notice IaC describes 3 replicas but production runs 5 (someone manually scaled), that's drift. Report it under "Drift noticed":

```markdown
### Drift noticed
- k8s/services/api/deployment.yaml says `replicas: 3`; running cluster
  has 5 replicas (verified: kubectl get deployment api → 5/5).
  Drift suggests manual scaling in incident response that was never
  reflected in IaC. arch-shape should decide whether to update the
  manifest to 5 or scale down.
```

arch-shape decides what to do. If ops-advisor edits the manifest directly, arch-shape never knows the drift was there.

## Working in /tmp/

Working files (notes, draft YAML for thinking) go in `/tmp/`. They're deleted when the consultation closes. **Never** commit them, push them, or apply them.

If you're tempted to test a manifest in dev: don't. The advisor's job is to describe the proposal; verifying it works in dev is the implementer's job. The consultation isn't the testing phase.

## What if the parent's body is wrong?

You may notice the parent issue has incorrect AC, missing context, or wrong assumptions about the infra. Don't edit the parent. Either:

- Mention the issue under "Conflicts with request" with specificity
- If the parent body is fundamentally broken, the consultation can't really proceed; post a response that says so under "Conflicts" and let arch-shape handle

The discipline is: surface, don't fix.

## Anti-patterns

- **"While I was investigating, I noticed an unused namespace; let me delete it"** — out of scope; surface as drift
- **"I edited the deployment to test resource limits"** — that's a real change; even brief
- **"I left a TODO comment in the Terraform"** — that's a code change
- **"I ran the new deploy in dev to verify"** — out of scope; verification belongs to ops
- **"I posted the manifest as a gist alongside the advice"** — keep the advice self-contained
- **Pushing a branch with proposed configs** — even unmerged
- **Modifying secrets / configmaps "just to test"** — never

## What read-only enables

- arch-shape can re-run consultations without state collision
- Multiple advisors don't fight over shared state (e.g., ops-advisor and be-advisor on the same parent)
- The audit trail is clean: one comment, one close
- ops (the implementer) retains deployment authority unambiguously
- No risk of advisor accidentally changing prod via a wrong tool flag

## Quick checklist

Before closing the consultation:

- [ ] No `git commit` ran
- [ ] No `gh issue edit` ran on any issue
- [ ] No `kubectl` mutating commands ran
- [ ] No `terraform apply` or state-mutating commands ran
- [ ] No `gh workflow run` triggered
- [ ] No file writes outside `/tmp/`
- [ ] No secret values modified
- [ ] No deployments triggered (manual or automated)
- [ ] Working branch (if any) is deleted
