#!/usr/bin/env bash
# lint.sh — eslint + prettier check for FE skill.
#
# Run by check-all.sh during validation phase. Each project may have its own
# eslint/prettier config; this script invokes the project's tooling rather
# than imposing settings.
#
# Tunable via env:
#   FE_LINT_PATHS — space-separated paths to lint (default: src/)
#   FE_LINT_CMD — override the entire lint command

set -euo pipefail

paths="${FE_LINT_PATHS:-src/}"

if [[ -n "${FE_LINT_CMD:-}" ]]; then
  echo "Running custom lint command: $FE_LINT_CMD"
  bash -c "$FE_LINT_CMD"
  exit $?
fi

# Try common project layouts
if [[ -f "package.json" ]] && grep -q '"lint"' package.json; then
  echo "Running: npm run lint"
  npm run lint
elif command -v eslint >/dev/null && command -v prettier >/dev/null; then
  echo "Running: eslint + prettier on $paths"
  eslint --max-warnings=0 $paths
  prettier --check $paths
else
  echo "skip: no lint tooling detected (no npm script, no eslint+prettier in PATH)"
  echo "set FE_LINT_CMD if your project uses something else"
fi
