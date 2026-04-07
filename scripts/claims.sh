#!/bin/bash
# Claim a GitHub issue for an agent. Prevents double-claim via label swap + comment verification.
#
# Usage: claims.sh <REPO_SLUG> <ISSUE_NUMBER> <AGENT_ID>
# Exit 0 = claimed, 1 = already claimed or race detected
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required (e.g. owner/repo)}"
ISSUE_N="${2:?ISSUE_NUMBER required}"
AGENT_ID="${3:?AGENT_ID required}"

# 1. Pre-check: is the issue still status:ready?
LABELS=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json labels --jq '[.labels[].name] | join(",")')
if [[ "$LABELS" != *"status:ready"* ]]; then
  echo "SKIP: #${ISSUE_N} is not status:ready (labels: ${LABELS})"
  exit 1
fi

# 2. Claim: swap status:ready → status:in-progress
gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" \
  --remove-label "status:ready" --add-label "status:in-progress" 2>/dev/null

# 3. Post claim comment with timestamp for race detection
CLAIM_TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
  --body "Claimed by \`${AGENT_ID}\` at ${CLAIM_TS}" 2>/dev/null

# 4. Race detection: wait briefly, then check if another agent claimed within 30s of us
sleep 2
OTHER_CLAIMS=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json comments \
  --jq --arg me "$AGENT_ID" '[.comments[-5:][] | select(.body | startswith("Claimed by")) | select(.body | contains($me) | not) | .body] | length')

if [ "$OTHER_CLAIMS" -gt 0 ]; then
  # Check if those other claims are recent (within last 60 seconds via comment order)
  # If the other "Claimed by" is AFTER ours in the comment list, it's a real race
  MY_IDX=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json comments \
    --jq --arg me "$AGENT_ID" '[.comments | to_entries[] | select(.value.body | contains($me)) | .key] | last // -1')
  LAST_OTHER_IDX=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json comments \
    --jq --arg me "$AGENT_ID" '[.comments | to_entries[] | select(.value.body | startswith("Claimed by")) | select(.value.body | contains($me) | not) | .key] | last // -1')

  if [ "$LAST_OTHER_IDX" -gt "$MY_IDX" ]; then
    # Someone claimed AFTER us — real race, back off
    echo "RACE: #${ISSUE_N} claimed by another agent after us — backing off"
    gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" \
      --remove-label "status:in-progress" --add-label "status:ready" 2>/dev/null
    gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
      --body "Released by \`${AGENT_ID}\` (race detected)" 2>/dev/null
    exit 1
  fi
  # Other claims exist but are BEFORE ours — stale, not a race. Proceed.
fi

# 5. Verify labels
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "${SCRIPT_DIR}/verify-labels.sh" "$REPO_SLUG" "$ISSUE_N" || echo "WARN: Label verification failed for #${ISSUE_N}"

echo "CLAIMED: #${ISSUE_N} by ${AGENT_ID}"
