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

# 3. Route back to ARCH via route.sh (handles label cleanup + verification)
# Find route.sh: check ~/.claude/scripts/, then relative paths
ROUTE_SH=""
for candidate in "$HOME/.claude/scripts/route.sh" "scripts/route.sh" "$(dirname "$0")/../../scripts/route.sh"; do
  [ -f "$candidate" ] && ROUTE_SH="$candidate" && break
done
if [ -n "$ROUTE_SH" ]; then
  bash "$ROUTE_SH" "$REPO_SLUG" "$ISSUE_N" arch "$AGENT_ID"
else
  echo "WARN: route.sh not found, falling back to raw gh issue edit"
  gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" --remove-label "status:in-progress" --add-label "status:ready"
fi

echo "Routed #${ISSUE_N} back to ARCH"

# 4. Release comment
gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
  --body "Delivered by \`${AGENT_ID}\` — PR opened, routed to ARCH for triage."
