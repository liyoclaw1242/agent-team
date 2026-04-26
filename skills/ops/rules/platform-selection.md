# Rule — Platform Selection

When the spec doesn't prescribe a platform, OPS picks. The criteria below produce defensible decisions and avoid "I prefer X" rationalisation.

## The platforms in scope

| Platform | Best fit | Don't fit |
|----------|----------|-----------|
| **K8s (GKE/EKS)** | Long-running services, stateful workloads, complex networking, multi-service deployments needing service mesh | Simple static sites, sub-100req/min CRUD APIs, websocket-heavy apps with sub-100 concurrent users |
| **Cloud Run** | HTTP-bound stateless services, burst traffic, low baseline traffic, batch-style work | Long-lived connections (websockets >60min), services needing local disk persistence, very high QPS where instance startup latency matters |
| **Vercel** | Next.js / Nuxt / Gatsby frontends, sites with edge/ISR needs, preview environments per PR | Backend services with non-trivial server logic, anything not strongly aligned to Vercel's framework support, services needing custom Docker images |
| **Cloudflare Workers** | Edge logic (auth, redirects, A/B), API gateways, lightweight backends with sub-50ms target latency, simple JSON CRUD over D1/KV | Heavy compute (>50ms per request), services needing more than KV/D1 storage, services with Node.js-only library deps |
| **Cloudflare Pages** | Static sites, JAMstack frontends with light server logic | Same constraints as Workers; for heavy backend logic combine with separate Workers/external API |
| **Plain GCS / Cloudflare R2 + CDN** | Pure static content, no compute | Anything dynamic |

## Decision framework

Walk these in order; first match wins.

### Q1: Is it pure static content?

If yes → Cloudflare Pages or GCS+CDN. Don't pay for compute you don't use.

### Q2: Is it a frontend framework Vercel supports natively?

Next.js / Nuxt / Astro / SvelteKit — Vercel has the best DX. If your team is already on Vercel for FE, stick with it unless there's reason not to.

Counter-signals to Vercel:
- Heavy server-side logic that should be in a separate API service anyway
- Custom Docker base image needed
- Cost concerns at high traffic (Vercel can get expensive past certain QPS — calculate)

### Q3: Is it edge logic (very low latency, simple processing)?

Auth tokens, redirects, geolocation routing, header manipulation, A/B test assignment, simple JSON APIs reading from KV — Cloudflare Workers.

Don't try to run heavy compute (image processing, ML inference, complex DB queries) on Workers; constraint pushes you to Cloud Run / K8s.

### Q4: Is it stateful or long-running?

Stateful (in-memory state across requests, SSE/websocket >60min, scheduled background jobs holding state) → K8s.

Cloud Run scales to zero between requests; not suitable for long-lived connections or stateful workloads.

### Q5: HTTP backend, stateless, traffic is bursty or low-baseline?

Cloud Run is the sweet spot. Scales to zero (no idle cost), handles bursts, no infra to manage. Most internal APIs and webhook handlers fit here.

### Q6: HTTP backend, stateless, but high baseline traffic?

Calculate. Cloud Run charges per instance-time during requests; K8s charges for reserved capacity. There's a crossover point where K8s becomes cheaper.

Rough heuristic: if you'd run >2 always-warm instances anyway (sustained traffic), K8s is competitive. Below that, Cloud Run wins on operational simplicity even if marginally pricier.

### Q7: Multiple coupled services with cross-service networking complexity?

K8s. Service mesh, network policies, sidecar patterns, affinity rules — all exist on K8s and don't on serverless.

If your design has 5+ services with explicit inter-service requirements (latency, tracing, mTLS), K8s amortises the operational cost across the fleet.

### Q8: Compliance / data residency / network constraints?

Sometimes the answer is dictated by external constraint:
- Data must stay in EU → narrows to platforms with EU regions and clear data residency contracts
- Government / regulated industry → platform certification (FedRAMP, HIPAA) matters
- VPC-only / no public internet → K8s in private subnets, Cloud Run with VPC connector, or AWS PrivateLink-style setup

If constrained, list the constraint first; pick the platform that satisfies it.

## What this rule is NOT

- It's not a "best platform" list. Best is contextual.
- It's not gospel. Counter-evidence (your team has expertise in X, your existing infra is Y) overrides defaults.
- It's not anti-AWS. AWS is fine; we just don't use it in this org.

The point is to make the decision **explicit and defensible** rather than reflexive.

## How to document the decision

When the spec doesn't prescribe and you pick, the PR description includes:

```markdown
## Platform decision

Picked: Cloud Run

Rationale:
- Service is stateless HTTP (POST /webhook/stripe handler)
- Baseline traffic is ~10 req/min; bursts to ~500 req/min during campaigns
- No long-lived connections
- Per Q5 of platform-selection.md — Cloud Run is the standard answer for this profile

Considered alternatives:
- K8s: overhead too high for a single-handler service; would need to deploy alongside other services for it to amortise
- Cloudflare Workers: handler involves Stripe SDK (Node-heavy); Workers' compute limit may be tight
```

This makes the decision auditable. Future readers know why this platform.

## When the spec prescribes a platform

If the spec says "deploy to GCP Cloud Run", do that — UNLESS reality-check reveals a hard mismatch (per `workflow/feedback.md` — `platform-mismatch` category). Don't second-guess unless evidence requires it.

## When you're not sure

If you've walked the framework and still aren't sure between two platforms, default to the one your team has more operational experience with. Operational expertise reduces incident risk more than marginal platform-fit improvements.

## Anti-patterns

- **"Always K8s" / "always serverless" reflex** — the framework exists to push past these
- **Picking platform based on novelty** — "let's try X" is a bad reason; pilot it on a low-risk new service first if curious
- **Ignoring cost in the decision** — cost matters; do the math
- **Rejecting incumbent platform without reason** — if 90% of your services are on K8s, the 10th should be on K8s too unless there's a real reason
