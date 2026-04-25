#!/usr/bin/env bash
# test.sh — unit + component tests.

set -euo pipefail

if [[ -n "${FE_TEST_CMD:-}" ]]; then
  bash -c "$FE_TEST_CMD"
  exit $?
fi

if [[ -f "package.json" ]] && grep -q '"test"' package.json; then
  echo "Running: npm test"
  # CI-mode: don't watch, fail on no tests
  CI=1 npm test --if-present
else
  echo "skip: no test tooling detected"
fi
