# Rule — Secrets Discipline

Secrets management governs:
1. **Where secrets live**: per-environment, in the secret store, never in git
2. **Who can read what**: minimal access; audit trails
3. **When they rotate**: by class
4. **What happens when leaked**: rotate first, investigate second

## Where secrets live

### The hierarchy

```
Highest priority (use first):
  - Cloud-native secret manager (GCP Secret Manager, AWS Secrets Manager,
    Cloudflare Secrets, Vercel Environment Variables)
  - Kubernetes Secrets (with encryption-at-rest + sealed secrets / SOPS for
    storage in IaC)

Acceptable:
  - GitHub Actions Secrets (for CI-only secrets)
  - HashiCorp Vault (if the team operates one)

Forbidden:
  - .env files committed to git (even .env.example with real values)
  - Hardcoded in code, even with env fallback (`token = process.env.X || 'sk-...'`)
  - Plain-text in IaC files
  - Sent over chat / email / docs
  - In log lines (any log line, ever, even debug)
```

### Environment isolation

- Production secrets are never accessible from dev / staging
- Dev / staging may use real-but-different secrets (fake Stripe key, sandbox API endpoint) or the prod secret if read-only-and-safe (rare)
- Local development uses `.env.local` which is gitignored; values are dev/test only

### Naming conventions

Secrets follow a `{env}/{service}/{name}` hierarchy:

```
prod/cancel-svc/database-password
staging/cancel-svc/database-password
prod/billing-svc/stripe-secret-key
```

This makes auditing ("which prod secrets did we rotate this quarter?") tractable.

## Who can read what

### IAM principles

- **Least privilege**: each secret accessed only by services / people that need it
- **Service accounts ≠ user accounts**: services have their own SAs with narrowly-scoped read access
- **Human access is logged**: audit log for every human read

### Pattern: per-service service account

Each service has its own SA with read access to ONLY its own secrets:

```yaml
# GCP example
- serviceAccount: cancel-svc-sa@project.iam.gserviceaccount.com
  binds:
    - role: secretmanager.secretAccessor
      conditions:
        resource.type == 'secretmanager.googleapis.com/Secret' &&
        resource.name.startsWith('projects/PROJECT/secrets/prod/cancel-svc/')
```

The service can read only secrets prefixed with its own name. Cross-service access requires an explicit second binding.

### Human access

- Routine engineering doesn't access production secrets
- Break-glass access (during incidents) is logged and reviewed
- Audit log retention: project-specific; document in `runbooks/`

## When secrets rotate

### Rotation cadence by class

| Class | Rotation cadence | Method |
|-------|------------------|--------|
| Service-to-service auth (JWT signing keys, mTLS certs) | 90 days | Automated via cert-manager / similar |
| Database passwords | 180 days OR on personnel change | Automated where supported (cloud SQL); manual elsewhere |
| External API keys (Stripe, Twilio, etc.) | 180 days OR on suspected leak | Manual via vendor's UI + secret store update |
| OAuth client secrets | 365 days | Manual + coordinated downtime if needed |
| Long-lived API tokens for ops | 90 days | Manual; auto-rotate where vendor supports |

### Rotation steps (manual case)

1. Generate new value (in vendor UI or via the auth system)
2. Add new value to secret store under a new version (don't overwrite yet)
3. Roll services to read the new version (rolling deploy)
4. Verify new version is in use (no errors, traffic still flowing)
5. Decommission old value (delete from vendor + secret store)

This is the safe rotation pattern. Skipping the "add new before remove old" step is what causes outages mid-rotation.

### Rotation runbook

Each secret class has a runbook in `runbooks/secrets/{class}.md`:

```markdown
# Stripe API key rotation

## Cadence
180 days OR immediately on suspected leak.

## Steps

1. Generate new key in Stripe dashboard (Developers → API keys → Create new secret)
2. Save the new key to GCP Secret Manager:
   `gcloud secrets versions add prod/billing-svc/stripe-secret-key --data-file=-`
3. Roll the billing-svc deployment:
   `kubectl rollout restart deployment/billing-svc -n production`
4. Wait for rollout to complete (~2 min)
5. Verify in Stripe dashboard: requests are using the new key
6. Wait 24h for any cached references to drain
7. Disable the old key in Stripe dashboard
8. Mark the old version of the secret as DISABLED in GCP Secret Manager

## Verification
- New key visible in Stripe dashboard's "Last used" within 5 min of step 4
- billing-svc error rate stays at baseline through and after rotation
```

## What happens when leaked

If a secret is committed to git, exposed in a log, or otherwise leaked:

1. **Rotate first, investigate second**. Generate new value; deploy it. Old value is now invalid.
2. **Document**: file an incident issue with the leak details (where, when, who saw it). Don't delete the leaked artefact (commit, log) — the incident record needs the evidence.
3. **Investigate**: how did the leak happen? Which controls failed? File a follow-up to fix the control.

DO NOT just delete the leaked content from git history hoping it's gone. Anyone who cloned the repo before the deletion has it. The only correct response is to rotate.

## Validation

`validate/secrets-leak.sh` runs `gitleaks` to catch secrets committed to the branch. Any finding fails the validator, which fails the deliver gate.

`validate/security.sh` includes IaC-level secret-detection (checkov, tfsec) catching things like `password = "literal"` in Terraform.

These are last-chance catches; the discipline above is the primary defence.

## Anti-patterns

- **Reusing a secret across environments** — staging compromised = prod compromised
- **Adding a secret without an associated rotation plan** — secrets without rotation cadence become permanent surface area
- **Storing secrets in 1Password / etc as the source of truth** — those are fine for personal credentials, not for service secrets that need automation
- **Email / chat exfiltration "just to share quickly"** — once it's in someone's inbox, it's leaked. Use the secret store's sharing.
- **"Temporary" hardcoding for testing** — temporary becomes permanent. Use a test secret in the secret store from day one.
