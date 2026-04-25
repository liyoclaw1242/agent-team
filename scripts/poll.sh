#!/usr/bin/env bash
# poll.sh — list issues claimable by an agent of a given role.
#
# Returns issue numbers, oldest-first by default (FIFO). The calling agent
# typically picks the first one and tries claims.sh on it.
#
# Usage:
#   poll.sh --role ROLE
#       [--repo OWNER/REPO]
#       [--limit N]               (default: 10)
#       [--order created|updated] (default: created)
#       [--json]                  (output JSON instead of plain numbers)
#
# Output:
#   Plain mode: one issue number per line, oldest-first
#   JSON mode:  array of {number, title, updated_at}
#
# Exit codes:
#   0 success (zero or more issues found)
#   1 argument error
#   2 GitHub error

set -euo pipefail

REPO="${REPO:-}"
ROLE=""
LIMIT=10
ORDER="created"
OUTPUT=plain

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)  REPO="$2"; shift 2 ;;
    --role)  ROLE="$2"; shift 2 ;;
    --limit) LIMIT="$2"; shift 2 ;;
    --order) ORDER="$2"; shift 2 ;;
    --json)  OUTPUT=json; shift ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO" ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ROLE" ]] && { echo "--role required" >&2; exit 1; }
case "$ROLE" in
  fe|be|ops|qa|design|debug|arch|arch-shape|arch-audit|arch-feedback|arch-judgment) ;;
  *) echo "invalid role: $ROLE" >&2; exit 1 ;;
esac
case "$ORDER" in created|updated) ;; *) echo "--order must be created or updated" >&2; exit 1 ;; esac

# ─── Query ──────────────────────────────────────────────────────────────────

if [[ "$OUTPUT" == "json" ]]; then
  gh issue list --repo "$REPO" \
    --label "agent:$ROLE" \
    --label "status:ready" \
    --state open \
    --limit "$LIMIT" \
    --json number,title,updatedAt,createdAt \
    --jq "sort_by(.${ORDER}At)" \
    || { echo "gh issue list failed" >&2; exit 2; }
else
  gh issue list --repo "$REPO" \
    --label "agent:$ROLE" \
    --label "status:ready" \
    --state open \
    --limit "$LIMIT" \
    --json number,createdAt,updatedAt \
    --jq "sort_by(.${ORDER}At) | .[].number" \
    || { echo "gh issue list failed" >&2; exit 2; }
fi
