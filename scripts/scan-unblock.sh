#!/usr/bin/env bash
# scan-unblock.sh — sweep all status:blocked issues and unblock those whose
# <!-- deps: #N1, #N2 --> markers have all been closed.
#
# Should be run on a cron (every few minutes is fine). Idempotent.
#
# Usage:
#   scan-unblock.sh
#       [--repo OWNER/REPO]
#       [--dry-run]
#
# Exit codes:
#   0 success (zero or more unblocked)
#   1 argument error
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

ROUTE_SH="${ROUTE_SH:-}"
if [[ -z "$ROUTE_SH" ]]; then
  if [[ -x "$HOME/.claude/scripts/route.sh" ]]; then
    ROUTE_SH="$HOME/.claude/scripts/route.sh"
  elif [[ -x "$(dirname "$0")/route.sh" ]]; then
    ROUTE_SH="$(dirname "$0")/route.sh"
  else
    echo "route.sh not found" >&2; exit 1
  fi
fi

# ─── Find blocked issues ────────────────────────────────────────────────────

blocked=$(gh issue list --repo "$REPO" \
  --label "status:blocked" \
  --state open \
  --limit 100 \
  --json number) || { echo "gh issue list failed" >&2; exit 2; }

count_total=$(echo "$blocked" | jq 'length')
count_unblocked=0
count_failed=0

echo "scanning $count_total blocked issues..."

# ─── For each blocked issue, check its deps ─────────────────────────────────

for n in $(echo "$blocked" | jq -r '.[].number'); do
  body=$(gh issue view "$n" --repo "$REPO" --json body --jq '.body // ""') \
    || { count_failed=$((count_failed + 1)); continue; }

  # Extract deps from <!-- deps: #N1, #N2 --> marker
  deps_raw=$(echo "$body" | grep -oP '<!--\s*deps:\s*\K[^>]*?(?=\s*-->)' | head -n1 || true)
  if [[ -z "$deps_raw" ]]; then
    echo "  #$n: no deps marker — already unblockable. Unblocking."
    [[ "$DRY_RUN" == "1" ]] && continue
    "$ROUTE_SH" "$n" "$(get_current_agent "$n")" \
      --repo "$REPO" \
      --agent-id "scan-unblock" \
      --reason "no remaining deps" \
      --status ready \
      && count_unblocked=$((count_unblocked + 1))
    continue
  fi

  # Parse list of issue numbers from "#142, #143, #144"
  dep_nums=$(echo "$deps_raw" | grep -oE '#[0-9]+' | tr -d '#')
  all_closed=true
  open_deps=()
  for d in $dep_nums; do
    state=$(gh issue view "$d" --repo "$REPO" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
    if [[ "$state" != "CLOSED" ]]; then
      all_closed=false
      open_deps+=("#$d:$state")
    fi
  done

  if [[ "$all_closed" == "true" ]]; then
    echo "  #$n: all deps closed → unblock"
    if [[ "$DRY_RUN" == "1" ]]; then
      continue
    fi
    target_agent=$(gh issue view "$n" --repo "$REPO" --json labels \
                     --jq '[.labels[].name] | map(select(startswith("agent:"))) | .[0] // "agent:arch"' \
                     | sed 's/^agent://')
    if "$ROUTE_SH" "$n" "$target_agent" \
         --repo "$REPO" \
         --agent-id "scan-unblock" \
         --reason "all deps closed" \
         --status ready; then
      count_unblocked=$((count_unblocked + 1))
    else
      count_failed=$((count_failed + 1))
    fi
  else
    echo "  #$n: still blocked on ${open_deps[*]}"
  fi
done

echo "done: $count_unblocked unblocked, $count_failed failed of $count_total"
[[ $count_failed -eq 0 ]] && exit 0 || exit 2

# Helper used in early-return branch above (for completeness; technically
# defined after use which works in bash because functions are looked up at
# call time, but cleaner to keep top-level for readability).
get_current_agent() {
  gh issue view "$1" --repo "$REPO" --json labels \
    --jq '[.labels[].name] | map(select(startswith("agent:"))) | .[0] // "agent:arch"' \
    | sed 's/^agent://'
}
