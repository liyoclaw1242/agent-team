# Case — Vercel Frontend Deployment

OPS owns Vercel: configuration, preview environments, custom domains, redirects, ISR, edge config. FE writes the application code; OPS decides how it's deployed.

## What Vercel handles natively

For Next.js / Nuxt / SvelteKit / Astro / Remix:
- Build artefact construction (zero config typical)
- Edge deployment (CDN + edge functions)
- Preview environments per PR (automatic)
- Custom domains + TLS (one-click)
- Server-side rendering, ISR, edge functions (framework-aware)
- Automatic image optimisation
- Analytics

OPS's Vercel work is mostly: project setup, environment variables, domain config, redirects, advanced caching, monorepo config.

## Project setup via vercel.json

For most projects, default Vercel config works. When you need overrides, `vercel.json`:

```json
{
  "$schema": "https://openapi.vercel.sh/vercel.json",
  "framework": "nextjs",
  "buildCommand": "npm run build",
  "outputDirectory": ".next",
  "installCommand": "npm ci",
  "regions": ["iad1", "sfo1"],
  "functions": {
    "app/api/cancel/route.ts": {
      "maxDuration": 30
    }
  },
  "headers": [
    {
      "source": "/api/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "no-store, max-age=0" }
      ]
    },
    {
      "source": "/_next/static/(.*)",
      "headers": [
        { "key": "Cache-Control", "value": "public, max-age=31536000, immutable" }
      ]
    }
  ],
  "redirects": [
    { "source": "/old-billing", "destination": "/billing", "permanent": true }
  ],
  "rewrites": [
    { "source": "/api/upstream/:path*", "destination": "https://upstream.example.com/:path*" }
  ]
}
```

### What's worth setting

**`regions`**: explicit region selection. Default is `iad1` (Washington DC). Multi-region adds resilience but also cost; only set if you've decided you need it.

**`functions.<path>.maxDuration`**: per-function execution time limit. Hobby plan: 10s; Pro: 60s; Enterprise: 900s. Set to actual need; don't max it out (longer timeouts = slower fail visibility).

**`headers`** for cache control: most static asset caching is automatic; explicit headers for API responses prevent CDN caching of dynamic responses.

**`redirects`** vs **`rewrites`**:
- Redirect: 301/302 to a different URL (browser sees the new URL)
- Rewrite: server-side path rewrite (browser sees the original URL)

Use redirects for permanent URL changes; rewrites for proxying or path remapping.

## Preview environments

Every PR gets a unique preview URL automatically. To customise:

```json
{
  "git": {
    "deploymentEnabled": {
      "main": true,
      "develop": false
    }
  }
}
```

Common pattern: make the preview reachable in a `pr-NUMBER.preview.example.com` format via a wildcard CNAME and Vercel's domain config:

1. CNAME `*.preview.example.com` → `cname.vercel-dns.com`
2. In Vercel project settings → Domains, add `*.preview.example.com` with "Apply to all preview deployments"
3. Configure auto-assignment via Vercel's deployment hooks

Now PR #501's preview is at `pr-501.preview.example.com`. Useful for QA review, stakeholder feedback, and link-sharing without the auto-generated long URL.

## Environment variables

Vercel has three env scopes: Development, Preview, Production. Each can hold different values for the same name.

```bash
# Set production env var
vercel env add API_BASE_URL production
# (paste value when prompted)

# Set preview env var (different value)
vercel env add API_BASE_URL preview
# (paste different value, e.g., staging URL)

# Read all
vercel env ls
```

For secrets specifically, use the platform's secrets store (Vercel handles encryption at rest for env vars; for higher security, use linked external secret stores).

### Env var reference in code

Public vars (exposed to browser): `NEXT_PUBLIC_*` prefix in Next.js. Private vars: any other name; only available in server-side code.

Don't put secrets behind `NEXT_PUBLIC_*` — they end up in the client bundle, visible to anyone.

## Custom domains

Adding `cancel-app.example.com`:

1. In Vercel project → Domains → Add `cancel-app.example.com`
2. Vercel shows DNS records to add. Two options:
   - CNAME `cancel-app` → `cname.vercel-dns.com`
   - Or A record to Vercel's IPs (less common; use CNAME unless apex)
3. Add the DNS record at your DNS provider
4. TLS cert provisioned automatically within minutes
5. Domain is live

For **apex domains** (`example.com`), CNAME isn't valid per RFC; use ALIAS/ANAME if your DNS provider supports it (Cloudflare, Route53 do), or use Vercel's A records.

## ISR and edge config

For Next.js sites:

### ISR (Incremental Static Regeneration)

Pages can be statically generated and revalidated periodically:

```tsx
// app/blog/[slug]/page.tsx
export const revalidate = 3600;  // regenerate at most once an hour

export default async function BlogPost({ params }) {
  const post = await fetchPost(params.slug);
  return <article>{post.content}</article>;
}
```

The page is served from CDN as static; in the background, revalidation refreshes it on the configured interval. Best of both worlds: speed + freshness.

### Edge runtime

For request-time logic that needs to be very fast (auth check, geolocation, A/B assignment):

```tsx
// app/api/edge-cancel/route.ts
export const runtime = 'edge';

export async function POST(req: Request) {
  // runs at the edge near the user
}
```

Edge functions:
- Faster cold start (~10ms vs ~200ms for serverless)
- Limited Node API (no `fs`, etc.)
- Lower max payload size
- Run in V8 isolates, not Node

Use edge for pure compute; use Node runtime for handlers that need filesystem, native modules, or long timeouts.

## Monorepo config

If your repo has multiple apps:

```
repo/
├── apps/
│   ├── web/        Next.js
│   └── docs/       Astro
└── packages/
    └── ui/         shared
```

Vercel project per app, each with `Root Directory: apps/web` (or `apps/docs`). Vercel builds only the relevant app per PR (with proper `vercel.json` in each app dir).

For shared packages, add `Ignored Build Step`:

```bash
# In Vercel project settings → Git → Ignored Build Step:
git diff HEAD^ HEAD --quiet -- apps/web packages/ui
```

If no changes affecting `apps/web` or `packages/ui`, skip the build.

## Deploy from CI

Default Vercel Git integration auto-deploys on push. To deploy from your own CI:

```yaml
# .github/workflows/deploy-vercel.yml
on:
  push:
    branches: [main]
  pull_request:

jobs:
  deploy:
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
```

This gives you control over when deploys happen (e.g., gate behind tests, do branch-specific environments).

## Caching pitfalls

### Pitfall: API routes accidentally cached

By default, Vercel caches GET responses from API routes if the response sets cache headers. If you want fresh data:

```typescript
export async function GET() {
  return new Response(JSON.stringify(data), {
    headers: { 'Cache-Control': 'no-store, max-age=0' }
  });
}
```

Or in `vercel.json` headers section.

### Pitfall: cookies bypass cache

API responses with `Set-Cookie` headers are not cached. So setting auth cookies inadvertently disables CDN caching.

For caching API responses with auth, use `stale-while-revalidate`:

```
Cache-Control: s-maxage=10, stale-while-revalidate=60
```

CDN serves cached response for 10s, then stale for up to 60s while fetching fresh.

### Pitfall: rewrites and caching

Rewrites can be cached at the edge or not, depending on the destination. Test what's actually being cached via response headers (`X-Vercel-Cache: HIT|MISS`).

## Dry-run / preview

Vercel doesn't have a perfect "dry-run" mode for arbitrary changes. Closest:

```bash
# Build artefact validation
vercel build

# Preview deploy (always available; just doesn't go to prod)
vercel deploy
```

For `vercel.json` validation, the JSON schema (`$schema` reference) gives editor-time validation. CI can:

```bash
npx jsonschema -i vercel.json https://openapi.vercel.sh/vercel.json
```

For risky config changes, deploy to a non-prod project first as smoke test.

## Common mistakes

- **Leaking secrets via `NEXT_PUBLIC_*`** — exposed to browser; treat as public
- **Setting `regions` randomly** — pick based on user geography; otherwise stick with default (Vercel routes intelligently)
- **`maxDuration` set to maximum** — slower failure visibility; set to actual need + buffer
- **No staging environment** — preview URLs are great but ephemeral; sometimes you want a stable staging
- **Custom domain config without testing** — TLS provisioning failures are obvious; CNAME issues less so
- **Deploys from local laptop** — use CI; laptops are not auditable
- **Letting Vercel manage the GitHub integration without team awareness** — when an integration breaks, only the original setter-up knows

## Cost considerations

Vercel pricing scales with:
- Bandwidth (egress data)
- Function execution time
- Build minutes (Pro tier and above)
- Image optimisation (per source image transformed)

If your site has large media or high traffic, Cloudflare Pages or self-hosted may be cheaper. For most product apps, Vercel's pricing is reasonable; do the math at projected scale before committing.
