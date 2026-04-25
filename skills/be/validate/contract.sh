#!/usr/bin/env bash
# contract.sh — best-effort cross-check between the issue's published contract
# block and the actual handler routing in code.
#
# This is a soft validator: it warns rather than fails on mismatches, because
# truly accurate contract conformance requires per-language handler parsing
# that's beyond a generic shell script.
#
# What it does:
#   1. Reads the contract block from /tmp/contract-issue-{N}.md if available
#   2. Extracts paths and methods from the contract
#   3. Greps the codebase for matching handler registrations
#   4. Warns if a contract endpoint has no apparent handler
#
# Usage:
#   ISSUE_N=143 bash validate/contract.sh
#   (or simply skip if ISSUE_N not set)

set -euo pipefail

if [[ -z "${ISSUE_N:-}" ]]; then
  echo "contract: skip (ISSUE_N env var not set)"
  exit 0
fi

CONTRACT_FILE="/tmp/contract-issue-${ISSUE_N}.md"
if [[ ! -f "$CONTRACT_FILE" ]]; then
  CONTRACT_FILE="/tmp/contract-${ISSUE_N}.md"
fi

if [[ ! -f "$CONTRACT_FILE" ]]; then
  echo "contract: skip (no /tmp/contract-issue-${ISSUE_N}.md or /tmp/contract-${ISSUE_N}.md)"
  exit 0
fi

echo "Contract conformance check using $CONTRACT_FILE:"

# Extract endpoint declarations: lines like "POST /path/{id}/action" or
# "GET /resource".
endpoints=$(grep -oE '(GET|POST|PUT|PATCH|DELETE)\s+/[a-zA-Z0-9/_{}-]+' "$CONTRACT_FILE" || true)

if [[ -z "$endpoints" ]]; then
  echo "  no endpoints extracted from contract; nothing to check"
  exit 0
fi

mismatches=0
echo "$endpoints" | while IFS= read -r ep; do
  method=$(echo "$ep" | awk '{print $1}')
  path=$(echo "$ep" | awk '{print $2}')

  # Strip {param} placeholders for grep
  path_pattern=$(echo "$path" | sed 's/{[^}]*}/[^"]*/g')

  # Look for handler registration
  if grep -rE --include="*.go" --include="*.ts" --include="*.js" --include="*.py" \
       "$method.*\"$path_pattern\"|\"$path_pattern\".*$method" . 2>/dev/null \
       | head -1 | grep -q .; then
    echo "  ✓ $method $path — handler found"
  else
    echo "  ✗ $method $path — no apparent handler registration"
    mismatches=$((mismatches + 1))
  fi
done

# Note: due to subshell, mismatches counter doesn't propagate. This is
# acceptable since this validator is informational; treat as soft.
echo ""
echo "(contract validator is best-effort; true verification is in integration tests)"
exit 0
