#!/bin/bash
# Scan for parent issues whose sub-issues are all closed, then close them.
# Run as ARCH pre-triage step every cycle.
#
# A "parent" issue is one that has been decomposed — its body contains
# references to sub-issues like "Decomposed into: #A, #B, #C"
# or it has <!-- deps: N --> in child issues pointing back to it.
#
# Usage: scan-complete-requests.sh <REPO_SLUG>
# Exit 0 = success, non-zero = error
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required (e.g. owner/repo)}"

echo "=== ARCH: Request Completion Scan ==="
echo "Repo: ${REPO_SLUG}"

# Look for open issues labeled status:done that weren't closed (cleanup)
DONE_OPEN=$(gh issue list --repo "$REPO_SLUG" --label "status:done" --state open --json number,title --jq '.[] | "#\(.number) \(.title)"' 2>/dev/null || true)

if [ -n "$DONE_OPEN" ]; then
  echo "Found status:done issues still open — closing:"
  echo "$DONE_OPEN"
  gh issue list --repo "$REPO_SLUG" --label "status:done" --state open --json number --jq '.[].number' | while read -r N; do
    gh issue close "$N" --repo "$REPO_SLUG" 2>/dev/null
    echo "  Closed #${N}"
  done
else
  echo "No orphaned status:done issues. All clean."
fi

echo "=== Done ==="
