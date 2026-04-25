#!/usr/bin/env bash
# publish-contract.sh — atomically update an issue body with the API contract
# block. Idempotent: re-running replaces the existing block if any.
#
# The contract block is delimited by HTML comment markers so the action can
# find and replace it without destroying surrounding content:
#
#   <!-- be-contract-begin -->
#   ## Contract (defined by BE, consumed by FE)
#   ...
#   <!-- be-contract-end -->
#
# Usage:
#   publish-contract.sh
#       --issue N
#       --contract-file PATH
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# The contract-file content is the markdown to insert verbatim (without the
# delimiter markers). The action wraps it with markers automatically.

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-be}"
ISSUE_N=""
CONTRACT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)         ISSUE_N="$2"; shift 2 ;;
    --contract-file) CONTRACT_FILE="$2"; shift 2 ;;
    --repo)          REPO="$2"; shift 2 ;;
    --agent-id)      AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$CONTRACT_FILE" || ! -f "$CONTRACT_FILE" ]] && { echo "--contract-file required and must exist" >&2; exit 1; }

# Read current body
current_body=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body // ""') \
  || { echo "cannot read issue #$ISSUE_N" >&2; exit 2; }

# Compose new body: remove any existing contract block, then append fresh one
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

# Strip existing contract block (if any) from current body
echo "$current_body" \
  | perl -0777 -pe 's/<!--\s*be-contract-begin\s*-->.*?<!--\s*be-contract-end\s*-->\n*//gs' \
  > "$TMP"

# Append fresh contract block
{
  echo ""
  echo ""
  echo "<!-- be-contract-begin -->"
  cat "$CONTRACT_FILE"
  echo ""
  echo "<!-- be-contract-end -->"
} >> "$TMP"

# Update the issue
gh issue edit "$ISSUE_N" --repo "$REPO" --body-file "$TMP" >/dev/null \
  || { echo "failed to update issue #$ISSUE_N" >&2; exit 3; }

# Audit comment so FE consumers see a notification
COMMENT_TMP=$(mktemp)
{
  echo "📜 **Contract published** by \`$AGENT_ID\`"
  echo ""
  echo "The API contract for this task is now in the issue body. FE consumers"
  echo "depending on this issue can read the \`## Contract\` block above and"
  echo "begin work."
  echo ""
  echo "Re-running the publish action will update the contract atomically."
} > "$COMMENT_TMP"
gh issue comment "$ISSUE_N" --repo "$REPO" --body-file "$COMMENT_TMP" >/dev/null \
  || echo "warning: failed to post contract-publish notification on #$ISSUE_N" >&2
rm -f "$COMMENT_TMP"

echo "contract published on #$ISSUE_N"
