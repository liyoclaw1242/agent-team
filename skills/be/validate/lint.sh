#!/usr/bin/env bash
# lint.sh — Go-flavoured: go vet + staticcheck + gofumpt.
# Falls back to project's `npm run lint` if BE is TS-based.

set -euo pipefail

if [[ -n "${BE_LINT_CMD:-}" ]]; then
  bash -c "$BE_LINT_CMD"
  exit $?
fi

# Detect Go vs Node project
if [[ -f "go.mod" ]]; then
  echo "Go project detected. Running go vet + staticcheck + gofumpt"
  go vet ./...
  if command -v staticcheck >/dev/null; then
    staticcheck ./...
  else
    echo "warn: staticcheck not installed (go install honnef.co/go/tools/cmd/staticcheck@latest)"
  fi
  if command -v gofumpt >/dev/null; then
    gofumpt_diff=$(gofumpt -l -d . 2>&1 || true)
    if [[ -n "$gofumpt_diff" ]]; then
      echo "✗ gofumpt diff:"
      echo "$gofumpt_diff"
      exit 1
    fi
  else
    echo "warn: gofumpt not installed"
  fi
elif [[ -f "package.json" ]] && grep -q '"lint"' package.json; then
  echo "Node project detected. Running npm run lint"
  npm run lint
else
  echo "skip: no recognised lint setup (set BE_LINT_CMD to override)"
fi
