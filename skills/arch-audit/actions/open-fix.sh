#!/usr/bin/env bash
# open-fix.sh — create a fix issue derived from an audit finding.
#
# Mostly identical to arch-shape's open-child.sh, but:
#   - Uses --audit-issue instead of --parent-issue (semantic clarity)
#   - Requires --severity
#   - Requires --findings (which audit findings this fix addresses)
#
# Usage:
#   open-fix.sh
#       --audit-issue N
#       --agent ROLE
#       --severity N
#       --findings "1,5,7"
#       --title "..."
#       --body-file PATH
#       [--deps "#X,#Y"]
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-audit}"
AUDIT_N=""
ROLE=""
SEVERITY=""
FINDINGS=""
TITLE=""
BODY_FILE=""
DEPS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit-issue)  AUDIT_N="$2"; shift 2 ;;
    --agent)        ROLE="$2"; shift 2 ;;
    --severity)     SEVERITY="$2"; shift 2 ;;
    --findings)     FINDINGS="$2"; shift 2 ;;
    --title)        TITLE="$2"; shift 2 ;;
    --body-file)    BODY_FILE="$2"; shift 2 ;;
    --deps)         DEPS="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --agent-id)     AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"      ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$AUDIT_N"   ]] && { echo "--audit-issue required" >&2; exit 1; }
[[ -z "$ROLE"      ]] && { echo "--agent required" >&2; exit 1; }
[[ -z "$SEVERITY"  ]] && { echo "--severity required" >&2; exit 1; }
[[ -z "$FINDINGS"  ]] && { echo "--findings required" >&2; exit 1; }
[[ -z "$TITLE"     ]] && { echo "--title required" >&2; exit 1; }
[[ -z "$BODY_FILE" || ! -f "$BODY_FILE" ]] && { echo "--body-file required and must exist" >&2; exit 1; }

case "$ROLE" in
  fe|be|ops|qa|design) ;;
  *) echo "invalid --agent: $ROLE" >&2; exit 1 ;;
esac
[[ "$SEVERITY" =~ ^[1-4]$ ]] || { echo "--severity must be 1,2,3,4" >&2; exit 1; }

LABELS="source:arch,agent:$ROLE"
if [[ -n "$DEPS" ]]; then
  LABELS="$LABELS,status:blocked"
else
  LABELS="$LABELS,status:ready"
fi

TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

cat "$BODY_FILE" > "$TMP"
{
  echo ""
  echo ""
  echo "<!-- parent: #$AUDIT_N -->"
  echo "<!-- audit-findings: $FINDINGS -->"
  echo "<!-- severity: $SEVERITY -->"
  if [[ -n "$DEPS" ]]; then
    echo "<!-- deps: $DEPS -->"
  fi
} >> "$TMP"

new_n=$(gh issue create --repo "$REPO" \
  --title "$TITLE" \
  --body-file "$TMP" \
  --label "$LABELS" \
  | grep -oE '/issues/[0-9]+' \
  | grep -oE '[0-9]+$')

[[ -z "$new_n" ]] && { echo "failed to extract new issue number" >&2; exit 2; }

echo "$new_n"
