#!/bin/bash
# Commit, push, open PR, and route back to ARCH via GitHub labels.
# Usage: deliver.sh <AGENT_ID> <ISSUE_NUMBER> <TITLE> <REPO_SLUG> [COMMIT_PREFIX]
set -e

AGENT_ID="${1:?Agent ID required}"
ISSUE_N="${2:?Issue number required}"
TITLE="${3:?Title required}"
REPO_SLUG="${4:?Repo slug required}"
PREFIX="${5:-feat:}"

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

# 3. Route back to ARCH: swap labels
CURRENT_AGENT=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json labels \
  --jq '[.labels[].name | select(startswith("agent:"))] | .[0] // empty')

if [ -n "$CURRENT_AGENT" ]; then
  gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" --remove-label "$CURRENT_AGENT"
fi
gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" \
  --remove-label "status:in-progress" \
  --add-label "agent:arch" --add-label "status:ready"

echo "Routed #${ISSUE_N} back to ARCH"

# 4. Verify labels
bash scripts/verify-labels.sh "$REPO_SLUG" "$ISSUE_N" || echo "WARN: Label verification failed for #${ISSUE_N}"

# 5. Release comment
gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
  --body "Delivered by \`${AGENT_ID}\` — PR opened, routed to ARCH for triage."
