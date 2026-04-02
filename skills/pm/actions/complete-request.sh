#!/bin/bash
# Mark decomposed requests as completed when all sub-issues are closed.
# Deterministic: fetch pending requests → check sub-issues → complete.
#
# Usage: complete-request.sh <API_URL> [REPO_SLUG]
# If REPO_SLUG is omitted, checks all repos.
# Exit 0 = success, non-zero = API error
set -euo pipefail

API_URL="${1:?API_URL required (e.g. http://localhost:8000)}"
REPO_SLUG="${2:-}"

echo "═══ PM: Request Completion Check ═══"

# 1. Fetch decomposed requests (status=decomposed means ARCH split it, waiting for sub-issues)
QUERY="${API_URL}/requests?status=decomposed"
if [ -n "$REPO_SLUG" ]; then
  QUERY="${QUERY}&repo_slug=${REPO_SLUG}"
  echo "Repo: ${REPO_SLUG}"
else
  echo "Scope: all repos"
fi

REQUESTS=$(curl -sf "$QUERY" || {
  echo "FAIL: Cannot reach ${API_URL}"; exit 1
})

COUNT=$(echo "$REQUESTS" | jq 'length')
if [ "$COUNT" -eq 0 ]; then
  echo "No decomposed requests found. Nothing to do."
  exit 0
fi

echo "Found ${COUNT} decomposed request(s). Checking sub-issues..."

COMPLETED=0
PENDING=0

echo "$REQUESTS" | jq -c '.[]' | while read -r REQ; do
  REQ_ID=$(echo "$REQ" | jq -r '.id')
  REQ_TITLE=$(echo "$REQ" | jq -r '.title // "untitled"')
  REQ_REPO=$(echo "$REQ" | jq -r '.repo_slug')
  SUB_ISSUES=$(echo "$REQ" | jq -r '.issue_numbers // [] | .[]')

  if [ -z "$SUB_ISSUES" ]; then
    echo "  Request ${REQ_ID} (${REQ_TITLE}): no sub-issues listed — skip"
    continue
  fi

  # 2. Preflight: check every sub-issue is closed/merged
  ALL_DONE=true
  OPEN_LIST=""
  for ISSUE_N in $SUB_ISSUES; do
    STATUS=$(curl -sf "${API_URL}/bounties/${REQ_REPO}/issues/${ISSUE_N}" | jq -r '.status' || echo "unknown")
    if [ "$STATUS" != "closed" ] && [ "$STATUS" != "merged" ]; then
      ALL_DONE=false
      OPEN_LIST="${OPEN_LIST} #${ISSUE_N}(${STATUS})"
    fi
  done

  if [ "$ALL_DONE" = false ]; then
    echo "  Request ${REQ_ID} (${REQ_TITLE}): still open:${OPEN_LIST}"
    PENDING=$((PENDING + 1))
    continue
  fi

  # 3. Execute: mark request as completed
  echo "  Request ${REQ_ID} (${REQ_TITLE}): all sub-issues closed → completing..."
  HTTP_CODE=$(curl -sf -o /dev/null -w "%{http_code}" \
    -X PATCH "${API_URL}/requests/${REQ_ID}" \
    -H "Content-Type: application/json" \
    -d '{"status": "completed"}')

  if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    # 4. Verify
    NEW_STATUS=$(curl -sf "${API_URL}/requests/${REQ_ID}" | jq -r '.status')
    if [ "$NEW_STATUS" = "completed" ]; then
      echo "  Request ${REQ_ID}: COMPLETED (verified)"
      COMPLETED=$((COMPLETED + 1))
    else
      echo "  Request ${REQ_ID}: WARN — PATCH succeeded but status is '${NEW_STATUS}'"
    fi
  else
    echo "  Request ${REQ_ID}: FAIL — PATCH returned HTTP ${HTTP_CODE}"
  fi
done

echo "═══ Result: ${COMPLETED} completed, ${PENDING} still pending ═══"
