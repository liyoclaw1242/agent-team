#!/usr/bin/env bash
# test.sh — BE tests with race detector.

set -euo pipefail

if [[ -n "${BE_TEST_CMD:-}" ]]; then
  bash -c "$BE_TEST_CMD"
  exit $?
fi

if [[ -f "go.mod" ]]; then
  echo "Running: go test -race -cover ./..."
  go test -race -cover ./...

  # Extract coverage and check threshold
  threshold="${BE_COVERAGE_THRESHOLD:-80}"
  coverage=$(go test -cover ./... 2>&1 | grep -oE 'coverage: [0-9.]+%' | head -n1 | grep -oE '[0-9.]+' || echo 0)
  if [[ -n "$coverage" ]]; then
    # Strip decimals for shell comparison
    coverage_int=${coverage%.*}
    if [[ "$coverage_int" -lt "$threshold" ]]; then
      echo "warn: coverage $coverage% below threshold $threshold%"
      echo "(self-test record must include rationale)"
    fi
  fi
elif [[ -f "package.json" ]] && grep -q '"test"' package.json; then
  echo "Running: npm test"
  CI=1 npm test --if-present
else
  echo "skip: no recognised test setup"
fi
