#!/usr/bin/env bash
# a11y.sh — axe-core accessibility scan.
#
# Note: full a11y verification often requires a running app instance.
# This script handles two modes:
#   - Static: lint-style checks for known anti-patterns (run always)
#   - Dynamic: axe-core via Playwright/Puppeteer if FE_A11Y_DYNAMIC=1 (assumes
#     app is running on FE_A11Y_URL, default http://localhost:3000)

set -euo pipefail

# ─── Static checks (always run) ─────────────────────────────────────────────
echo "Static a11y checks:"

errors=0

# Anti-pattern: dangerouslySetInnerHTML without sanitization
if grep -rn "dangerouslySetInnerHTML" --include="*.tsx" --include="*.jsx" src/ 2>/dev/null \
     | grep -v "DOMPurify" | grep -v "sanitize" | grep -q .; then
  echo "  ✗ dangerouslySetInnerHTML found without DOMPurify/sanitize"
  errors=$((errors + 1))
fi

# Anti-pattern: outline:none without replacement
if grep -rn "outline:\s*none\|outline:0" --include="*.css" --include="*.tsx" src/ 2>/dev/null \
     | grep -q .; then
  echo "  warn: 'outline: none' found — verify a focus indicator is provided"
fi

# Missing alt attributes (rough check)
missing_alt=$(grep -rn "<img " --include="*.tsx" --include="*.jsx" src/ 2>/dev/null \
                | grep -v "alt=" | wc -l)
if [[ "$missing_alt" -gt 0 ]]; then
  echo "  ✗ $missing_alt <img> tags without alt attribute"
  errors=$((errors + 1))
fi

[[ $errors -eq 0 ]] && echo "  ✓ static a11y checks passed"

# ─── Dynamic check (opt-in) ─────────────────────────────────────────────────
if [[ "${FE_A11Y_DYNAMIC:-0}" == "1" ]]; then
  url="${FE_A11Y_URL:-http://localhost:3000}"
  echo ""
  echo "Dynamic axe-core scan against $url:"

  if command -v npx >/dev/null && npx --no-install axe --version >/dev/null 2>&1; then
    npx axe "$url" --exit
  else
    echo "  skip: @axe-core/cli not available (npm i -D @axe-core/cli to enable)"
  fi
fi

[[ $errors -eq 0 ]] && exit 0 || exit 1
