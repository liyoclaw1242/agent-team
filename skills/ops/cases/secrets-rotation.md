# Case — Secrets Rotation

Rotating a secret without an outage. The pattern is the same across providers; the specific commands vary.

## The pattern: add new before removing old

The unsafe rotation:

```
1. Generate new secret
2. Replace old in secret store
3. Roll services
```

Step 2 invalidates the old value before any service has the new value. Result: outage during step 3 until rollout completes.

The safe rotation:

```
1. Generate new secret
2. Add new value to secret store under a new version (don't remove old)
3. Roll services to read the new version
4. Verify new version is in use
5. Remove old value
```

This is what `rules/secrets-discipline.md` calls the "add new before remove old" pattern. Each step is its own action; failure at any step doesn't break production.

## Worked example: Stripe API key on GCP Secret Manager

Service: `billing-svc` deployed on GKE; reads Stripe key from `prod/billing-svc/stripe-secret-key`.

### Phase 1: generate new key (in vendor)

```bash
# Manual step in Stripe dashboard
# Developers → API keys → "Create restricted key" or "Roll secret key"
# Copy the new value (only shown once)
```

Capture the new value safely (paste buffer fine for the next 2 minutes; don't paste into chat).

### Phase 2: add as new version in Secret Manager

```bash
# Add as a new version; existing version stays
echo -n "$NEW_STRIPE_KEY" | \
  gcloud secrets versions add prod/billing-svc/stripe-secret-key \
    --data-file=- \
    --project=$PROJECT
```

Confirm the new version exists alongside the old:

```bash
gcloud secrets versions list prod/billing-svc/stripe-secret-key --project=$PROJECT
# Should show:
# NAME  STATE
# 2     ENABLED  <-- new
# 1     ENABLED  <-- old
```

### Phase 3: roll services to use the new version

If the deployment references the secret by `:latest` (always reads newest), a pod restart picks up the new value:

```bash
kubectl rollout restart deployment/billing-svc -n production
kubectl rollout status deployment/billing-svc -n production --timeout=5m
```

If the deployment pins a specific version (recommended for predictability), update the pin via PR:

```diff
# k8s/billing-svc/deployment.yaml
env:
  - name: STRIPE_SECRET_KEY
    valueFrom:
      secretKeyRef:
        name: stripe-secret-key
-       key: v1
+       key: v2
```

PR + apply.

### Phase 4: verify new version is in use

Two checks:

**Check 1: at the platform level**, has any pod hit the new secret version?

```bash
gcloud secrets versions describe 2 \
  --secret=prod/billing-svc/stripe-secret-key \
  --project=$PROJECT \
  --format='value(createTime)'
# vs:
gcloud logging read \
  'resource.type="secret_manager" AND \
   resource.labels.secret_id="stripe-secret-key" AND \
   protoPayload.methodName="AccessSecretVersion"' \
  --project=$PROJECT \
  --limit=10
```

The audit log shows accesses; new accesses post-rollout should be hitting version 2.

**Check 2: at the application level**, are Stripe requests succeeding?

```bash
# Watch billing-svc error rate
kubectl logs -f deployment/billing-svc -n production | grep stripe

# Or via dashboard: Stripe API errors metric should remain at baseline
```

Wait at least 24h for any cached references to drain. Some clients (libraries, sidecars) may have cached the old value; the cache TTL determines how long.

### Phase 5: disable old version

Once you're confident the old version isn't used:

```bash
# Disable (not delete — disable can be undone if you need to investigate)
gcloud secrets versions disable 1 \
  --secret=prod/billing-svc/stripe-secret-key \
  --project=$PROJECT
```

Watch for errors over the next 24h. If something breaks (a forgotten consumer), re-enable:

```bash
gcloud secrets versions enable 1 \
  --secret=prod/billing-svc/stripe-secret-key \
  --project=$PROJECT
```

After a successful 24h with version 1 disabled, in Stripe dashboard, **revoke the old key**. (You don't need to delete the secret version in GCP; disabled is fine for audit retention.)

## Variant: rotation on Cloudflare Workers

Workers use `wrangler secret put`:

```bash
# Add new
echo -n "$NEW_KEY" | wrangler secret put STRIPE_SECRET_KEY --env production

# Wrangler doesn't have versions; the put replaces immediately.
# This is the unsafe pattern.
```

Workaround for safe rotation: temporarily use TWO env vars (`STRIPE_SECRET_KEY_NEW` + `STRIPE_SECRET_KEY`), update code to prefer NEW, deploy, observe, then swap names.

This is clunkier than GCP / AWS Secrets Manager. The Cloudflare ecosystem assumes ops via wrangler with shorter rotation windows; live with the trade-off.

## Variant: rotation in Vercel

Vercel env vars are similar to Cloudflare — no native versioning:

```bash
vercel env add STRIPE_SECRET_KEY_NEW production
# (paste new value)
```

Code reads `STRIPE_SECRET_KEY_NEW || STRIPE_SECRET_KEY`. Deploy. Observe. Then:

```bash
vercel env rm STRIPE_SECRET_KEY production
# Code now reads only NEW; eventually rename in next deploy.
```

## Variant: rotation in K8s sealed-secret / SOPS

If secrets are in IaC via sealed-secrets or SOPS, rotation is a PR:

1. Re-encrypt the secret with the new value
2. Commit + apply the IaC change
3. Restart consuming deployments
4. Old value is in git history — accept that, don't try to scrub

The pattern's the same; just IaC instead of imperative commands.

## Database password rotation

Database passwords have an extra step: the database itself needs to know the new password.

For Cloud SQL with IAM auth: prefer IAM auth (no rotation needed). For password auth:

```sql
-- 1. Add new role/password (don't remove old yet)
CREATE USER billing_svc_v2 WITH PASSWORD 'new_value';
GRANT [permissions] TO billing_svc_v2;

-- 2. Add the new password as a new secret version (per Phase 2 above)

-- 3. Roll services to use the new credentials

-- 4. Verify all services connecting as billing_svc_v2

-- 5. Drop the old role
DROP USER billing_svc;
```

The "two roles, parallel" pattern is the safe migration. Don't try to update the same user's password mid-rollout — connections in flight may fail.

## When rotation breaks something

If you rotate and a consumer breaks:

1. **Roll back the consumer first**: re-enable the old secret version
2. **Investigate**: which consumer? What was it caching? Did it ignore the secret update?
3. **Fix the consumer**: usually a code or config issue
4. **Try again**: rotation continues once consumers are reliable

Don't push through a broken rotation. Each retry is cheap; broken production is expensive.

## Audit and tracking

After every rotation, journal:

```bash
bash _shared/actions/write-journal.sh /path/to/skills/ops $ISSUE_N "rotated" \
  "secret=prod/billing-svc/stripe-secret-key from=v1 to=v2"
```

Every quarter, review the journal:

- Which secrets were rotated?
- Which weren't (overdue)?
- File rotation tasks for overdue ones.

## Anti-patterns

- **"Just roll the deployment, the new secret is ready"** — without verifying the new version is in the secret store first
- **Removing old before confirming new is in use** — the bug class that causes rotation outages
- **No journal of when rotated** — overdue rotations go unnoticed for years
- **Manually emailing/chatting the new value to teammates** — secrets discipline; use the secret store's sharing
- **Rotating during peak traffic** — rotation is a (low-risk) change but still avoid peak; per `rules/change-windows.md`
- **Skipping audit log review** — the log tells you whether the new version is actually in use; if it's not, your rollout didn't take effect
