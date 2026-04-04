#!/bin/bash
# Release a claim on a GitHub issue.
#
# Usage: release-claim.sh <REPO_SLUG> <ISSUE_NUMBER> <AGENT_ID>
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required}"
ISSUE_N="${2:?ISSUE_NUMBER required}"
AGENT_ID="${3:?AGENT_ID required}"

gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" \
  --remove-label "status:in-progress" --add-label "status:ready" 2>/dev/null

gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
  --body "Released by \`${AGENT_ID}\`" 2>/dev/null

echo "RELEASED: #${ISSUE_N} by ${AGENT_ID}"
