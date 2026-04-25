#!/usr/bin/env bash
# scan-complete-requests.sh — sweep parent issues whose children are all done,
# close them, and link them to the original Hermes/human request comment.
#
# A parent issue has children if other issues reference it via
# <!-- parent: #PARENT --> marker in their body.
#
# Usage:
#   scan-complete-requests.sh
#       [--repo OWNER/REPO]
#       [--dry-run]
#
# Exit codes:
#   0 success
#   1 arg error
#   2 partial failure

set -euo pipefail

REPO="${REPO:-}"
DRY_RUN=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)    REPO="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO" ]] && { echo "REPO not set" >&2; exit 1; }

# ─── Find candidate parents: open issues whose body has been referenced
# as <!-- parent: #N --> by at least one child ─────────────────────────────

# Strategy: list open issues, then for each see if there exist ≥1 issues
# with that issue's number in their parent marker. To avoid scanning every
# issue's body, we use the children's body-content approach instead:
# enumerate all issues whose body contains <!-- parent: --> and group them.

# Get all open issues with their body markers and labels.
all_issues=$(gh issue list --repo "$REPO" \
  --state all \
  --limit 500 \
  --json number,state,body,labels) \
  || { echo "gh issue list failed" >&2; exit 2; }

# Build a mapping of parent → list of child numbers and child states.
# Use jq to do this.
parent_children=$(echo "$all_issues" | jq -r '
  map({
    number,
    state,
    parent: (.body // "" | capture("<!--\\s*parent:\\s*#(?<n>[0-9]+)\\s*-->"; "i").n // null)
  })
  | map(select(.parent != null))
  | group_by(.parent)
  | map({parent: .[0].parent, children: map({number, state})})
')

count_closed=0
count_failed=0

for row in $(echo "$parent_children" | jq -c '.[]'); do
  parent=$(echo "$row" | jq -r '.parent')
  total=$(echo "$row" | jq '.children | length')
  open=$(echo "$row" | jq '.children | map(select(.state == "OPEN")) | length')

  # Skip if parent itself is already closed.
  parent_state=$(gh issue view "$parent" --repo "$REPO" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
  [[ "$parent_state" != "OPEN" ]] && continue

  if [[ "$open" -gt 0 ]]; then
    echo "  parent #$parent: $open of $total children still open"
    continue
  fi

  echo "  parent #$parent: all $total children done → closing parent"
  if [[ "$DRY_RUN" == "1" ]]; then
    continue
  fi

  # Build close comment with summary of what was delivered.
  child_list=$(echo "$row" | jq -r '.children | map("- #\(.number)") | join("\n")')
  comment=$(cat <<EOF
✅ **Parent request complete** — all subtasks merged.

Delivered subtasks:
$child_list

Closing this request.
EOF
)
  if gh issue comment "$parent" --repo "$REPO" --body "$comment" >/dev/null \
     && gh issue close "$parent" --repo "$REPO" >/dev/null; then
    count_closed=$((count_closed + 1))
  else
    count_failed=$((count_failed + 1))
  fi
done

echo "done: $count_closed closed, $count_failed failed"
[[ $count_failed -eq 0 ]] && exit 0 || exit 2
