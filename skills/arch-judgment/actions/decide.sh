#!/usr/bin/env bash
# decide.sh — record a judgment decision and route accordingly.
#
# Usage:
#   decide.sh
#       --issue N
#       --category {A|B|C|D|E}
#       --route-to TARGET                 (agent role; or "close" to close the issue)
#       --reason "..."
#       [--reset-rounds]                  (reset feedback-rounds to 0)
#       [--decision-file PATH]            (full decision-log markdown; if not given, build a minimal one)
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-judgment}"
ISSUE_N=""
CATEGORY=""
ROUTE_TO=""
REASON=""
RESET_ROUNDS=0
DECISION_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)         ISSUE_N="$2"; shift 2 ;;
    --category)      CATEGORY="$2"; shift 2 ;;
    --route-to)      ROUTE_TO="$2"; shift 2 ;;
    --reason)        REASON="$2"; shift 2 ;;
    --reset-rounds)  RESET_ROUNDS=1; shift ;;
    --decision-file) DECISION_FILE="$2"; shift 2 ;;
    --repo)          REPO="$2"; shift 2 ;;
    --agent-id)      AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"     ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N"  ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$CATEGORY" ]] && { echo "--category required" >&2; exit 1; }
[[ -z "$ROUTE_TO" ]] && { echo "--route-to required" >&2; exit 1; }
[[ -z "$REASON"   ]] && { echo "--reason required" >&2; exit 1; }

case "$CATEGORY" in
  A|B|C|D|E) ;;
  *) echo "invalid --category: $CATEGORY (must be A, B, C, D, or E)" >&2; exit 1 ;;
esac

case "$ROUTE_TO" in
  fe|be|ops|qa|design|debug|arch|arch-shape|arch-audit|arch-feedback|human-review|close) ;;
  *) echo "invalid --route-to: $ROUTE_TO" >&2; exit 1 ;;
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

# ─── Decision-log comment ───────────────────────────────────────────────────
COMMENT_TMP=$(mktemp)
trap 'rm -f "$COMMENT_TMP"' EXIT

if [[ -n "$DECISION_FILE" && -f "$DECISION_FILE" ]]; then
  cat "$DECISION_FILE" > "$COMMENT_TMP"
else
  # Minimal default
  {
    echo "## arch-judgment: decision"
    echo ""
    echo "**Category**: $CATEGORY"
    echo ""
    echo "**Routing**: $ROUTE_TO"
    echo ""
    echo "**Reason**: $REASON"
    echo ""
    if [[ "$RESET_ROUNDS" == "1" ]]; then
      echo "**Reset rounds**: yes"
      echo ""
    fi
  } > "$COMMENT_TMP"
fi

gh issue comment "$ISSUE_N" --repo "$REPO" --body-file "$COMMENT_TMP" >/dev/null \
  || { echo "failed to post decision comment on #$ISSUE_N" >&2; exit 3; }

# ─── Reset feedback-rounds if asked ─────────────────────────────────────────
if [[ "$RESET_ROUNDS" == "1" ]]; then
  REPO="$REPO" "$ISSUE_META_SH" set "$ISSUE_N" feedback-rounds 0 \
    || echo "warning: failed to reset feedback-rounds" >&2
fi

# ─── Take routing action ────────────────────────────────────────────────────
case "$ROUTE_TO" in
  close)
    gh issue close "$ISSUE_N" --repo "$REPO" >/dev/null \
      || { echo "failed to close #$ISSUE_N" >&2; exit 3; }
    echo "judgment closed #$ISSUE_N: $REASON"
    ;;
  human-review)
    # human-review is just a label, doesn't go through route.sh's agent state machine
    gh issue edit "$ISSUE_N" --repo "$REPO" --add-label "human-review" >/dev/null \
      || { echo "failed to label #$ISSUE_N as human-review" >&2; exit 3; }
    echo "judgment escalated #$ISSUE_N to human-review: $REASON"
    ;;
  *)
    "$ROUTE_SH" "$ISSUE_N" "$ROUTE_TO" \
      --repo "$REPO" \
      --agent-id "$AGENT_ID" \
      --reason "judgment-cat-$CATEGORY: $REASON" \
      >/dev/null \
      || { echo "failed to route #$ISSUE_N to $ROUTE_TO" >&2; exit 3; }
    echo "judgment routed #$ISSUE_N → $ROUTE_TO: $REASON"
    ;;
esac
