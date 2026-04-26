#!/usr/bin/env bash
# secrets-leak.sh — gitleaks scan for committed secrets.
#
# Run on the current branch's commits (vs main). Catches accidentally
# committed API keys, passwords, etc.

set -euo pipefail

if ! command -v gitleaks >/dev/null; then
  echo "warn: gitleaks not installed (https://github.com/gitleaks/gitleaks)"
  echo "skipping secrets scan"
  exit 0
fi

# Determine base branch
default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo "main")

# Scan commits on this branch only (avoid scanning all history)
echo "gitleaks scan (commits since origin/$default_branch)..."

if ! gitleaks detect --no-banner \
     --source . \
     --log-opts="origin/$default_branch..HEAD" \
     --redact \
     --exit-code 1; then
  echo ""
  echo "✗ secrets detected in commit history" >&2
  echo "  See gitleaks output above; rotate any leaked secrets per rules/secrets-discipline.md" >&2
  exit 1
fi

# Also scan working tree (uncommitted changes)
echo "gitleaks scan (working tree)..."
if ! gitleaks detect --no-banner \
     --source . \
     --no-git \
     --redact \
     --exit-code 1; then
  echo ""
  echo "✗ secrets detected in working tree" >&2
  exit 1
fi

echo "secrets-leak: ok"
