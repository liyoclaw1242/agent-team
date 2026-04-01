# Rule: SEO

**Activation**: This rule activates when:
- The task involves page creation or modification
- The task spec mentions SEO, metadata, or search
- Working on public-facing pages (not admin/dashboard)

## Rules

### Metadata (every page)

1. **Title**: unique per page, ≤ 60 chars, primary keyword first
2. **Description**: unique per page, ≤ 155 chars, actionable copy
3. **Canonical URL**: set on every page to prevent duplicates
4. **Open Graph**: `og:title`, `og:description`, `og:image` for social sharing
5. **Viewport**: `<meta name="viewport" content="width=device-width, initial-scale=1">`

```tsx
// Next.js App Router metadata
export const metadata: Metadata = {
  title: "Page Title — Site Name",
  description: "Actionable description under 155 chars.",
  openGraph: {
    title: "Page Title",
    description: "...",
    images: ["/og-image.png"],
  },
  alternates: {
    canonical: "https://example.com/page",
  },
};
```

### Semantic HTML

| Element | Use for |
|---------|---------|
| `<main>` | Primary page content (one per page) |
| `<nav>` | Navigation sections |
| `<article>` | Self-contained content (blog post, card) |
| `<section>` | Thematic grouping with heading |
| `<aside>` | Tangentially related content |
| `<header>` / `<footer>` | Page or section header/footer |
| `<h1>` | One per page, describes the page |
| `<h2>`–`<h6>` | Logical hierarchy, no skipping levels |

### Technical SEO

1. **Heading hierarchy**: one `<h1>` per page, no skipped levels
2. **Image alt text**: descriptive for content images, empty for decorative
3. **Internal links**: use `<Link>` (Next.js) for client-side navigation
4. **Structured data**: JSON-LD for articles, products, FAQ where applicable
5. **Sitemap**: auto-generated via `next-sitemap` or framework equivalent
6. **robots.txt**: exists and allows indexing of public pages

## Validation

```bash
echo "── SEO checks ──"

# Check for pages without metadata export
git diff --name-only origin/main | grep -E 'page\.(tsx|ts)$' | while read f; do
  grep -q "metadata\|generateMetadata" "$f" || echo "WARN: No metadata in $f"
done

# Check heading hierarchy
git diff --name-only origin/main | grep -E '\.(tsx|jsx)$' | xargs grep -n '<h[1-6]' 2>/dev/null | head -10 || true

# Check for images without alt
git diff origin/main | grep "^+" | grep '<img\|<Image' | grep -v 'alt=' || true

# Check for hardcoded <a> instead of <Link>
git diff origin/main | grep "^+" | grep '<a ' | grep -v 'target=.*_blank\|rel=' | head -5 || true
```
