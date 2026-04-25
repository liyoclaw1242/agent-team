#!/usr/bin/env bash
# accept-feedback.sh — apply spec changes to a child issue, increment round
# counter, post the change-summary comment, route back to the implementer.
#
# Usage:
#   accept-feedback.sh
#       --issue N
#       --new-body-file PATH
#       --back-to ROLE                 (fe|be|ops|qa|design)
#       --change-summary "..."
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# What this guarantees:
#   - The issue body is replaced with the new body file content
#   - <!-- feedback-rounds: N+1 --> is set
#   - A comment is posted summarising what changed and why
#   - The issue routes back to the original role with status:ready
#   - Escalation rule is checked: if rounds would exceed 2, refuses and exits

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-feedback}"
ISSUE_N=""
BODY_FILE=""
BACK_TO=""
SUMMARY=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)           ISSUE_N="$2"; shift 2 ;;
    --new-body-file)   BODY_FILE="$2"; shift 2 ;;
    --back-to)         BACK_TO="$2"; shift 2 ;;
    --change-summary)  SUMMARY="$2"; shift 2 ;;
    --repo)            REPO="$2"; shift 2 ;;
    --agent-id)        AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"      ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N"   ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$BODY_FILE" || ! -f "$BODY_FILE" ]] && { echo "--new-body-file required and must exist" >&2; exit 1; }
[[ -z "$BACK_TO"   ]] && { echo "--back-to required" >&2; exit 1; }
[[ -z "$SUMMARY"   ]] && { echo "--change-summary required" >&2; exit 1; }

case "$BACK_TO" in
  fe|be|ops|qa|design) ;;
  *) echo "invalid --back-to: $BACK_TO" >&2; exit 1 ;;
esac

# Locate helpers
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

# ─── Check escalation limit BEFORE doing anything ───────────────────────────
current_rounds=$(REPO="$REPO" "$ISSUE_META_SH" get "$ISSUE_N" feedback-rounds 2>/dev/null || echo 0)
[[ "$current_rounds" =~ ^[0-9]+$ ]] || current_rounds=0

if [[ "$current_rounds" -ge 2 ]]; then
  echo "REFUSING: feedback-rounds=$current_rounds (limit=2). Escalate to arch-judgment instead." >&2
  echo "Run: bash route.sh $ISSUE_N arch-judgment --reason 'feedback round limit'" >&2
  exit 4
fi

new_rounds=$((current_rounds + 1))

# ─── Read current body to preserve metadata footer ──────────────────────────
# The new body file should contain the new spec only. We preserve the issue's
# existing HTML comment markers (parent, deps, etc.) by re-applying them.
existing_body=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body // ""') \
  || { echo "cannot read issue #$ISSUE_N" >&2; exit 2; }

# Extract existing markers (everything inside HTML comments)
existing_markers=$(echo "$existing_body" | grep -oE '<!--[^>]*-->' || true)

# Assemble new body: user's new content + preserved markers (excluding feedback-rounds, we'll set fresh)
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

cat "$BODY_FILE" > "$TMP"
echo "" >> "$TMP"
echo "" >> "$TMP"

while IFS= read -r marker; do
  # Skip feedback-rounds — we'll set it via issue-meta.sh
  [[ "$marker" == *"feedback-rounds:"* ]] && continue
  echo "$marker" >> "$TMP"
done <<< "$existing_markers"

# Replace body
gh issue edit "$ISSUE_N" --repo "$REPO" --body-file "$TMP" >/dev/null \
  || { echo "failed to update body of #$ISSUE_N" >&2; exit 3; }

# Set feedback-rounds marker
REPO="$REPO" "$ISSUE_META_SH" set "$ISSUE_N" feedback-rounds "$new_rounds" \
  || { echo "warning: failed to set feedback-rounds marker" >&2; }

# ─── Change summary comment ─────────────────────────────────────────────────
COMMENT_TMP=$(mktemp)
{
  echo "## arch-feedback: accepted (round $new_rounds)"
  echo ""
  echo "**What changed in the spec:**"
  echo ""
  echo "$SUMMARY"
  echo ""
  echo "Routing back to \`agent:$BACK_TO\`. Pick up the updated spec on your next poll."
  if [[ "$new_rounds" -ge 2 ]]; then
    echo ""
    echo "⚠️ This is round 2. Further pushback will escalate to arch-judgment automatically."
  fi
} > "$COMMENT_TMP"

gh issue comment "$ISSUE_N" --repo "$REPO" --body-file "$COMMENT_TMP" >/dev/null \
  || echo "warning: failed to post change summary on #$ISSUE_N" >&2
rm -f "$COMMENT_TMP"

# ─── Route back ──────────────────────────────────────────────────────────────
"$ROUTE_SH" "$ISSUE_N" "$BACK_TO" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "feedback accepted (round $new_rounds): $SUMMARY" \
  >/dev/null \
  || { echo "failed to route #$ISSUE_N back to $BACK_TO" >&2; exit 3; }

echo "accepted feedback on #$ISSUE_N: round $new_rounds, routed to agent:$BACK_TO"
