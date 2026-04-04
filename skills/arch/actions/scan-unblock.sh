#!/bin/bash
# Scan for blocked issues whose dependencies are all closed, then unblock them.
# Run as ARCH pre-triage step every cycle.
#
# Usage: scan-unblock.sh <REPO_SLUG>
# Exit 0 = success (0 or more issues unblocked), non-zero = error
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required (e.g. owner/repo)}"

echo "=== ARCH: Dependency Unblock Scan ==="
echo "Repo: ${REPO_SLUG}"

# 1. Fetch all blocked issues
BLOCKED=$(gh issue list --repo "$REPO_SLUG" --label "status:blocked" --json number,title,body --jq '.[] | @json' 2>/dev/null || true)

if [ -z "$BLOCKED" ]; then
  echo "No blocked issues found. Nothing to do."
  exit 0
fi

UNBLOCKED=0
STILL_BLOCKED=0

echo "$BLOCKED" | while IFS= read -r ISSUE_JSON; do
  ISSUE_N=$(echo "$ISSUE_JSON" | jq -r '.number')
  TITLE=$(echo "$ISSUE_JSON" | jq -r '.title')
  BODY=$(echo "$ISSUE_JSON" | jq -r '.body')

  # Parse <!-- deps: 5,6,7 --> from body
  DEPS=$(echo "$BODY" | grep -oP '<!-- deps: \K[0-9,]+' || true)

  if [ -z "$DEPS" ]; then
    echo "  #${ISSUE_N} (${TITLE}): no deps found — skip"
    continue
  fi

  # 2. Check every dependency is closed
  ALL_CLOSED=true
  for DEP in $(echo "$DEPS" | tr ',' ' '); do
    DEP_STATE=$(gh issue view "$DEP" --repo "$REPO_SLUG" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
    if [ "$DEP_STATE" != "CLOSED" ]; then
      echo "  #${ISSUE_N}: dep #${DEP} is ${DEP_STATE} — still blocked"
      ALL_CLOSED=false
      break
    fi
  done

  if [ "$ALL_CLOSED" = false ]; then
    STILL_BLOCKED=$((STILL_BLOCKED + 1))
    continue
  fi

  # 3. Unblock: swap labels
  echo "  #${ISSUE_N} (${TITLE}): all deps closed — unblocking..."
  gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" \
    --remove-label "status:blocked" --add-label "status:ready" 2>/dev/null

  echo "  #${ISSUE_N}: UNBLOCKED"
  UNBLOCKED=$((UNBLOCKED + 1))
done

echo "=== Result: ${UNBLOCKED} unblocked, ${STILL_BLOCKED} still blocked ==="
