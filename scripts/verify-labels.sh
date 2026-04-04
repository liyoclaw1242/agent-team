#!/bin/bash
# Verify an issue has exactly 1 agent: label and exactly 1 status: label.
# Run after any label change to catch malformed state.
#
# Usage: verify-labels.sh <REPO_SLUG> <ISSUE_NUMBER>
# Exit 0 = valid, 1 = invalid (prints what's wrong)
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required}"
ISSUE_N="${2:?ISSUE_NUMBER required}"

LABELS=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json labels,state \
  --jq '{labels: [.labels[].name], state: .state}')

STATE=$(echo "$LABELS" | jq -r '.state')
LABEL_LIST=$(echo "$LABELS" | jq -r '.labels[]')

# Closed issues with status:done are exempt
if [ "$STATE" = "CLOSED" ]; then
  exit 0
fi

AGENT_COUNT=$(echo "$LABEL_LIST" | grep -c '^agent:' || true)
STATUS_COUNT=$(echo "$LABEL_LIST" | grep -c '^status:' || true)
AGENT_LABELS=$(echo "$LABEL_LIST" | grep '^agent:' | tr '\n' ',' | sed 's/,$//')
STATUS_LABELS=$(echo "$LABEL_LIST" | grep '^status:' | tr '\n' ',' | sed 's/,$//')

ERRORS=0

if [ "$AGENT_COUNT" -eq 0 ]; then
  echo "FAIL: #${ISSUE_N} missing agent: label"
  ERRORS=$((ERRORS+1))
elif [ "$AGENT_COUNT" -gt 1 ]; then
  echo "FAIL: #${ISSUE_N} has ${AGENT_COUNT} agent: labels (${AGENT_LABELS}) — must be exactly 1"
  ERRORS=$((ERRORS+1))
fi

if [ "$STATUS_COUNT" -eq 0 ]; then
  echo "FAIL: #${ISSUE_N} missing status: label"
  ERRORS=$((ERRORS+1))
elif [ "$STATUS_COUNT" -gt 1 ]; then
  echo "FAIL: #${ISSUE_N} has ${STATUS_COUNT} status: labels (${STATUS_LABELS}) — must be exactly 1"
  ERRORS=$((ERRORS+1))
fi

if [ "$ERRORS" -eq 0 ]; then
  echo "OK: #${ISSUE_N} [${AGENT_LABELS}, ${STATUS_LABELS}]"
fi

exit $ERRORS
