#!/bin/bash
# Commit, push, and open PR. ARCH does NOT route to itself.
# Usage: deliver.sh <AGENT_ID> <ISSUE_NUMBER> <TITLE> <REPO_SLUG> [COMMIT_PREFIX] [API_URL]
set -e

AGENT_ID="${1:?Agent ID required}"
ISSUE_N="${2:?Issue number required}"
TITLE="${3:?Title required}"
REPO_SLUG="${4:?Repo slug required}"
PREFIX="${5:-docs:}"
API_URL="${6:-http://localhost:8000}"

BRANCH="agent/${AGENT_ID}/issue-${ISSUE_N}"

# 1. Git: commit + push
git add -A
git commit -m "${PREFIX} ${TITLE} (closes #${ISSUE_N})"
git push origin "${BRANCH}"

# 2. GitHub: open PR
gh pr create \
  --title "[${AGENT_ID}] ${TITLE}" \
  --body "Closes #${ISSUE_N}

Implemented by agent \`${AGENT_ID}\`." \
  --base main \
  --head "${BRANCH}" \
  --repo "${REPO_SLUG}"

echo "PR created for #${ISSUE_N}"

# 3. ARCH sets status directly (no routing needed — ARCH IS the authority)
curl -sf -X PATCH "${API_URL}/bounties/${REPO_SLUG}/issues/${ISSUE_N}" \
  -H "Content-Type: application/json" \
  -d '{"status": "review"}' \
  && echo "Set #${ISSUE_N} to review" \
  || echo "WARN: Failed to update bounty status for #${ISSUE_N}"

# 4. Release claim
curl -sf -X DELETE "${API_URL}/claims/${REPO_SLUG}/issues/${ISSUE_N}?agent_id=${AGENT_ID}" \
  && echo "Released claim on #${ISSUE_N}" \
  || echo "WARN: Failed to release claim for #${ISSUE_N}"
