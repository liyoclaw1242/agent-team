#!/bin/bash
# FE validation pipeline — frontend-specific checks
# Exit code: 0 = all pass, non-zero = failures found
set -e

FAILURES=0

echo "═══ FE Validation Pipeline ═══"

# 1. Type check
echo "── TypeScript ──"
if [ -f "tsconfig.json" ]; then
  npx tsc --noEmit 2>&1 || { echo "FAIL: Type errors found"; FAILURES=$((FAILURES+1)); }
else
  echo "SKIP: No tsconfig.json"
fi

# 2. Lint
echo "── Lint ──"
if [ -f "package.json" ] && grep -q '"lint"' package.json 2>/dev/null; then
  if command -v pnpm &>/dev/null && [ -f "pnpm-lock.yaml" ]; then
    pnpm lint 2>&1 || { echo "FAIL: Lint failed"; FAILURES=$((FAILURES+1)); }
  else
    npm run lint 2>&1 || { echo "FAIL: Lint failed"; FAILURES=$((FAILURES+1)); }
  fi
else
  echo "SKIP: No lint script"
fi

# 3. Tests
echo "── Tests ──"
if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
  if command -v pnpm &>/dev/null && [ -f "pnpm-lock.yaml" ]; then
    pnpm test 2>&1 || { echo "FAIL: Tests failed"; FAILURES=$((FAILURES+1)); }
  else
    npm test 2>&1 || { echo "FAIL: Tests failed"; FAILURES=$((FAILURES+1)); }
  fi
else
  echo "SKIP: No test script"
fi

# 4. Accessibility
echo "── Accessibility ──"
# Check for div-as-button anti-pattern
A11Y_DIV=$(git diff origin/main 2>/dev/null | grep "^+" | grep -E '<div.*onClick|<span.*onClick' || true)
if [ -n "$A11Y_DIV" ]; then
  echo "FAIL: div/span with onClick detected — use <button> or add role=\"button\":"
  echo "$A11Y_DIV"
  FAILURES=$((FAILURES+1))
fi

# Check for images without alt
A11Y_IMG=$(git diff origin/main 2>/dev/null | grep "^+" | grep '<img' | grep -v 'alt=' || true)
if [ -n "$A11Y_IMG" ]; then
  echo "FAIL: <img> without alt attribute:"
  echo "$A11Y_IMG"
  FAILURES=$((FAILURES+1))
fi

# 5. Security
echo "── Security ──"
XSS=$(git diff origin/main 2>/dev/null | grep "^+" | grep 'dangerouslySetInnerHTML' || true)
if [ -n "$XSS" ]; then
  echo "WARN: dangerouslySetInnerHTML found — ensure content is sanitized:"
  echo "$XSS"
fi

SECRETS=$(grep -rn "sk-\|ghp_\|AKIA" --include="*.ts" --include="*.tsx" . 2>/dev/null | grep -v node_modules | grep -v .venv | grep -v ".test." || true)
if [ -n "$SECRETS" ]; then
  echo "FAIL: Potential secrets in source:"
  echo "$SECRETS"
  FAILURES=$((FAILURES+1))
fi

# 6. Code quality
echo "── Code Quality ──"
CONSOLE=$(git diff origin/main 2>/dev/null | grep "^+" | grep "console\.log" | grep -v "// debug" || true)
if [ -n "$CONSOLE" ]; then
  echo "WARN: console.log in diff (remove before merge):"
  echo "$CONSOLE"
fi

ANY_TYPE=$(git diff origin/main 2>/dev/null | grep "^+" | grep -E ': any\b|as any' || true)
if [ -n "$ANY_TYPE" ]; then
  echo "WARN: 'any' type found — prefer explicit types:"
  echo "$ANY_TYPE" | head -5
fi

# 7. Tailwind / styling
echo "── Styling ──"
HARDCODED=$(git diff origin/main 2>/dev/null | grep "^+" | grep -E 'style=\{|style={{' | head -5 || true)
if [ -n "$HARDCODED" ]; then
  echo "WARN: Inline styles found — prefer Tailwind classes:"
  echo "$HARDCODED"
fi

# 8. Git hygiene
echo "── Git ──"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "Branch: $BRANCH"

BAD_COMMITS=$(git log origin/main..HEAD --format="%s" 2>/dev/null | grep -cvE "^(feat|fix|docs|design|test|chore):" || true)
if [ "$BAD_COMMITS" -gt 0 ] 2>/dev/null; then
  echo "FAIL: $BAD_COMMITS commit(s) with bad message format:"
  git log origin/main..HEAD --format="%s" 2>/dev/null | grep -vE "^(feat|fix|docs|design|test|chore):"
  FAILURES=$((FAILURES+1))
fi

echo "═══ Results: $FAILURES failure(s) ═══"
exit $FAILURES
