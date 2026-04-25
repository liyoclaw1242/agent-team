#!/usr/bin/env bash
# security.sh — BE-side security checks: injection patterns + dependency scan.

set -euo pipefail

errors=0

# ─── SQL injection patterns ────────────────────────────────────────────────
echo "Checking for raw SQL concatenation:"

# Patterns that suggest unsafe SQL construction
suspicious=$(grep -rEn \
  --include="*.go" --include="*.ts" --include="*.js" --include="*.py" \
  'fmt\.Sprintf.*("[A-Z ]*SELECT|"INSERT|"UPDATE|"DELETE)' . 2>/dev/null \
  | grep -v '_test\.go' \
  || true)

if [[ -n "$suspicious" ]]; then
  echo "  ✗ found SQL-string fmt.Sprintf patterns (likely injection vector):"
  echo "$suspicious" | sed 's/^/    /'
  errors=$((errors + 1))
fi

# JS/TS template literal SQL
suspicious_ts=$(grep -rEn \
  --include="*.ts" --include="*.js" \
  '\`(SELECT|INSERT|UPDATE|DELETE).*\$\{' . 2>/dev/null \
  | grep -v '\.test\.' \
  || true)

if [[ -n "$suspicious_ts" ]]; then
  echo "  ✗ found JS template-literal SQL with \${...} interpolation:"
  echo "$suspicious_ts" | sed 's/^/    /'
  errors=$((errors + 1))
fi

# ─── Command injection patterns ─────────────────────────────────────────────
echo "Checking for shell-out with user input:"

# os/exec.Command with concatenated args is a yellow flag
exec_concat=$(grep -rEn 'exec\.Command\(.*\+' --include="*.go" . 2>/dev/null \
                | grep -v '_test\.go' || true)
if [[ -n "$exec_concat" ]]; then
  echo "  warn: os/exec.Command with string concatenation — verify args are not user input"
fi

# ─── Dependency vulnerabilities ─────────────────────────────────────────────
echo "Dependency vulnerability scan:"

if [[ -f "go.mod" ]] && command -v govulncheck >/dev/null; then
  govulncheck ./... || errors=$((errors + 1))
elif [[ -f "go.mod" ]]; then
  echo "  warn: govulncheck not installed (go install golang.org/x/vuln/cmd/govulncheck@latest)"
fi

if [[ -f "package.json" ]]; then
  if command -v npm >/dev/null; then
    npm audit --audit-level=high || errors=$((errors + 1))
  fi
fi

# ─── Auth middleware check ──────────────────────────────────────────────────
# Project-specific; this is a placeholder you'd customise.
if grep -rE "^func.*Handler.*\(" --include="*.go" . 2>/dev/null | grep -v "_test\.go" | head -1 | grep -q .; then
  # Heuristic: handlers exist; ensure auth middleware is used somewhere
  if ! grep -rE "Use\(.*[Aa]uth|requireAuth|authMiddleware" --include="*.go" . 2>/dev/null | head -1 | grep -q .; then
    echo "  warn: handlers exist but no auth middleware usage detected — verify auth is applied"
  fi
fi

echo ""
[[ $errors -eq 0 ]] && echo "security checks: passed" && exit 0
echo "security checks: $errors issue(s)" >&2
exit 1
