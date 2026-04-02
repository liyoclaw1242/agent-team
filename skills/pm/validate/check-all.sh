#!/bin/bash
# PM post-cycle validation sweep.
# Finds missed unblocks and incomplete requests that should have been completed.
# Run after each polling cycle to catch anything the action scripts missed.
#
# Usage: check-all.sh <API_URL> [REPO_SLUG]
# Exit code: 0 = clean, non-zero = issues found
set -euo pipefail

API_URL="${1:?API_URL required}"
REPO_SLUG="${2:-}"

ISSUES=0

echo "═══ PM Validation Sweep ═══"

# ── 1. Missed Unblocks ──
# Find blocked issues whose deps are all closed (should have been unblocked)
echo "── Missed Unblocks ──"

QUERY="${API_URL}/bounties?status=blocked"
[ -n "$REPO_SLUG" ] && QUERY="${QUERY}&repo_slug=${REPO_SLUG}"

BLOCKED=$(curl -sf "$QUERY" 2>/dev/null || echo "[]")
echo "$BLOCKED" | jq -c '.[]' 2>/dev/null | while read -r ISSUE; do
  ISSUE_N=$(echo "$ISSUE" | jq -r '.issue_number')
  REPO=$(echo "$ISSUE" | jq -r '.repo_slug')
  DEPS=$(echo "$ISSUE" | jq -r '.depends_on // [] | .[]')

  [ -z "$DEPS" ] && continue

  ALL_CLOSED=true
  for DEP in $DEPS; do
    STATUS=$(curl -sf "${API_URL}/bounties/${REPO}/issues/${DEP}" 2>/dev/null | jq -r '.status' || echo "unknown")
    if [ "$STATUS" != "closed" ] && [ "$STATUS" != "merged" ]; then
      ALL_CLOSED=false
      break
    fi
  done

  if [ "$ALL_CLOSED" = true ]; then
    echo "  MISS: ${REPO}#${ISSUE_N} — all deps closed but still blocked"
    ISSUES=$((ISSUES + 1))
  fi
done

# ── 2. Missed Request Completions ──
echo "── Missed Completions ──"

QUERY="${API_URL}/requests?status=decomposed"
[ -n "$REPO_SLUG" ] && QUERY="${QUERY}&repo_slug=${REPO_SLUG}"

REQUESTS=$(curl -sf "$QUERY" 2>/dev/null || echo "[]")
echo "$REQUESTS" | jq -c '.[]' 2>/dev/null | while read -r REQ; do
  REQ_ID=$(echo "$REQ" | jq -r '.id')
  REQ_REPO=$(echo "$REQ" | jq -r '.repo_slug')
  SUB_ISSUES=$(echo "$REQ" | jq -r '.issue_numbers // [] | .[]')

  [ -z "$SUB_ISSUES" ] && continue

  ALL_DONE=true
  for ISSUE_N in $SUB_ISSUES; do
    STATUS=$(curl -sf "${API_URL}/bounties/${REQ_REPO}/issues/${ISSUE_N}" 2>/dev/null | jq -r '.status' || echo "unknown")
    if [ "$STATUS" != "closed" ] && [ "$STATUS" != "merged" ]; then
      ALL_DONE=false
      break
    fi
  done

  if [ "$ALL_DONE" = true ]; then
    echo "  MISS: Request ${REQ_ID} — all sub-issues closed but not completed"
    ISSUES=$((ISSUES + 1))
  fi
done

# ── 3. Orphan Detection ──
# Issues that have been in 'ready' for a long time with no claim
echo "── Stale Ready Issues ──"

QUERY="${API_URL}/bounties?status=ready"
[ -n "$REPO_SLUG" ] && QUERY="${QUERY}&repo_slug=${REPO_SLUG}"

READY=$(curl -sf "$QUERY" 2>/dev/null || echo "[]")
NOW=$(date +%s)
STALE_THRESHOLD=86400  # 24 hours

echo "$READY" | jq -c '.[]' 2>/dev/null | while read -r ISSUE; do
  ISSUE_N=$(echo "$ISSUE" | jq -r '.issue_number')
  REPO=$(echo "$ISSUE" | jq -r '.repo_slug')
  CREATED=$(echo "$ISSUE" | jq -r '.created_at // empty')

  if [ -n "$CREATED" ]; then
    CREATED_TS=$(date -j -f "%Y-%m-%dT%H:%M:%S" "$CREATED" +%s 2>/dev/null || date -d "$CREATED" +%s 2>/dev/null || echo "0")
    AGE=$((NOW - CREATED_TS))
    if [ "$AGE" -gt "$STALE_THRESHOLD" ]; then
      HOURS=$((AGE / 3600))
      echo "  STALE: ${REPO}#${ISSUE_N} — ready for ${HOURS}h, no agent claimed it"
      ISSUES=$((ISSUES + 1))
    fi
  fi
done

echo "═══ Sweep Result: ${ISSUES} issue(s) found ═══"
exit $ISSUES
