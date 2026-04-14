#!/bin/bash
# OPS Preflight — verify CLI tools, auth, and project linkage before any deploy action
# Usage: bash validate/preflight.sh [project_dir]
# Exit code: 0 = ready, 1 = not ready
set -e

PROJECT_DIR="${1:-.}"
FAILURES=0
WARNINGS=0

echo "═══ OPS Preflight Check ═══"
echo "Project: $PROJECT_DIR"
echo ""

# ── CLI Tools ──
echo "── CLI Tools ──"

check_cli() {
  local name="$1"
  local cmd="$2"
  if command -v "$cmd" &>/dev/null; then
    echo "  ✓ $name"
  else
    echo "  ✗ $name — not installed"
    FAILURES=$((FAILURES+1))
  fi
}

check_cli "GitHub CLI" "gh"
check_cli "Vercel CLI" "vercel"
check_cli "Fly.io CLI" "fly"
check_cli "Turso CLI" "turso"
check_cli "Docker" "docker"

echo ""

# ── Auth Status ──
echo "── Auth Status ──"

check_auth() {
  local name="$1"
  local cmd="$2"
  local result
  result=$(eval "$cmd" 2>&1) && {
    echo "  ✓ $name → $result"
  } || {
    echo "  ✗ $name — not logged in"
    FAILURES=$((FAILURES+1))
  }
}

check_auth "GitHub" "gh auth status 2>&1 | grep 'Logged in' | head -1 | sed 's/.*account //' | sed 's/ .*//' || false"
command -v vercel &>/dev/null && check_auth "Vercel" "vercel whoami 2>/dev/null"
command -v fly &>/dev/null && check_auth "Fly.io" "fly auth whoami 2>/dev/null"
command -v turso &>/dev/null && check_auth "Turso" "turso auth whoami 2>/dev/null"

echo ""

# ── Project Linkage ──
echo "── Project Linkage ──"

# Vercel
if [ -f "$PROJECT_DIR/.vercel/project.json" ]; then
  VERCEL_PROJECT=$(grep -o '"projectName":"[^"]*"' "$PROJECT_DIR/.vercel/project.json" 2>/dev/null | cut -d'"' -f4)
  echo "  ✓ Vercel → $VERCEL_PROJECT"
else
  echo "  – Vercel — not linked (run: vercel link)"
  WARNINGS=$((WARNINGS+1))
fi

# Fly.io
if [ -f "$PROJECT_DIR/fly.toml" ]; then
  FLY_APP=$(grep -m1 "^app" "$PROJECT_DIR/fly.toml" 2>/dev/null | sed 's/app = //' | tr -d '"' | tr -d "'" | xargs)
  echo "  ✓ Fly.io → $FLY_APP"
else
  echo "  – Fly.io — no fly.toml found"
  WARNINGS=$((WARNINGS+1))
fi

# Git remote
if git -C "$PROJECT_DIR" remote -v &>/dev/null; then
  REMOTE=$(git -C "$PROJECT_DIR" remote get-url origin 2>/dev/null)
  echo "  ✓ Git remote → $REMOTE"
else
  echo "  ✗ Git — no remote configured"
  FAILURES=$((FAILURES+1))
fi

echo ""

# ── Environment Variables ──
echo "── Environment Variables ──"

check_env_file() {
  local env_file="$1"
  if [ -f "$PROJECT_DIR/$env_file" ]; then
    echo "  ✓ $env_file exists"
  else
    echo "  – $env_file not found"
    WARNINGS=$((WARNINGS+1))
  fi
}

check_env_file ".env.local"
check_env_file ".env"

# Check for required vars in env files (if they exist)
for env_file in ".env.local" ".env"; do
  if [ -f "$PROJECT_DIR/$env_file" ]; then
    # Check Turso vars
    grep -q "TURSO_DATABASE_URL\|LIBSQL_URL" "$PROJECT_DIR/$env_file" 2>/dev/null || {
      echo "  – $env_file: missing TURSO_DATABASE_URL"
      WARNINGS=$((WARNINGS+1))
    }
    break
  fi
done

echo ""

# ── Docker ──
echo "── Docker ──"
if command -v docker &>/dev/null; then
  if docker info &>/dev/null; then
    echo "  ✓ Docker daemon running"
  else
    echo "  ✗ Docker daemon not running (try: orb start)"
    FAILURES=$((FAILURES+1))
  fi
else
  echo "  – Docker not installed"
  WARNINGS=$((WARNINGS+1))
fi

echo ""
echo "═══ Preflight: $FAILURES failure(s), $WARNINGS warning(s) ═══"

if [ $FAILURES -gt 0 ]; then
  echo "❌ Not ready to deploy. Fix failures above."
  exit 1
else
  if [ $WARNINGS -gt 0 ]; then
    echo "⚠️  Ready with warnings. Some services may not be configured."
  else
    echo "✅ All clear. Ready to deploy."
  fi
  exit 0
fi
