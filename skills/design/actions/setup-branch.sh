#!/bin/bash
# Create a clean agent branch from main
# Usage: setup-branch.sh <REPO_DIR> <AGENT_ID> <ISSUE_NUMBER>
set -e

REPO_DIR="${1:-.}"
AGENT_ID="${2:?Agent ID required}"
ISSUE_N="${3:?Issue number required}"

cd "$REPO_DIR"
git fetch origin main
git checkout -b "agent/${AGENT_ID}/issue-${ISSUE_N}" origin/main
echo "Branch created: agent/${AGENT_ID}/issue-${ISSUE_N}"
