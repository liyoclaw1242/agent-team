#!/bin/bash
# QA post-verdict validation — verify verdict comment was posted and issue routed to ARCH
# Usage: check-all.sh <REPO_SLUG> <ISSUE_N> <PR_NUMBER>
#
# Exit code: 0 = all checks pass, N = number of violations
set -e

REPO_SLUG="${1:?Usage: check-all.sh <REPO_SLUG> <ISSUE_N> <PR_NUMBER>}"
ISSUE_N="${2:?Issue number required}"
PR_NUMBER="${3:?PR number required}"
FAILURES=0

echo "=== QA Validation ==="
echo "Repo: $REPO_SLUG | Issue: #$ISSUE_N | PR: #$PR_NUMBER"
echo ""

# 1. Verify verdict comment exists on the PR
echo "-- Comment Audit --"
LAST_COMMENT=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json comments --jq '.comments[-1].body' 2>/dev/null || echo "")

if [ -z "$LAST_COMMENT" ]; then
  echo "FAIL: No comments found on PR"
  FAILURES=$((FAILURES+1))
elif echo "$LAST_COMMENT" | grep -q "Verdict:"; then
  echo "OK: Verdict comment found"
else
  echo "FAIL: Last comment does not contain a verdict"
  FAILURES=$((FAILURES+1))
fi

# 2. Verify issue was routed to ARCH
echo ""
echo "-- Routing Audit --"
LABELS=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json labels --jq '[.labels[].name] | join(",")' 2>/dev/null || echo "")

if echo "$LABELS" | grep -q "agent:arch"; then
  echo "OK: Issue routed to ARCH"
else
  echo "FAIL: Issue not routed to ARCH (labels: $LABELS)"
  echo "      Run: gh issue edit $ISSUE_N --repo $REPO_SLUG --add-label agent:arch"
  FAILURES=$((FAILURES+1))
fi

if echo "$LABELS" | grep -q "status:ready"; then
  echo "OK: Status is ready for ARCH triage"
else
  echo "WARN: Status is not ready (labels: $LABELS)"
fi

echo ""
echo "=== Results: $FAILURES violation(s) ==="
exit $FAILURES
