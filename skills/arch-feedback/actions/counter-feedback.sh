#!/usr/bin/env bash
# counter-feedback.sh — post an explanatory counter, increment round counter,
# route back to the implementer with the spec UNCHANGED.
#
# Usage:
#   counter-feedback.sh
#       --issue N
#       --back-to ROLE                (fe|be|ops|qa|design)
#       --rationale-file PATH
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-feedback}"
ISSUE_N=""
BACK_TO=""
RATIONALE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)           ISSUE_N="$2"; shift 2 ;;
    --back-to)         BACK_TO="$2"; shift 2 ;;
    --rationale-file)  RATIONALE_FILE="$2"; shift 2 ;;
    --repo)            REPO="$2"; shift 2 ;;
    --agent-id)        AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"           ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N"        ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$BACK_TO"        ]] && { echo "--back-to required" >&2; exit 1; }
[[ -z "$RATIONALE_FILE" || ! -f "$RATIONALE_FILE" ]] && { echo "--rationale-file required and must exist" >&2; exit 1; }

case "$BACK_TO" in
  fe|be|ops|qa|design) ;;
  *) echo "invalid --back-to: $BACK_TO" >&2; exit 1 ;;
esac

# Helpers
ROUTE_SH="${ROUTE_SH:-}"
if [[ -z "$ROUTE_SH" ]]; then
  if   [[ -x "$HOME/.claude/scripts/route.sh" ]]; then ROUTE_SH="$HOME/.claude/scripts/route.sh"
  elif [[ -x "scripts/route.sh"               ]]; then ROUTE_SH="$(pwd)/scripts/route.sh"
  else echo "route.sh not found" >&2; exit 1
  fi
fi

ISSUE_META_SH="${ISSUE_META_SH:-}"
if [[ -z "$ISSUE_META_SH" ]]; then
  if   [[ -x "$HOME/.claude/skills/_shared/actions/issue-meta.sh" ]]; then ISSUE_META_SH="$HOME/.claude/skills/_shared/actions/issue-meta.sh"
  elif [[ -x "skills/_shared/actions/issue-meta.sh"               ]]; then ISSUE_META_SH="$(pwd)/skills/_shared/actions/issue-meta.sh"
  else echo "issue-meta.sh not found" >&2; exit 1
  fi
fi

# ─── Escalation check ───────────────────────────────────────────────────────
current_rounds=$(REPO="$REPO" "$ISSUE_META_SH" get "$ISSUE_N" feedback-rounds 2>/dev/null || echo 0)
[[ "$current_rounds" =~ ^[0-9]+$ ]] || current_rounds=0

if [[ "$current_rounds" -ge 2 ]]; then
  echo "REFUSING: feedback-rounds=$current_rounds (limit=2). Escalate to arch-judgment instead." >&2
  exit 4
fi

new_rounds=$((current_rounds + 1))

# ─── Counter comment ────────────────────────────────────────────────────────
COMMENT_TMP=$(mktemp)
trap 'rm -f "$COMMENT_TMP"' EXIT

{
  echo "## arch-feedback: countered (round $new_rounds)"
  echo ""
  echo "**Original spec stands.** Rationale:"
  echo ""
  cat "$RATIONALE_FILE"
  echo ""
  echo "Routing back to \`agent:$BACK_TO\`. If you have additional context that wasn't in the previous feedback, you can push back again — but note that round 2 is the last round before automatic escalation to arch-judgment."
  if [[ "$new_rounds" -ge 2 ]]; then
    echo ""
    echo "⚠️ This was round 2. Any further pushback will escalate."
  fi
} > "$COMMENT_TMP"

gh issue comment "$ISSUE_N" --repo "$REPO" --body-file "$COMMENT_TMP" >/dev/null \
  || { echo "failed to post counter comment on #$ISSUE_N" >&2; exit 3; }

# Update round counter
REPO="$REPO" "$ISSUE_META_SH" set "$ISSUE_N" feedback-rounds "$new_rounds" \
  || echo "warning: failed to update feedback-rounds marker" >&2

# Route back
"$ROUTE_SH" "$ISSUE_N" "$BACK_TO" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "feedback countered (round $new_rounds): spec unchanged" \
  >/dev/null \
  || { echo "failed to route #$ISSUE_N back to $BACK_TO" >&2; exit 3; }

echo "countered feedback on #$ISSUE_N: round $new_rounds, routed to agent:$BACK_TO"
