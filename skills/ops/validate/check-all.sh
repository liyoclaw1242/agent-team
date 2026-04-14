#!/bin/bash
# OPS validation pipeline — preflight + infra-specific checks
# Exit code: 0 = all pass, 1 = failures found
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILL_DIR="$(dirname "$SCRIPT_DIR")"
FAILURES=0

echo "═══ OPS Validation Pipeline ═══"

# 0. Preflight
echo "── Preflight ──"
bash "$SCRIPT_DIR/preflight.sh" "$PWD" || FAILURES=$((FAILURES+1))

# 1. Security — no secrets in tracked files
echo "── Security ──"
SECRETS=$(grep -rn "sk-\|ghp_\|AKIA\|password\s*=\s*['\"]" --include="*.ts" --include="*.js" --include="*.go" --include="*.toml" --include="*.yaml" --include="*.yml" . 2>/dev/null | grep -v node_modules | grep -v .venv | grep -v ".test." | grep -v ".env" || true)
if [ -n "$SECRETS" ]; then
  echo "FAIL: Potential secrets in tracked files:"
  echo "$SECRETS"
  FAILURES=$((FAILURES+1))
fi

# Check .gitignore covers sensitive files
for sensitive in ".env" ".env.local" ".env.production"; do
  if [ -f ".gitignore" ]; then
    grep -qF "$sensitive" .gitignore 2>/dev/null || {
      echo "WARN: $sensitive not in .gitignore"
    }
  fi
done

# 2. Docker — validate Dockerfile if present
echo "── Docker ──"
for dockerfile in $(find . -name "Dockerfile" -not -path "*/node_modules/*" 2>/dev/null); do
  echo "  Checking $dockerfile"
  # Non-root user check
  grep -q "USER\|useradd\|adduser" "$dockerfile" 2>/dev/null || echo "  WARN: $dockerfile — no non-root USER directive"
  # Multi-stage check
  grep -cq "^FROM" "$dockerfile" 2>/dev/null && {
    STAGES=$(grep -c "^FROM" "$dockerfile")
    [ "$STAGES" -lt 2 ] && echo "  WARN: $dockerfile — single-stage build, consider multi-stage"
  }
done

# 3. Fly.io — validate fly.toml if present
echo "── Fly.io ──"
if [ -f "fly.toml" ]; then
  grep -q "\[http_service\]\|internal_port" fly.toml 2>/dev/null || echo "WARN: fly.toml — no http_service configured"
  grep -q "\[checks\]\|health" fly.toml 2>/dev/null || echo "WARN: fly.toml — no health check configured"
fi

# 4. Git hygiene
echo "── Git ──"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "$BRANCH" | grep -qE "^agent/" || echo "WARN: Branch doesn't follow agent/ pattern"

git log origin/main..HEAD --format="%s" 2>/dev/null | while read msg; do
  echo "$msg" | grep -qE "^(feat|fix|docs|design|test|chore):" || echo "FAIL: Bad commit message: $msg"
done

echo "═══ Results: $FAILURES failure(s) ═══"
exit $FAILURES
