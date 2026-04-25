#!/usr/bin/env bash
# open-child.sh — create a child issue with all required arch-shape provenance.
#
# Usage:
#   open-child.sh
#       --parent-issue N
#       --agent ROLE                 (fe|be|ops|qa|design)
#       --title "..."
#       --body-file PATH
#       [--deps "#X,#Y"]              (optional; comma-separated, with hashes)
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Prints the new issue number to stdout.
#
# What this guarantees:
#   - The child has source:arch (provenance)
#   - The child has the right agent:* label
#   - The child has status:ready (or status:blocked if --deps was supplied)
#   - The child body has <!-- parent: #N --> marker
#   - The child body has <!-- deps: ... --> marker if --deps supplied

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-shape}"
PARENT_N=""
ROLE=""
TITLE=""
BODY_FILE=""
DEPS=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-issue) PARENT_N="$2"; shift 2 ;;
    --agent)        ROLE="$2"; shift 2 ;;
    --title)        TITLE="$2"; shift 2 ;;
    --body-file)    BODY_FILE="$2"; shift 2 ;;
    --deps)         DEPS="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --agent-id)     AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"     ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$PARENT_N" ]] && { echo "--parent-issue required" >&2; exit 1; }
[[ -z "$ROLE"     ]] && { echo "--agent required" >&2; exit 1; }
[[ -z "$TITLE"    ]] && { echo "--title required" >&2; exit 1; }
[[ -z "$BODY_FILE" || ! -f "$BODY_FILE" ]] && { echo "--body-file required and must exist" >&2; exit 1; }

case "$ROLE" in
  fe|be|ops|qa|design) ;;
  *) echo "invalid --agent: $ROLE" >&2; exit 1 ;;
esac

# Construct labels list
LABELS="source:arch,agent:$ROLE"
if [[ -n "$DEPS" ]]; then
  LABELS="$LABELS,status:blocked"
else
  LABELS="$LABELS,status:ready"
fi

# Construct full body: append parent + deps markers to user-supplied body.
TMP_BODY=$(mktemp)
trap 'rm -f "$TMP_BODY"' EXIT

cat "$BODY_FILE" > "$TMP_BODY"
{
  echo ""
  echo ""
  echo "<!-- parent: #$PARENT_N -->"
  if [[ -n "$DEPS" ]]; then
    echo "<!-- deps: $DEPS -->"
  fi
} >> "$TMP_BODY"

# Create the issue
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

# Audit comment back on parent (lightweight — full summary comes from deliver.sh)
echo "$new_n"
