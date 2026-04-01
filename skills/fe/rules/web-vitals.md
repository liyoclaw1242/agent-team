# Rule: Web Performance (Web Vitals)

**Activation**: This rule is NOT checked by default in every task. It activates when:
- The task spec mentions performance, speed, or Core Web Vitals
- The final validation phase of a page-level or layout-level change
- Explicitly requested by the user or QA

## Thresholds (Core Web Vitals)

| Metric | Good | Needs Improvement | Poor |
|--------|------|--------------------|------|
| **LCP** (Largest Contentful Paint) | ≤ 2.5s | ≤ 4.0s | > 4.0s |
| **CLS** (Cumulative Layout Shift) | ≤ 0.1 | ≤ 0.25 | > 0.25 |
| **INP** (Interaction to Next Paint) | ≤ 200ms | ≤ 500ms | > 500ms |
| **FCP** (First Contentful Paint) | ≤ 1.8s | ≤ 3.0s | > 3.0s |
| **TTFB** (Time to First Byte) | ≤ 800ms | ≤ 1800ms | > 1800ms |

Target: ALL metrics in "Good" range.

## Common Violations & Fixes

### LCP

| Cause | Fix |
|-------|-----|
| Unoptimized hero image | `next/image` with `priority`, proper `sizes` attr |
| Render-blocking CSS/JS | Inline critical CSS, defer non-critical |
| Slow server response | Check TTFB first, add caching headers |
| Client-side rendering of above-fold content | Use SSR/SSG for initial render |

### CLS

| Cause | Fix |
|-------|-----|
| Images without dimensions | Always set `width`/`height` or use `aspect-ratio` |
| Dynamic content injection | Reserve space with skeleton/placeholder |
| Web fonts causing FOUT | `font-display: swap` + preload font files |
| Ads / embeds without size | Container with fixed aspect-ratio |

### INP

| Cause | Fix |
|-------|-----|
| Heavy click handlers | Debounce, offload to Web Worker |
| Large re-renders | `React.memo`, `useMemo`, split components |
| Synchronous DOM operations | `requestAnimationFrame`, `startTransition` |

## Validation

```bash
# Build and analyze bundle
if [ -f "next.config.js" ] || [ -f "next.config.mjs" ] || [ -f "next.config.ts" ]; then
  ANALYZE=true pnpm build 2>&1 | tail -20
fi

# Check for common CLS causes in diff
echo "── CLS checks ──"
git diff origin/main | grep "^+" | grep -E '<img' | grep -v 'width=\|height=\|fill\b' || true

# Check for priority on hero images
echo "── LCP checks ──"
git diff origin/main | grep "^+" | grep -E 'Image.*hero\|Image.*banner' | grep -v 'priority' || true

# Check for layout shift patterns
echo "── Dynamic content ──"
git diff origin/main | grep "^+" | grep -E 'useState.*\[\]|useState.*null' | head -5 || true
```
