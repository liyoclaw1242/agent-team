#!/usr/bin/env bash
# typecheck.sh — TypeScript type check.

set -euo pipefail

if [[ -n "${FE_TYPECHECK_CMD:-}" ]]; then
  echo "Running custom typecheck: $FE_TYPECHECK_CMD"
  bash -c "$FE_TYPECHECK_CMD"
  exit $?
fi

if [[ -f "package.json" ]] && grep -q '"typecheck"\|"type-check"' package.json; then
  echo "Running: npm run typecheck (or type-check)"
  npm run typecheck 2>/dev/null || npm run type-check
elif command -v tsc >/dev/null; then
  echo "Running: tsc --noEmit"
  tsc --noEmit
else
  echo "skip: no typecheck tooling detected"
fi
