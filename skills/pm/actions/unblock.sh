#!/bin/bash
# Unblock issues whose dependencies are all closed.
# Deterministic: preflight check → execute → verify. AI should NOT reason about this.
#
# Usage: unblock.sh <API_URL> <REPO_SLUG>
# Exit 0 = success (0 or more issues unblocked), non-zero = API error
set -euo pipefail

API_URL="${1:?API_URL required (e.g. http://localhost:8000)}"
REPO_SLUG="${2:?REPO_SLUG required (e.g. owner/repo)}"

echo "═══ PM: Dependency Unblock ═══"
echo "Repo: ${REPO_SLUG}"

# 1. Fetch all blocked issues for this repo
BLOCKED=$(curl -sf "${API_URL}/bounties?status=blocked&repo_slug=${REPO_SLUG}" || {
  echo "FAIL: Cannot reach ${API_URL}"; exit 1
})

COUNT=$(echo "$BLOCKED" | jq 'length')
if [ "$COUNT" -eq 0 ]; then
  echo "No blocked issues found. Nothing to do."
  exit 0
fi

echo "Found ${COUNT} blocked issue(s). Checking dependencies..."

UNBLOCKED=0
STILL_BLOCKED=0

echo "$BLOCKED" | jq -c '.[]' | while read -r ISSUE; do
  ISSUE_N=$(echo "$ISSUE" | jq -r '.issue_number')
  TITLE=$(echo "$ISSUE" | jq -r '.title // "untitled"')
  DEPS=$(echo "$ISSUE" | jq -r '.depends_on // [] | .[]')

  if [ -z "$DEPS" ]; then
    echo "  #${ISSUE_N} (${TITLE}): no deps listed — skip (needs manual triage)"
    continue
  fi

  # 2. Preflight: check every dependency is closed
  ALL_CLOSED=true
  for DEP in $DEPS; do
    DEP_STATUS=$(curl -sf "${API_URL}/bounties/${REPO_SLUG}/issues/${DEP}" | jq -r '.status' || echo "unknown")
    if [ "$DEP_STATUS" != "closed" ] && [ "$DEP_STATUS" != "merged" ]; then
      echo "  #${ISSUE_N}: dep #${DEP} is '${DEP_STATUS}' — still blocked"
      ALL_CLOSED=false
      break
    fi
  done

  if [ "$ALL_CLOSED" = false ]; then
    STILL_BLOCKED=$((STILL_BLOCKED + 1))
    continue
  fi

  # 3. Execute: unblock
  echo "  #${ISSUE_N} (${TITLE}): all deps closed → unblocking..."
  HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    -X PATCH "${API_URL}/bounties/${REPO_SLUG}/issues/${ISSUE_N}" \
    -H "Content-Type: application/json" \
    -d '{"status": "ready"}')

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    # 4. Verify: re-fetch and confirm
    NEW_STATUS=$(curl -sf "${API_URL}/bounties/${REPO_SLUG}/issues/${ISSUE_N}" | jq -r '.status')
    if [ "$NEW_STATUS" = "ready" ]; then
      echo "  #${ISSUE_N}: UNBLOCKED (verified)"
      UNBLOCKED=$((UNBLOCKED + 1))
    else
      echo "  #${ISSUE_N}: WARN — PATCH succeeded but status is '${NEW_STATUS}'"
    fi
  else
    echo "  #${ISSUE_N}: FAIL — PATCH returned HTTP ${HTTP_CODE}"
  fi
done

echo "═══ Result: ${UNBLOCKED} unblocked, ${STILL_BLOCKED} still blocked ═══"
