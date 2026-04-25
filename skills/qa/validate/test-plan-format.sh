#!/usr/bin/env bash
# test-plan-format.sh — verifies a published test plan has the required structure.
#
# Used during shift-left QA work. Reads the test plan from the issue body
# (between qa-test-plan markers) and checks for required sections.
#
# Usage:
#   ISSUE_N=145 bash validate/test-plan-format.sh
#
# (or skip if ISSUE_N not set — non-strict; informational)

set -euo pipefail

if [[ -z "${ISSUE_N:-}" ]]; then
  echo "test-plan-format: skip (ISSUE_N env var not set)"
  exit 0
fi

REPO="${REPO:-}"
[[ -z "$REPO" ]] && { echo "test-plan-format: skip (REPO not set)"; exit 0; }

# Read body
body=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body // ""') \
  || { echo "test-plan-format: cannot read issue #$ISSUE_N"; exit 0; }

# Extract the plan block
plan=$(echo "$body" | perl -ne 'print if /qa-test-plan-begin/.../qa-test-plan-end/')

if [[ -z "$plan" ]]; then
  echo "test-plan-format: no qa-test-plan block found in issue #$ISSUE_N"
  exit 0
fi

errors=0

# Check required sections
for section in "AC-to-test mapping" "Edge cases" "Out of scope" "Verification approach"; do
  if ! echo "$plan" | grep -qiE "^### .*$section|^## .*$section"; then
    echo "  ✗ missing section: $section"
    errors=$((errors + 1))
  fi
done

# Check at least one test name in the AC mapping (rough heuristic)
test_count=$(echo "$plan" | grep -cE 'Test[A-Z][a-zA-Z_]+' || echo 0)
if [[ "$test_count" -lt 1 ]]; then
  echo "  ✗ no test names found in plan (expected pattern Test*)"
  errors=$((errors + 1))
fi

if [[ $errors -eq 0 ]]; then
  echo "test-plan-format: ok (4 required sections + $test_count tests named)"
  exit 0
fi

echo "test-plan-format: $errors issue(s)"
exit 1
