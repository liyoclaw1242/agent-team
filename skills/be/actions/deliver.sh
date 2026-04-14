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
SELF_TEST_FILE="/tmp/self-test-issue-${ISSUE_N}.md"

# 0. Gate: self-test record must exist
if [ ! -f "$SELF_TEST_FILE" ]; then
  echo "BLOCKED: Self-test record not found at $SELF_TEST_FILE"
  echo "Complete self-testing before delivering."
  echo "See workflow/implement.md for self-test requirements."
  exit 1
fi

# 1. Git: commit + push
git add -A
git commit -m "${PREFIX} ${TITLE} (closes #${ISSUE_N})"
git push origin "${BRANCH}"

# 2. GitHub: open PR
PR_URL=$(gh pr create \
  --title "[${AGENT_ID}] ${TITLE}" \
  --body "Closes #${ISSUE_N}

Implemented by agent \`${AGENT_ID}\`." \
  --base main \
  --head "${BRANCH}" \
  --repo "${REPO_SLUG}" 2>&1 | tail -1)

echo "PR created for #${ISSUE_N}: ${PR_URL}"

# 3. Post self-test record as PR comment
PR_NUMBER=$(echo "$PR_URL" | grep -o '[0-9]*$')
if [ -n "$PR_NUMBER" ] && [ -f "$SELF_TEST_FILE" ]; then
  gh pr comment "$PR_NUMBER" --repo "$REPO_SLUG" \
    --body-file "$SELF_TEST_FILE"
  echo "Self-test record posted to PR #${PR_NUMBER}"
fi

# 4. Route back to ARCH via route.sh (handles label cleanup + verification)
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

# 5. Release comment
gh issue comment "$ISSUE_N" --repo "$REPO_SLUG" \
  --body "Delivered by \`${AGENT_ID}\` — PR opened, routed to ARCH for triage."
