#!/usr/bin/env bash
# open-consultation.sh — open an advisor consultation issue and wire it to its
# parent as a dep.
#
# Usage:
#   open-consultation.sh
#       --parent-issue N
#       --advisor {fe-advisor|be-advisor|ops-advisor|design-advisor}
#       --questions-file PATH
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Prints the consultation issue number to stdout. The caller is responsible
# for adding the consultation number to the parent's <!-- deps: --> marker
# (use issue-meta.sh set deps "#1,#2,...") and routing the parent to
# status:blocked.

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-shape}"
PARENT_N=""
ADVISOR=""
Q_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-issue)    PARENT_N="$2"; shift 2 ;;
    --advisor)         ADVISOR="$2"; shift 2 ;;
    --questions-file)  Q_FILE="$2"; shift 2 ;;
    --repo)            REPO="$2"; shift 2 ;;
    --agent-id)        AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"     ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$PARENT_N" ]] && { echo "--parent-issue required" >&2; exit 1; }
[[ -z "$ADVISOR"  ]] && { echo "--advisor required" >&2; exit 1; }
[[ -z "$Q_FILE" || ! -f "$Q_FILE" ]] && { echo "--questions-file required and must exist" >&2; exit 1; }

case "$ADVISOR" in
  fe-advisor|be-advisor|ops-advisor|design-advisor) ;;
  *) echo "invalid --advisor: $ADVISOR" >&2; exit 1 ;;
esac

# Title format makes consultations easy to find in issue list
parent_title=$(gh issue view "$PARENT_N" --repo "$REPO" --json title --jq '.title')
TITLE="[Consultation] $ADVISOR: $parent_title"

# Body: the questions, plus a reminder of the structured-advice schema
TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_BODY"' EXIT

{
  echo "Consulting on parent: #$PARENT_N"
  echo ""
  echo "## Questions from arch-shape"
  echo ""
  cat "$Q_FILE"
  echo ""
  echo "---"
  echo ""
  echo "## Required response format"
  echo ""
  echo "Reply with a comment matching this structure exactly. arch-shape parses these sections."
  echo ""
  echo '```'
  echo "## Advice from $ADVISOR"
  echo ""
  echo "### Existing constraints"
  echo "- (file:line anchors when relevant)"
  echo ""
  echo "### Suggested approach"
  echo "- (high level, no code)"
  echo ""
  echo "### Conflicts with request"
  echo "- (or: none)"
  echo ""
  echo "### Estimated scope"
  echo "- (X files, Y new components — S/M/L)"
  echo ""
  echo "### Risks"
  echo "- (technical debt, future flexibility lost, etc.)"
  echo ""
  echo "### Drift noticed"
  echo "- (places where codebase differs from arch-ddd; or: none)"
  echo '```'
  echo ""
  echo "When you've posted the response, close this issue."
  echo ""
  echo ""
  echo "<!-- parent: #$PARENT_N -->"
  echo "<!-- consultation-of: #$PARENT_N -->"
  echo "<!-- intake-kind: consultation -->"
} > "$TMP_BODY"

LABELS="source:arch,agent:$ADVISOR,status:ready"

new_n=$(gh issue create --repo "$REPO" \
  --title "$TITLE" \
  --body-file "$TMP_BODY" \
  --label "$LABELS" \
  | grep -oE '/issues/[0-9]+' \
  | grep -oE '[0-9]+$')

if [[ -z "$new_n" ]]; then
  echo "failed to extract new issue number" >&2
  exit 2
fi

echo "$new_n"
