#!/bin/bash
# Create a journal entry file
# Usage: write-journal.sh <REPO_SLUG> <ISSUE_NUMBER> <AGENT_ID> <ROLE>
set -e

REPO_SLUG="${1:?Repo slug required}"
ISSUE_N="${2:?Issue number required}"
AGENT_ID="${3:?Agent ID required}"
ROLE="${4:-be}"

JOURNAL_DIR="$HOME/.agent-team/journal/$(echo "$REPO_SLUG" | tr '/' '-')"
mkdir -p "$JOURNAL_DIR"

DATE=$(date +"%Y-%m-%d")
FILENAME="${DATE}-issue-${ISSUE_N}.md"
FILEPATH="${JOURNAL_DIR}/${FILENAME}"

cat > "$FILEPATH" << EOF
# Task Journal Entry

## Meta

- **Issue**: ${REPO_SLUG}#${ISSUE_N}
- **Agent**: ${AGENT_ID}
- **Role**: ${ROLE}
- **Date**: ${DATE}
- **Outcome**: DONE

## Summary

(Fill in: 1-2 sentences)

## What Worked

(Fill in: patterns or approaches that were effective)

## What Didn't Work

(Fill in: dead ends, false starts)

## Standards Violations Found

(Fill in: which checks failed initially)

## Lessons

(Fill in: insights for future tasks in this repo)
EOF

echo "Journal entry created: $FILEPATH"
