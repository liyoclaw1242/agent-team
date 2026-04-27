# Case — Infrastructure Greenfield

A request that requires introducing infrastructure that doesn't yet exist. ops-advisor's job is to honestly report "no existing infra for this" and surface the implications, including alternatives that avoid introducing new infra.

## The consultation

Parent issue #810: "Add a real-time presence indicator showing which users are currently online."

arch-shape opened consultation #811 to ops-advisor:

```
- What in current infra makes real-time presence easy or hard?
- Does presence imply any new shared infrastructure?
- What's the deploy / blast radius story?
```

## Phase 1 — Investigate

```bash
# Existing real-time / pub-sub infra?
grep -r "websocket\|socket.io\|redis.*pubsub" k8s/ infra/
# → no matches in cluster manifests
# → no matches in terraform

# Existing Redis?
grep -r "redis" k8s/ helm/
# → 1 Redis deployment for session caching (k8s/infra/redis-cache)
#   single-instance, not clustered, not configured for pubsub

# Existing message queue?
grep -r "rabbitmq\|kafka" k8s/ helm/
# → RabbitMQ exists for async jobs (orders, payments)
#   not a fit for real-time presence (per-message persistence is overkill)

# Existing WebSocket / SSE patterns?
grep -r "ws\|websocket\|EventSource" k8s/services/
# → no matches in any service config
# → no service exposes WebSocket endpoints

# Ingress / load balancer config
cat k8s/services/ingress-controller/values.yaml | grep -i sticky
# → no sticky session config
# → would need configuring for WebSocket connections to stick

# Capacity
kubectl describe nodes | grep -A2 "Allocated"
# → 4 nodes, ~75% CPU committed
# → headroom for 1-2 small services without scaling

# Existing services consuming Redis
git grep -l "redis" services/
# → services/auth/session.go (the only Redis consumer)
```

## Phase 2 — Compose response

```markdown
## Advice from ops-advisor

### Existing constraints

- No real-time / pub-sub infrastructure in cluster prod-tw-1. Verified
  by grep on k8s/, helm/, terraform/ — no Redis pubsub config, no
  WebSocket-aware ingress, no SSE patterns in any service.
- Redis exists (k8s/infra/redis-cache, single-instance, helm/redis-cache
  release, version 7.0). Used only by services/auth/session.go for
  session caching. Not configured for pubsub; would need separate Redis
  instance or Redis cluster mode for presence at scale.
- RabbitMQ exists for async background jobs (payments, orders). Not a
  good fit for presence — RabbitMQ persists per-message; presence is
  ephemeral and high-churn.
- Ingress controller (nginx-ingress, k8s/services/ingress-controller)
  has no sticky session config and no WebSocket-aware annotations.
  WebSockets would work but session affinity may be needed depending on
  scaling pattern.
- Cluster capacity: 4-node default pool, ~75% CPU committed. Headroom
  for one small new service (~0.5 CPU). Adding clustered Redis or Kafka
  would push capacity beyond comfortable; cluster autoscaler would kick
  in (configured 2-8).
- arch-ddd has no documented real-time / presence patterns; this
  category is greenfield for the platform.

### Suggested approach

This is a greenfield real-time feature; there's no existing infra to
extend. Three architectural directions, ranked by infra cost:

- **A) Polling (no new infra)**: client polls /api/users/online every
  30-60 seconds. Existing API services and DB. Stale by design (30-60s
  granularity). Smallest infra change.

- **B) Server-Sent Events on a dedicated service (one new service,
  shared Redis)**: a small SSE service holds connections, reads from
  Redis pubsub. Reuses existing Redis (would need pubsub mode enabled,
  possibly a separate Redis instance for isolation). Requires
  ingress sticky-session config for SSE.

- **C) WebSocket on a dedicated service with clustered Redis (significant
  new infra)**: clustered Redis for pubsub at scale; WebSocket service
  with horizontal scaling; sticky-session ingress. Production-grade
  real-time; significant infra commitment.

Recommend **A as MVP** if real-time-ness is a "nice to have" — most
"online" UI works fine with 30-60s staleness and saves the infra cost
entirely. **B is the right next step** if real-time is genuinely
required; it's a meaningful improvement without major infra commitment.
**C is justified only at scale** (~10k concurrent users) or if
multi-purpose real-time features are planned (chat, notifications,
collaborative editing).

For Direction B (recommended for real-time):
- Reuse existing Redis cluster for pubsub OR provision a dedicated
  Redis instance (recommended; isolation from session caching workload)
- New SSE service: stateless, connects to Redis, holds connections to
  clients
- Ingress: configure SSE-friendly timeouts (idle connections kept open)
- Monitoring: connection count, message rate, broadcast latency

### Conflicts with request

- "Real-time" hasn't been quantified. If "real-time" means <1 second,
  options A is out. If "real-time" means <30 seconds, A may be sufficient
  and dramatically cheaper. Recommend arch-shape clarify before infra
  commitment.
- Request implies presence is a primary feature; the infra cost is
  significant for a feature whose primary user value is unclear. Worth
  confirming demand before infra investment.

### Estimated scope

- For Direction A (polling): S — 0 new infra; FE/BE-only change. No
  ops scope beyond verifying API rate limits handle the polling load.
- For Direction B (SSE + Redis pubsub): M — ~6 new manifests:
  - New service Deployment + Service + ConfigMap (3)
  - PrometheusRule + ServiceMonitor (2)
  - Ingress annotation update (1; existing manifest modification)
  - Possibly: helm/redis-presence release (separate Redis instance) (~3 files)
  - Existing Redis: enable pubsub mode (if reusing); 1 config change
- For Direction C (WebSocket + clustered Redis): L+ — would require:
  1. Clustered Redis (helm chart deployment; ~10 manifests)
  2. WebSocket service with sticky-session ingress
  3. Connection state migration story (when pods restart)
  4. Load-test and capacity planning
  5. Runbook for connection-storm incidents
  Strongly suggest decomposing if Direction C is chosen.

### Risks

- Direction A: API rate limits. Polling at 60s × 1000 active users =
  ~17 requests/second; well within current capacity. At 10k users:
  ~167 RPS. Worth load-testing.
- Direction B: SSE connection holds open; ingress timeout misconfig
  can cause cascading reconnects. Verify ingress timeout > SSE
  expected idle, plus client-side reconnect with backoff.
- Direction B: Redis pubsub fan-out scales with subscribers. At 10k
  subscribers, every status change broadcasts 10k messages. Verify
  Redis can handle this; clustered Redis may be needed earlier
  than expected.
- Direction C: WebSocket sticky sessions reduce horizontal scaling
  efficiency. Connection rebalancing on pod restart is a known
  pain point.
- All directions: blast radius of presence service failure — UI
  shows incorrect "online" state. Acceptable degradation if FE
  handles "presence unknown" gracefully.
- Direction B/C: introducing Redis pubsub adds a shared dependency.
  If presence misbehaves, could DoS the shared Redis instance,
  affecting session caching too. Recommend separate Redis instance.

### Drift noticed

- arch-ddd has no documented real-time / presence patterns. This
  category should be added once direction is decided.
- Existing Redis (k8s/infra/redis-cache) is single-instance with no
  HA. If presence reuses it and it fails, both presence AND session
  caching fail. Worth noting separately from this consultation —
  current Redis is a single point of failure already.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 811 \
  --advice-file /tmp/advice-issue-811.md
```

## What this case demonstrates

- **Investigated infra before opining**: greps confirmed no existing real-time stack
- **Surfaced cheap alternative**: polling avoids infra entirely; recommended as MVP
- **Three options with infra-cost gradient**: S → M → L+ cost; arch-shape can pick based on real-time requirement
- **Pushed back on vagueness**: "real-time" isn't quantified; recommended clarification
- **Cross-cutting risks called out**: shared Redis SPOF, ingress sticky-session, blast radius
- **Drift surfaced**: arch-ddd gap + existing Redis SPOF as separate concern
- **No infra committed**: all proposals as text, including the proposed Redis configuration

## Key lessons for greenfield infra consultations

1. The first sentence should establish "this is greenfield infrastructure". Don't bury it.
2. Always surface the "no new infra" alternative if one exists — sometimes the best ops advice is "don't add infra".
3. Greenfield infra is often L+ for the full version. Decomposition or staging is usually the right move.
4. Real-time / streaming / pub-sub features often imply new infra; recognise the pattern.
5. Existing infrastructure has hidden constraints (single-instance Redis, no sticky sessions); surface them as constraints, not assumptions.
