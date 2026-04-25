#!/usr/bin/env bash
# deliver.sh — finalise an arch-shape decomposition.
#
# Posts a summary comment on the parent listing all child tasks, then routes
# the parent to status:done. This is called only after every child issue has
# been opened successfully and self-test has passed.
#
# Usage:
#   deliver.sh
#       --parent-issue N
#       --children "#142,#143,#144"
#       --reason "..."
#       [--adr-ref "ADR-NNNN"]              (optional; for architecture mode)
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-shape}"
PARENT_N=""
CHILDREN=""
REASON=""
ADR=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --parent-issue) PARENT_N="$2"; shift 2 ;;
    --children)     CHILDREN="$2"; shift 2 ;;
    --reason)       REASON="$2"; shift 2 ;;
    --adr-ref)      ADR="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --agent-id)     AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"     ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$PARENT_N" ]] && { echo "--parent-issue required" >&2; exit 1; }
[[ -z "$CHILDREN" ]] && { echo "--children required" >&2; exit 1; }
[[ -z "$REASON"   ]] && { echo "--reason required" >&2; exit 1; }

# Locate route.sh (auto-detect)
ROUTE_SH="${ROUTE_SH:-}"
if [[ -z "$ROUTE_SH" ]]; then
  if   [[ -x "$HOME/.claude/scripts/route.sh" ]]; then ROUTE_SH="$HOME/.claude/scripts/route.sh"
  elif [[ -x "scripts/route.sh"               ]]; then ROUTE_SH="$(pwd)/scripts/route.sh"
  else echo "route.sh not found" >&2; exit 1
  fi
fi

# ─── Self-test gate ─────────────────────────────────────────────────────────
# Verify each child has the required labels and parent marker.
echo "Self-test: verifying children..."

IFS=',' read -ra child_arr <<< "$CHILDREN"
for raw in "${child_arr[@]}"; do
  n=$(echo "$raw" | tr -d '#[:space:]')
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "invalid child: $raw" >&2; exit 2; }

  labels=$(gh issue view "$n" --repo "$REPO" --json labels \
             --jq '[.labels[].name] | join(" ")') \
    || { echo "cannot read child #$n" >&2; exit 2; }

  echo " $labels " | grep -q ' source:arch ' \
    || { echo "child #$n missing source:arch" >&2; exit 2; }
  echo " $labels " | grep -qE ' agent:(fe|be|ops|qa|design) ' \
    || { echo "child #$n missing agent:* label" >&2; exit 2; }
  echo " $labels " | grep -qE ' status:(ready|blocked) ' \
    || { echo "child #$n missing status label" >&2; exit 2; }

  body=$(gh issue view "$n" --repo "$REPO" --json body --jq '.body // ""') \
    || { echo "cannot read child #$n body" >&2; exit 2; }
  echo "$body" | grep -qE "<!--\s*parent:\s*#$PARENT_N\s*-->" \
    || { echo "child #$n missing or wrong parent marker" >&2; exit 2; }

  echo "  ✓ #$n"
done

# ─── Compose summary comment ────────────────────────────────────────────────
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

{
  echo "## ✅ Decomposition complete"
  echo ""
  echo "**Reason**: $REASON"
  echo ""
  if [[ -n "$ADR" ]]; then
    echo "**Decision recorded as**: $ADR"
    echo ""
  fi
  echo "**Child tasks**:"
  echo ""
  for raw in "${child_arr[@]}"; do
    n=$(echo "$raw" | tr -d '#[:space:]')
    title=$(gh issue view "$n" --repo "$REPO" --json title --jq '.title')
    role=$(gh issue view "$n" --repo "$REPO" --json labels \
             --jq '[.labels[].name] | map(select(startswith("agent:"))) | .[0] // ""' \
             | sed 's/^agent://')
    echo "- [ ] #$n — \`$role\` — $title"
  done
  echo ""
  echo "This parent issue will close automatically when all children are done."
  echo "(\`scan-complete-requests.sh\` handles this.)"
} > "$TMP"

# Post the comment
gh issue comment "$PARENT_N" --repo "$REPO" --body-file "$TMP" >/dev/null \
  || { echo "failed to comment on parent #$PARENT_N" >&2; exit 3; }

# ─── Route parent to done ───────────────────────────────────────────────────
# Note: parent stays open; scan-complete-requests.sh will close it once all
# children have closed. We just transition status to "done" semantically by
# routing back to agent:arch with status:done... actually, no — the parent
# stays at agent:arch + status:ready until children are done. The right state
# for the parent now is simply: ready (no longer needing arch-shape).
#
# But we don't want dispatcher to re-shape it. We mark it via metadata.
ISSUE_META_SH="${ISSUE_META_SH:-}"
if [[ -z "$ISSUE_META_SH" ]]; then
  if   [[ -x "$HOME/.claude/skills/_shared/actions/issue-meta.sh" ]]; then ISSUE_META_SH="$HOME/.claude/skills/_shared/actions/issue-meta.sh"
  elif [[ -x "skills/_shared/actions/issue-meta.sh"               ]]; then ISSUE_META_SH="$(pwd)/skills/_shared/actions/issue-meta.sh"
  fi
fi

if [[ -x "$ISSUE_META_SH" ]]; then
  REPO="$REPO" "$ISSUE_META_SH" set "$PARENT_N" decomposed-at "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
    || echo "warning: could not set decomposed-at marker" >&2
fi

# Now route parent to status:blocked with deps = the children list, so
# scan-unblock + scan-complete-requests handle the rest.
deps_marker=$(echo "$CHILDREN" | tr ',' ' ' | sed 's/  */, /g')
if [[ -x "$ISSUE_META_SH" ]]; then
  REPO="$REPO" "$ISSUE_META_SH" set "$PARENT_N" deps "$deps_marker" \
    || echo "warning: could not set deps marker" >&2
fi

"$ROUTE_SH" "$PARENT_N" "arch" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "decomposition delivered; awaiting children" \
  --status blocked \
  >/dev/null \
  || { echo "failed to route parent #$PARENT_N to blocked" >&2; exit 3; }

echo "delivered: parent #$PARENT_N → status:blocked, ${#child_arr[@]} children open"
