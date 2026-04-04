#!/bin/bash
# ARCH deliver: commit, push, open PR. ARCH does NOT route to itself.
# Usage: deliver.sh <AGENT_ID> <ISSUE_NUMBER> <TITLE> <REPO_SLUG> [COMMIT_PREFIX]
set -e

AGENT_ID="${1:?Agent ID required}"
ISSUE_N="${2:?Issue number required}"
TITLE="${3:?Title required}"
REPO_SLUG="${4:?Repo slug required}"
PREFIX="${5:-docs:}"

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
