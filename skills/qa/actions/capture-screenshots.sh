#!/bin/bash
# Capture screenshots of running app at multiple breakpoints
# Usage: capture-screenshots.sh <BASE_URL> <OUTPUT_DIR> [routes...]
#
# Example:
#   capture-screenshots.sh http://localhost:3000 /tmp/screenshots / /dashboard /settings
#
# Requires: npx playwright (auto-installs if needed)
set -e

BASE_URL="${1:?Usage: capture-screenshots.sh <BASE_URL> <OUTPUT_DIR> [routes...]}"
OUTPUT_DIR="${2:?Output directory required}"
shift 2
ROUTES=("${@:-/}")

# Default routes if none provided
if [ ${#ROUTES[@]} -eq 0 ]; then
  ROUTES=("/")
fi

mkdir -p "$OUTPUT_DIR"

# Breakpoints: mobile, tablet, desktop
VIEWPORTS=(
  "320x568:mobile"
  "768x1024:tablet"
  "1280x800:desktop"
)

# Generate Playwright script
SCRIPT_FILE="$OUTPUT_DIR/_capture.mjs"

cat > "$SCRIPT_FILE" << 'PLAYWRIGHT_SCRIPT'
import { chromium } from "playwright";

const baseUrl = process.argv[2];
const outputDir = process.argv[3];
const routes = process.argv.slice(4);

const viewports = [
  { width: 320, height: 568, name: "mobile" },
  { width: 768, height: 1024, name: "tablet" },
  { width: 1280, height: 800, name: "desktop" },
];

async function main() {
  const browser = await chromium.launch();

  for (const route of routes) {
    for (const vp of viewports) {
      const page = await browser.newPage({
        viewport: { width: vp.width, height: vp.height },
      });

      const url = `${baseUrl}${route}`;
      const slug = route === "/" ? "home" : route.replace(/\//g, "-").replace(/^-/, "");
      const filename = `${slug}_${vp.name}.png`;

      try {
        await page.goto(url, { waitUntil: "networkidle", timeout: 15000 });
        // Wait a bit for animations/transitions
        await page.waitForTimeout(1000);
        await page.screenshot({ path: `${outputDir}/${filename}`, fullPage: true });
        console.log(`OK: ${filename}`);
      } catch (err) {
        console.log(`FAIL: ${filename} — ${err.message}`);
      }

      await page.close();
    }
  }

  await browser.close();
}

main();
PLAYWRIGHT_SCRIPT

# Ensure Playwright is available
npx playwright install chromium --with-deps 2>/dev/null || true

# Run capture
node "$SCRIPT_FILE" "$BASE_URL" "$OUTPUT_DIR" "${ROUTES[@]}"

# Clean up script
rm -f "$SCRIPT_FILE"

# List captured screenshots
echo ""
echo "═══ Screenshots captured ═══"
ls -la "$OUTPUT_DIR"/*.png 2>/dev/null || echo "No screenshots captured"
echo ""
echo "Screenshots saved to: $OUTPUT_DIR"
