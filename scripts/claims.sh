#!/usr/bin/env bash
# claims.sh — atomically claim an issue for an agent.
#
# Sets status:in-progress, posts a structured claim comment with the agent's
# id and timestamp. If the issue is not status:ready, exits 3 (conflict).
#
# Usage:
#   claims.sh <issue-number>
#       --agent-id ID
#       [--repo OWNER/REPO]
#       [--note "TEXT"]
#
# Exit codes:
#   0 claimed
#   1 argument error
#   2 GitHub error
#   3 already claimed / not ready

set -euo pipefail

ISSUE_N="${1:-}"; shift || true
[[ -z "$ISSUE_N" ]] && { echo "usage: claims.sh <issue-number> --agent-id ID" >&2; exit 1; }
[[ "$ISSUE_N" =~ ^[0-9]+$ ]] || { echo "issue-number must be numeric" >&2; exit 1; }

REPO="${REPO:-}"
AGENT_ID=""
NOTE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)     REPO="$2"; shift 2 ;;
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --note)     NOTE="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO" ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$AGENT_ID" ]] && { echo "--agent-id required" >&2; exit 1; }

# ─── Read current state ─────────────────────────────────────────────────────

labels=$(gh issue view "$ISSUE_N" --repo "$REPO" --json labels \
  --jq '[.labels[].name] | join(" ")') || { echo "cannot read issue #$ISSUE_N" >&2; exit 2; }

if ! echo " $labels " | grep -q ' status:ready '; then
  current_status=$(echo "$labels" | grep -oE 'status:[a-z-]+' | head -n1 || echo "<none>")
  echo "cannot claim #$ISSUE_N: status is $current_status, expected status:ready" >&2
  exit 3
fi

# ─── Atomic flip: ready → in-progress ───────────────────────────────────────
#
# GitHub does not give us true CAS, but `gh issue edit` is essentially
# linearisable from the API perspective. The race window is between read
# and write; for stronger isolation see dispatcher's TOCTOU re-read pattern.

if ! gh issue edit "$ISSUE_N" --repo "$REPO" \
       --add-label "status:in-progress" \
       --remove-label "status:ready" >/dev/null; then
  echo "gh edit failed; another agent may have claimed first" >&2
  exit 3
fi

# ─── Claim comment ──────────────────────────────────────────────────────────

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
comment=$(cat <<EOF
🔒 **Claimed** by \`$AGENT_ID\` at $ts

${NOTE:+**Note:** $NOTE}

This issue is now status:in-progress. Other agents should not work on it concurrently.
EOF
)

gh issue comment "$ISSUE_N" --repo "$REPO" --body "$comment" >/dev/null \
  || echo "warning: claimed but failed to comment on #$ISSUE_N" >&2

echo "claimed #$ISSUE_N for $AGENT_ID"
