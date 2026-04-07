#!/bin/bash
# BE validation pipeline — runs all rule checks in sequence
# Exit code: 0 = all pass, 1 = failures found
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
FAILURES=0

echo "═══ BE Validation Pipeline ═══"

# 1. Testing
echo "── Testing ──"
if [ -f "package.json" ] && grep -q '"test"' package.json 2>/dev/null; then
  pnpm test 2>&1 || npm test 2>&1 || { echo "FAIL: Tests failed"; FAILURES=$((FAILURES+1)); }
else
  echo "SKIP: No test script found"
fi

# 2. Lint
echo "── Code Quality ──"
if [ -f "package.json" ] && grep -q '"lint"' package.json 2>/dev/null; then
  pnpm lint 2>&1 || npm run lint 2>&1 || { echo "FAIL: Lint failed"; FAILURES=$((FAILURES+1)); }
else
  echo "SKIP: No lint script found"
fi

# 3. Security checks
echo "── Security ──"
SECRETS=$(grep -rn "sk-\|ghp_\|AKIA\|password\s*=\s*['\"]" --include="*.ts" --include="*.js" . 2>/dev/null | grep -v node_modules | grep -v .venv | grep -v ".test." || true)
if [ -n "$SECRETS" ]; then
  echo "FAIL: Potential secrets found:"
  echo "$SECRETS"
  FAILURES=$((FAILURES+1))
fi

SQL_INJECT=$(grep -rn 'query.*`.*\${' --include="*.ts" --include="*.js" . 2>/dev/null | grep -v node_modules | grep -v .venv | grep -v ".test." || true)
if [ -n "$SQL_INJECT" ]; then
  echo "FAIL: Potential SQL injection:"
  echo "$SQL_INJECT"
  FAILURES=$((FAILURES+1))
fi

# 4. Git hygiene
echo "── Git ──"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "$BRANCH" | grep -qE "^agent/" || echo "WARN: Branch doesn't follow agent/ pattern"

git log origin/main..HEAD --format="%s" 2>/dev/null | while read msg; do
  echo "$msg" | grep -qE "^(feat|fix|docs|design|test|chore):" || echo "FAIL: Bad commit message: $msg"
done

# 5. Performance (N+1 detection)
echo "── Performance ──"
N1=$(git diff origin/main 2>/dev/null | grep "^+" | grep -E "\.map\(.*=>.*find|\.forEach\(.*=>.*find" || true)
if [ -n "$N1" ]; then
  echo "WARN: Potential N+1 query pattern:"
  echo "$N1"
fi

echo "═══ Results: $FAILURES failure(s) ═══"
exit $FAILURES
