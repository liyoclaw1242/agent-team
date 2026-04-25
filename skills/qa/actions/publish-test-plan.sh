#!/usr/bin/env bash
# publish-test-plan.sh — atomically publish a test plan into the QA issue body.
# Idempotent: re-running replaces the existing block.
#
# The block is delimited by HTML comments so the action can find and replace
# it without destroying surrounding content:
#
#   <!-- qa-test-plan-begin -->
#   ## Test plan (defined by QA, used by implementers)
#   ...
#   <!-- qa-test-plan-end -->
#
# Usage:
#   publish-test-plan.sh
#       --issue N
#       --plan-file PATH
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-qa}"
ISSUE_N=""
PLAN_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)     ISSUE_N="$2"; shift 2 ;;
    --plan-file) PLAN_FILE="$2"; shift 2 ;;
    --repo)      REPO="$2"; shift 2 ;;
    --agent-id)  AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$PLAN_FILE" || ! -f "$PLAN_FILE" ]] && { echo "--plan-file required and must exist" >&2; exit 1; }

# Sanity-check the plan: it should have an AC mapping section
if ! grep -qE "^### AC-to-test mapping|^## .*[Tt]est plan" "$PLAN_FILE"; then
  echo "plan-file appears malformed (no '### AC-to-test mapping' or '## Test plan' heading found)" >&2
  echo "see workflow/test-plan.md for the expected structure" >&2
  exit 1
fi

# Read current body
current_body=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body // ""') \
  || { echo "cannot read issue #$ISSUE_N" >&2; exit 2; }

# Compose new body
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Strip existing test-plan block (if any)
echo "$current_body" \
  | perl -0777 -pe 's/<!--\s*qa-test-plan-begin\s*-->.*?<!--\s*qa-test-plan-end\s*-->\n*//gs' \
  > "$TMP"

# Append fresh block
{
  echo ""
  echo ""
  echo "<!-- qa-test-plan-begin -->"
  cat "$PLAN_FILE"
  echo ""
  echo "<!-- qa-test-plan-end -->"
} >> "$TMP"

# Update the issue
gh issue edit "$ISSUE_N" --repo "$REPO" --body-file "$TMP" >/dev/null \
  || { echo "failed to update issue #$ISSUE_N" >&2; exit 3; }

# Audit comment so dependent tasks see the publish event
COMMENT_TMP=$(mktemp)
{
  echo "📋 **Test plan published** by \`$AGENT_ID\`"
  echo ""
  echo "The shift-left test plan is now in this issue's body. Dependent"
  echo "implementer tasks (those with \`<!-- deps: #$ISSUE_N -->\`) can read"
  echo "the plan and proceed when this issue closes."
  echo ""
  echo "Re-running the publish action will update the plan atomically."
} > "$COMMENT_TMP"
gh issue comment "$ISSUE_N" --repo "$REPO" --body-file "$COMMENT_TMP" >/dev/null \
  || echo "warning: failed to post test-plan-publish notification on #$ISSUE_N" >&2
rm -f "$COMMENT_TMP"

echo "test plan published on #$ISSUE_N"
