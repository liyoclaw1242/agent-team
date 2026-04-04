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

# 3. Post claim comment (used for race detection)
gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
  --body "Claimed by \`${AGENT_ID}\`" 2>/dev/null

# 4. Race detection: wait briefly, then check if another agent also claimed
sleep 2
CLAIM_COUNT=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json comments \
  --jq '[.comments[-3:][].body | select(startswith("Claimed by"))] | length')

if [ "$CLAIM_COUNT" -gt 1 ]; then
  echo "RACE: #${ISSUE_N} claimed by multiple agents — backing off"
  gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" \
    --remove-label "status:in-progress" --add-label "status:ready" 2>/dev/null
  gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
    --body "Released by \`${AGENT_ID}\` (race detected)" 2>/dev/null
  exit 1
fi

echo "CLAIMED: #${ISSUE_N} by ${AGENT_ID}"
