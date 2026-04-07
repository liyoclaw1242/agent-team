#!/bin/bash
# Create a journal entry file
# Usage: write-journal.sh <REPO_SLUG> <ISSUE_NUMBER> <AGENT_ID> <ROLE>
set -e

REPO_SLUG="${1:?Repo slug required}"
ISSUE_N="${2:?Issue number required}"
AGENT_ID="${3:?Agent ID required}"
ROLE="${4:-ops}"

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

WRITE 1-2 SENTENCES HERE. Do not leave this blank.

## What Worked

WRITE at least 1 bullet. What patterns or approaches were effective?

## What Didn't Work

WRITE at least 1 bullet, or "None" if nothing went wrong. Dead ends, false starts, script bugs.

## Standards Violations Found

WRITE what checks failed initially, or "None".

## Lessons

WRITE at least 1 insight for future tasks in this repo. If nothing new, write "No new lessons."
EOF

echo "Journal template created: $FILEPATH"
echo "IMPORTANT: Open $FILEPATH and fill in all sections. Do not leave template text."
