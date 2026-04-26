#!/usr/bin/env bash
# plan-change.sh — embed a dry-run / plan output into the issue body for
# reviewer visibility.
#
# Idempotent: re-running replaces the existing plan block with the new one.
#
# The block is delimited by HTML comments:
#   <!-- ops-plan-begin -->
#   ## Plan summary
#   ...
#   <!-- ops-plan-end -->
#
# Usage:
#   plan-change.sh
#       --issue N
#       --dry-run-file PATH        path to the dry-run output (terraform plan,
#                                  kubectl --dry-run, wrangler dry-run, etc.)
#       [--tool NAME]              tool name to display (auto-detected from content)
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-ops}"
ISSUE_N=""
DRY_RUN_FILE=""
TOOL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)        ISSUE_N="$2"; shift 2 ;;
    --dry-run-file) DRY_RUN_FILE="$2"; shift 2 ;;
    --tool)         TOOL="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --agent-id)     AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$DRY_RUN_FILE" || ! -f "$DRY_RUN_FILE" ]] && { echo "--dry-run-file required and must exist" >&2; exit 1; }

# Auto-detect tool from content if not specified
if [[ -z "$TOOL" ]]; then
  if grep -qE 'Terraform will perform|Plan: [0-9]+ to add' "$DRY_RUN_FILE"; then
    TOOL="terraform"
  elif grep -qE 'created \(server dry run\)|configured \(server dry run\)' "$DRY_RUN_FILE"; then
    TOOL="kubectl --dry-run=server"
  elif grep -qE 'Total Upload|Outputs:' "$DRY_RUN_FILE"; then
    TOOL="wrangler"
  else
    TOOL="(unknown)"
  fi
fi

# Extract a summary from the dry-run output (best-effort per tool)
TMP_SUMMARY=$(mktemp)
trap 'rm -f "$TMP_SUMMARY"' EXIT

case "$TOOL" in
  terraform)
    plan_line=$(grep -E '^Plan:' "$DRY_RUN_FILE" | head -n1 || echo "Plan: (no summary line found)")
    echo "$plan_line" >> "$TMP_SUMMARY"
    # Try to extract security-relevant resources
    sec_changes=$(grep -E '(iam_|kms|networking|security_group|firewall_rule)' "$DRY_RUN_FILE" \
                    | head -n5 || true)
    if [[ -n "$sec_changes" ]]; then
      echo "" >> "$TMP_SUMMARY"
      echo "Security-relevant resources affected:" >> "$TMP_SUMMARY"
      echo "$sec_changes" | sed 's/^/  /' >> "$TMP_SUMMARY"
    fi
    ;;
  "kubectl --dry-run=server")
    grep -cE '(created|configured|unchanged|deleted)' "$DRY_RUN_FILE" \
      | head -n1 \
      | xargs -I{} echo "Operations: {}" >> "$TMP_SUMMARY"
    ;;
  wrangler)
    grep -E 'Total Upload|Outputs:' "$DRY_RUN_FILE" | head -n5 >> "$TMP_SUMMARY"
    ;;
  *)
    echo "(no automated summary for tool '$TOOL'; review full output)" >> "$TMP_SUMMARY"
    ;;
esac

# Compose the new block content
TMP_BLOCK=$(mktemp)
trap 'rm -f "$TMP_SUMMARY" "$TMP_BLOCK"' EXIT

{
  echo "## Plan summary"
  echo ""
  echo "**Tool**: $TOOL"
  echo ""
  echo "**Captured at**: $(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  echo ""
  echo "**Summary**:"
  echo ""
  echo '```'
  cat "$TMP_SUMMARY"
  echo '```'
  echo ""
  echo "**Full output**:"
  echo ""
  echo "<details>"
  echo "<summary>Click to expand (truncated to 200 lines)</summary>"
  echo ""
  echo '```'
  head -n 200 "$DRY_RUN_FILE"
  total_lines=$(wc -l < "$DRY_RUN_FILE")
  if [[ "$total_lines" -gt 200 ]]; then
    echo "... (truncated; $total_lines total lines)"
  fi
  echo '```'
  echo ""
  echo "</details>"
} > "$TMP_BLOCK"

# Get current body, strip existing plan block, append new
current_body=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body // ""') \
  || { echo "cannot read issue #$ISSUE_N" >&2; exit 2; }

TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_SUMMARY" "$TMP_BLOCK" "$TMP_BODY"' EXIT

echo "$current_body" \
  | perl -0777 -pe 's/<!--\s*ops-plan-begin\s*-->.*?<!--\s*ops-plan-end\s*-->\n*//gs' \
  > "$TMP_BODY"

{
  echo ""
  echo ""
  echo "<!-- ops-plan-begin -->"
  cat "$TMP_BLOCK"
  echo ""
  echo "<!-- ops-plan-end -->"
} >> "$TMP_BODY"

gh issue edit "$ISSUE_N" --repo "$REPO" --body-file "$TMP_BODY" >/dev/null \
  || { echo "failed to update issue #$ISSUE_N" >&2; exit 3; }

echo "plan summary embedded on #$ISSUE_N (tool: $TOOL)"
