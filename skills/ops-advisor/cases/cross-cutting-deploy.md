# Case — Cross-Cutting Deploy

A request that requires coordinated changes across multiple services / manifests where deploy ordering matters. ops-advisor's job is to surface the coordination cost and propose the right deploy sequence.

## The consultation

Parent issue #910: "Migrate all services from internal-jwt-validator library v1 to v2 (v1 has a CVE)."

arch-shape opened consultation #911 to ops-advisor:

```
- Which services use jwt-validator v1?
- Can we deploy in any order, or does sequence matter?
- What's the rollback story?
```

## Phase 1 — Investigate

```bash
# Services using the validator
grep -r "jwt-validator" services/ go.mod
# → 6 services import jwt-validator: api-gateway, payments, orders,
#   billing, admin-api, customer-api

# Library version
grep "jwt-validator" go.sum | head
# → currently v1.4.2

# v2 differences (read changelog or release notes)
git show v2.0.0:CHANGELOG.md | head -30
# → token format unchanged
# → API surface compatible
# → but: v2 has stricter signature verification; tokens signed with
#   weak algorithms (RS256 with weak key) will reject

# Token producer — which service issues tokens?
grep -r "jwt.Sign\|GenerateJWT" services/
# → services/auth/token.go is the only producer

# Token signing algorithm currently
grep -A2 "SigningMethod" services/auth/
# → uses RS256 with 2048-bit key (acceptable; v2 won't reject)

# Deploy patterns
ls .github/workflows/
# → deploy-{service}.yml per service
# → no batch deploy

# Recent multi-service rollouts
git log --oneline --all -- .github/workflows/ | head
# → most rollouts are single-service; rare multi-service

# Are services stateless?
grep -l "kind: Deployment" k8s/services/*/
# → all 6 affected services use Deployment (rolling update)

# Existing rollback patterns
cat runbooks/rollback.md 2>/dev/null
# → file exists; describes rolling back via gh workflow run with prev SHA
```

## Phase 2 — Compose response

```markdown
## Advice from ops-advisor

### Existing constraints

- 6 services import jwt-validator v1.4.2: api-gateway, payments, orders,
  billing, admin-api, customer-api (verified via grep on services/ and go.mod).
- 1 service is the token producer: services/auth/token.go uses RS256
  with 2048-bit key. v2's stricter algorithm enforcement won't reject
  current token signatures (RS256 is still allowed in v2).
- All 6 affected services are stateless Deployments using rolling update
  strategy (verified via grep on k8s/services/).
- Each service has its own deploy workflow (.github/workflows/deploy-{service}.yml).
  No batch / orchestration workflow exists; updates would be
  per-service rollouts.
- Token format is unchanged between v1 and v2; v1 and v2 validators
  can both verify the same tokens. This means deploy ordering is
  flexible (no breakage if some consumers are v1 and some are v2 during
  rollout).
- Existing rollback runbook (runbooks/rollback.md) covers single-service
  rollback via gh workflow run with prior SHA. Multi-service rollback
  not specifically documented.

### Suggested approach

Because v1 and v2 validators are interoperable for current tokens,
**deploy order is flexible**. This is the easy case for cross-cutting
upgrades.

Recommended sequence:

1. **Pre-flight**: bump library version in shared module / go.mod.
   PR #1: change go.mod across all 6 services (one PR or per-service).
   No production deploy yet.

2. **Stage 1 (one canary service)**: Deploy `customer-api` first. It's
   the lowest-traffic service in the set; failure mode is localised
   (some customer requests fail; not blocking other services).

3. **Stage 2 (verify)**: Monitor customer-api for 24-48 hours. Watch:
   - Error rate (jwt validation errors specifically)
   - Latency (validation overhead, if any)
   - Logs for unexpected behaviour

4. **Stage 3 (remaining services)**: If stage 2 clean, deploy the
   remaining 5 services. Order doesn't matter much, but suggested
   batching: 2 services per deploy window to limit blast radius.

5. **Cleanup**: Remove jwt-validator v1 from go.sum (after all
   services confirmed on v2).

Total: 4-5 deploy windows over ~1 week.

### Conflicts with request

- Request says "all services". This consultation found 6 services
  using v1; assume that's all. If new services have been added that
  also use jwt-validator, they need to be in scope. Recommend a
  final grep before final cleanup PR.
- Request implies urgency (CVE). The 1-week phased rollout balances
  safety with speed. If urgency is "patch within 24 hours", we'd need
  to skip the canary phase and accept larger blast radius if v2 has
  unexpected issues. Recommend arch-shape weight CVE severity vs
  rollout caution.

### Estimated scope

- M — 6 services, 6+ deploy phases (as recommended), 1-2 weeks elapsed:
  - 1 PR (or 6) bumping go.mod versions
  - 6 deploy workflows triggered
  - Monitoring during canary phase
  - Runbook update for v2 validation behavior (if any nuances)
  - Cleanup PR removing v1 (post-rollout)
- This is M not S because of coordination cost; pure file count is small.
- Could be S if all 6 services are deployed in a single batch, but
  that has higher blast radius.

### Risks

- Blast radius: per-stage rollout limits blast to 1 service initially.
  All 6 services failing simultaneously (worst case) would affect
  user-facing API access broadly. Mitigation: per-service rollback via
  existing runbook.
- v2 unknowns: even though the API is compatible, v2 may have
  different memory / CPU profile. Monitor resource utilisation
  during canary stage.
- CVE exposure: each day of phased rollout extends CVE exposure. If
  the CVE is high-severity (e.g., signature bypass), the phased
  rollout is wrong choice — accept higher blast radius and deploy
  in one window.
- Coordination: 6 services across multiple owning teams. If teams are
  distributed, scheduling deploy windows is non-trivial. Recommend
  arch-shape coordinate or run all deploys from a single orchestrator
  account.
- Rollback: if a service is rolled back to v1 due to issue, it remains
  CVE-exposed. Need a clear protocol for "v2 problem detected, what
  next" — temporary mitigation in place of v2?
- Token producer (auth service) is not in scope; v2 doesn't change
  signing behavior for current key. But if auth service is later
  upgraded in a way that affects signing (e.g., key rotation), the
  v2 consumers may need re-evaluation. Worth noting for future awareness.

### Drift noticed

- arch-ddd doesn't document jwt-validator usage or version policy.
  Worth adding (which version is approved, how upgrades are coordinated).
- 1 of the 6 services (admin-api) was migrated from a different auth
  pattern in PR #200; may have residual code paths that don't go
  through jwt-validator. Verify during the upgrade — easy to miss.
- runbooks/rollback.md describes single-service rollback only;
  multi-service rollback procedure should be added before this
  rollout starts.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 911 \
  --advice-file /tmp/advice-issue-911.md
```

## What this case demonstrates

- **Verified affected services with grep**: not "I think 5-6 services"; verified the exact 6
- **Determined deploy ordering matters or not**: in this case, v1/v2 interoperate, so order is flexible — said so explicitly
- **Recommended phased rollout**: with named canary service, monitoring criteria, batching
- **Pushed back on assumed urgency**: surfaced the trade-off between caution and CVE exposure; let arch-shape weight
- **Cross-team coordination noted**: multi-team deploy is harder than single-team
- **Rollback story considered**: rolling back to v1 means re-exposing CVE; surfaced as a real risk
- **Drift surfaced for follow-up**: missing arch-ddd, possible code paths bypassing the lib

## Key lessons for cross-cutting deploy consultations

1. Always verify the affected set with grep — assumed counts are usually wrong
2. Determine if deploy order matters; it often doesn't, which simplifies dramatically
3. Cross-cutting deploys benefit from canary + phased rollout; recommend one even when not asked
4. Coordination cost is real; cross-team deploys are slower than within-team
5. Rollback complexity for security upgrades is special — re-exposing the issue is often worse than alternatives
6. Time pressure (CVEs, urgency) changes the right answer; surface the trade-off rather than picking unilaterally
