# Case — Cloudflare Deployment

Cloudflare's product family: Workers (edge functions), Pages (static + functions), R2 (object storage), KV (eventual-consistent key-value), D1 (SQLite at the edge), Durable Objects (strongly-consistent stateful), DNS, Zero Trust. OPS owns deployment of all of these.

## When Cloudflare fits

Per `rules/platform-selection.md`:

- **Workers**: edge logic, API gateways, lightweight backends, sub-50ms target latency
- **Pages**: static sites, JAMstack frontends, JavaScript-based functions
- **R2**: S3-compatible object storage, especially when you'd otherwise pay AWS egress fees
- **KV**: caching, feature flags, eventual-consistent config
- **D1**: small relational data, edge-readable, SQLite-compatible
- **Durable Objects**: stateful coordination (chat rooms, game state, distributed locks)

What Cloudflare doesn't fit:
- Heavy compute per request (>50ms CPU or non-trivial Node libraries)
- Strongly-consistent multi-region writes (Durable Objects help but with limits)
- Workloads requiring full Node.js runtime (some compatibility, not all)

## Workers worked example

A simple cancellation handler at the edge.

### Project layout

```
cancel-edge/
├── wrangler.toml
├── package.json
├── tsconfig.json
└── src/
    ├── index.ts
    └── types.ts
```

### `wrangler.toml`

```toml
name = "cancel-edge"
main = "src/index.ts"
compatibility_date = "2026-04-01"
compatibility_flags = ["nodejs_compat"]   # only if you need Node-style APIs

# Default (development) account binding
account_id = "..."

# Per-environment config
[env.staging]
name = "cancel-edge-staging"
routes = [
  { pattern = "cancel-staging.example.com/*", zone_name = "example.com" }
]

[env.staging.vars]
LOG_LEVEL = "debug"
UPSTREAM_API = "https://api-staging.example.com"

[env.production]
name = "cancel-edge"
routes = [
  { pattern = "cancel.example.com/*", zone_name = "example.com" }
]

[env.production.vars]
LOG_LEVEL = "info"
UPSTREAM_API = "https://api.example.com"

# KV binding (for both envs; per-env override below)
[[kv_namespaces]]
binding = "RATE_LIMIT_KV"
id = "PROD_KV_NAMESPACE_ID"
preview_id = "STAGING_KV_NAMESPACE_ID"

# D1 binding
[[d1_databases]]
binding = "DB"
database_name = "cancel-db"
database_id = "..."
```

### `src/index.ts`

```typescript
interface Env {
  RATE_LIMIT_KV: KVNamespace;
  DB: D1Database;
  STRIPE_SECRET_KEY: string;        // from secret, not vars
  UPSTREAM_API: string;
  LOG_LEVEL: string;
}

export default {
  async fetch(request: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (request.method !== 'POST') {
      return new Response('Method not allowed', { status: 405 });
    }

    // Rate limit per user
    const userId = await getUserId(request);
    const rateLimitKey = `rl:${userId}:cancel`;
    const current = parseInt(await env.RATE_LIMIT_KV.get(rateLimitKey) ?? '0');
    if (current >= 5) {
      return new Response('Rate limit exceeded', { status: 429 });
    }
    ctx.waitUntil(env.RATE_LIMIT_KV.put(rateLimitKey, String(current + 1), { expirationTtl: 60 }));

    // Forward to upstream API for the actual cancellation
    const upstreamResp = await fetch(`${env.UPSTREAM_API}/cancel`, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${env.STRIPE_SECRET_KEY}`,
        'Content-Type': 'application/json',
      },
      body: await request.text(),
    });

    return new Response(upstreamResp.body, {
      status: upstreamResp.status,
      headers: upstreamResp.headers,
    });
  },
};
```

### Secrets

Don't put secrets in `vars`. Use `wrangler secret`:

```bash
echo -n "$STRIPE_SECRET_KEY" | wrangler secret put STRIPE_SECRET_KEY --env production
```

Per environment:

```bash
echo -n "..." | wrangler secret put STRIPE_SECRET_KEY --env staging
echo -n "..." | wrangler secret put STRIPE_SECRET_KEY --env production
```

### Deploy

```bash
# To staging
wrangler deploy --env staging

# To production
wrangler deploy --env production

# Dry-run
wrangler deploy --env staging --dry-run --outdir dist
```

The dry-run builds the bundle locally (catches build errors); actual upload doesn't happen.

### Local dev

```bash
wrangler dev --env staging
```

Local server with bindings emulated. KV, D1 use local SQLite by default (or `--remote` to hit real services).

## Pages worked example

For a static frontend (or JAMstack with edge functions):

### `wrangler.toml` for Pages

Pages uses a simpler config; usually `pages_build_output_dir`:

```toml
name = "marketing-site"
pages_build_output_dir = "./dist"
compatibility_date = "2026-04-01"

[[env.production.vars]]
NEXT_PUBLIC_API_URL = "https://api.example.com"
```

### Functions

If your app has edge functions, place them in `functions/` (Pages convention):

```
functions/
├── api/
│   └── feedback.ts          → routes /api/feedback
└── _middleware.ts           → applies to all routes
```

Each file is a Workers handler:

```typescript
// functions/api/feedback.ts
export async function onRequestPost(context: EventContext<Env, any, any>) {
  const body = await context.request.json();
  // ... handle
  return new Response('ok');
}
```

### Deploy

```bash
wrangler pages deploy dist/ --project-name marketing-site --branch main
```

For a CI integration, use the Cloudflare Pages GitHub integration (Settings → Builds & deployments → Connect to Git). Each PR gets a preview deploy automatically.

## R2 worked example

S3-compatible object storage. No egress fees if served via Workers (big cost win vs S3 for high-bandwidth use cases).

### Bucket setup

```bash
wrangler r2 bucket create user-uploads
```

### Bind to a Worker

```toml
[[r2_buckets]]
binding = "UPLOADS"
bucket_name = "user-uploads"
preview_bucket_name = "user-uploads-preview"
```

### Use in Worker

```typescript
async fetch(request: Request, env: { UPLOADS: R2Bucket }): Promise<Response> {
  const key = new URL(request.url).pathname.slice(1);
  
  if (request.method === 'GET') {
    const obj = await env.UPLOADS.get(key);
    if (!obj) return new Response('Not found', { status: 404 });
    return new Response(obj.body, { headers: obj.httpMetadata });
  }
  
  if (request.method === 'PUT') {
    await env.UPLOADS.put(key, request.body, {
      httpMetadata: request.headers,
    });
    return new Response('Created', { status: 201 });
  }
  
  return new Response('Method not allowed', { status: 405 });
}
```

### Direct S3-API access

R2 also has S3-compatible HTTP API. For tools / SDKs that already speak S3:

```bash
aws s3 ls s3://user-uploads \
  --endpoint-url https://ACCOUNT_ID.r2.cloudflarestorage.com
```

## DNS management

Cloudflare DNS is generally managed via dashboard, but for IaC:

### Via Terraform

```hcl
resource "cloudflare_record" "cancel_app" {
  zone_id = var.zone_id
  name    = "cancel"
  value   = "cname.vercel-dns.com"
  type    = "CNAME"
  ttl     = 1     # 1 means "automatic" in Cloudflare (300s typical)
  proxied = false # true = traffic goes through Cloudflare's proxy + CDN
}
```

### Proxied vs DNS-only

Cloudflare's "orange-cloud" (proxied) routes traffic through their network: DDoS protection, caching, Cloud Workers can intercept. "Grey-cloud" (DNS only) is just DNS resolution.

Default to proxied unless you have a reason not to. Reasons not to:

- Origin requires direct IP visibility (some webhook validators care about source IP)
- Cloudflare can't terminate TLS for the protocol (e.g., FTP, raw TCP)
- Compliance requires direct connection

## Cloudflare-specific quirks

### Cold-start latency is ~10ms

Vs Lambda's 100-300ms. This is the headline Workers advantage — eligible workloads should feel instant.

### Subrequest limits

Free tier: 50 subrequests per request. Paid: 1000. Each `fetch()` from a Worker counts. Don't accidentally fan out to 100s of subrequests.

### CPU time limits

Workers run on V8 isolates with strict CPU limits:
- Free: 10ms
- Paid: 50ms (default), up to 30s with config

If your handler runs ML inference or heavy parsing, consider Cloud Run or Lambda instead.

### Eventual consistency in KV

KV reads can return stale data for up to 60 seconds after writes (within a region; longer cross-region). For data that must be consistent immediately, use Durable Objects or D1.

### D1 limitations

D1 is SQLite-compatible but:
- Not all SQLite features supported (some pragmas, FTS5 quirks)
- Multi-region replication is async; reads can be stale
- Beta features change; check status before relying on advanced patterns

## Validation

`validate/manifest-dryrun.sh` for Workers:

```bash
wrangler deploy --dry-run --outdir dist > /tmp/wrangler-dryrun.txt
```

Catches: TypeScript errors, missing bindings referenced in code, invalid `wrangler.toml`.

## Common mistakes

- **Secrets in `wrangler.toml`** — they end up in your VCS. Use `wrangler secret`.
- **Hard-coding env-specific values in code** — use `env` bindings; values come from `wrangler.toml` per-env section.
- **Hitting subrequest limit** — fan-out patterns work, fan-out-of-fan-outs don't
- **Treating KV as fast database** — eventual consistency; consider D1 for relational, Durable Objects for strong consistency
- **Forgetting the proxied / DNS-only distinction** — major behaviour differences
- **Deploying without `--env`** — defaults to a "default" env that may not have your vars/secrets configured

## Cost considerations

- **Workers**: Free tier generous (100K requests/day); Paid $5/mo + per-req past quotas. Compute time matters more than request count at scale.
- **Pages**: Static is free; Pages Functions has Workers-equivalent pricing
- **R2**: storage cheap; no egress fees (vs S3's $0.09/GB) — major cost win for high-bandwidth use cases
- **KV**: free tier covers most use cases; paid tier reasonable
- **D1**: still in beta-ish state; pricing may shift

For most applications, Cloudflare's pricing is favourable. The exception is if you have very heavy compute per request — that's where Cloud Run / Lambda starts to compete.
