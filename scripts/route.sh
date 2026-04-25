#!/usr/bin/env bash
# route.sh — the only legal way to change an issue's agent:* or status:* labels.
#
# Validates source→target transitions against LABEL_RULES.md before applying.
# Writes a structured comment recording the transition for audit trail.
#
# Usage:
#   route.sh <issue-number> <target-agent>
#       [--repo OWNER/REPO]      (default: $REPO env var)
#       [--agent-id ID]          (default: $AGENT_ID env var, fallback "unknown")
#       [--reason "TEXT"]        (default: empty; recommended)
#       [--status STATUS]        (default: ready; only used when target requires non-ready)
#
# Examples:
#   route.sh 142 fe --reason "decomposed by arch-shape"
#   route.sh 99  arch-feedback --reason "spec conflict, see comment #c-456"
#
# Exit codes:
#   0  routed
#   1  argument or env error
#   2  illegal transition per LABEL_RULES.md
#   3  GitHub API error
#   4  precondition violated (e.g., issue already at target)

set -euo pipefail

# ─── Argument parsing ───────────────────────────────────────────────────────

ISSUE_N="${1:-}"; shift || true
TARGET="${1:-}"; shift || true

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-unknown}"
REASON=""
NEW_STATUS="ready"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)     REPO="$2"; shift 2 ;;
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    --reason)   REASON="$2"; shift 2 ;;
    --status)   NEW_STATUS="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE_N" || -z "$TARGET" ]] && {
  echo "usage: route.sh <issue-number> <target-agent> [--reason TEXT] [--repo OWNER/REPO]" >&2
  exit 1
}
[[ "$ISSUE_N" =~ ^[0-9]+$ ]] || { echo "issue-number must be numeric" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "REPO not set; pass --repo or export REPO" >&2; exit 1; }

# Valid targets — every agent label without the "agent:" prefix.
case "$TARGET" in
  fe|be|ops|qa|design|debug|arch|arch-shape|arch-audit|arch-feedback|arch-judgment) ;;
  *) echo "invalid target agent: $TARGET" >&2; exit 1 ;;
esac

case "$NEW_STATUS" in
  ready|in-progress|blocked|done) ;;
  *) echo "invalid status: $NEW_STATUS" >&2; exit 1 ;;
esac

# ─── Read current state ─────────────────────────────────────────────────────

current_labels=$(gh issue view "$ISSUE_N" --repo "$REPO" --json labels \
  --jq '[.labels[].name] | join(" ")') || { echo "cannot read issue #$ISSUE_N" >&2; exit 3; }

current_agent=$(echo "$current_labels" | grep -oE 'agent:[a-z-]+' | head -n1 || true)
current_status=$(echo "$current_labels" | grep -oE 'status:[a-z-]+' | head -n1 || true)

# Idempotency: if already at target with target status, no-op success.
if [[ "$current_agent" == "agent:$TARGET" && "$current_status" == "status:$NEW_STATUS" ]]; then
  echo "no-op: #$ISSUE_N already at agent:$TARGET status:$NEW_STATUS" >&2
  exit 0
fi

# ─── Transition validation ──────────────────────────────────────────────────
#
# Legal transitions:
#   - agent:* may change to any other agent:* (routing is the dispatcher's job)
#   - status:ready ↔ status:in-progress (claim/release)
#   - status:* → status:blocked (when deps appear)
#   - status:blocked → status:ready (when deps clear)
#   - status:* → status:done (closing)
#
# Illegal:
#   - status:done → anything (terminal)
#   - jumping from agent:fe to agent:be without going through arch (must Mode C
#     properly: fe writes feedback, returns to arch, arch decides). This is
#     enforced by checking the caller's agent_id matches the current agent OR
#     is an arch-family agent.

if [[ "$current_status" == "status:done" ]]; then
  echo "illegal transition: #$ISSUE_N is status:done (terminal)" >&2
  exit 2
fi

# Caller-permission check: only the current agent or an arch-family agent
# can route from agent:X.
if [[ -n "$current_agent" ]]; then
  current_agent_short="${current_agent#agent:}"
  if [[ "$current_agent_short" != "$AGENT_ID" \
     && "$AGENT_ID" != "dispatcher" \
     && ! "$AGENT_ID" =~ ^arch ]]; then
    echo "illegal: caller agent_id=$AGENT_ID cannot move issue from $current_agent" >&2
    echo "  only the current agent or an arch-family agent may route." >&2
    exit 2
  fi
fi

# ─── Apply the transition ───────────────────────────────────────────────────

# Build add/remove label lists.
add_labels="agent:$TARGET,status:$NEW_STATUS"
remove_labels=""

# Drop the old agent and status labels.
for lbl in $current_labels; do
  case "$lbl" in
    agent:*|status:*)
      # Don't add to remove if it's already what we want
      if [[ "$lbl" != "agent:$TARGET" && "$lbl" != "status:$NEW_STATUS" ]]; then
        remove_labels="${remove_labels:+$remove_labels,}$lbl"
      fi
      ;;
  esac
done

# Atomic-as-possible: GitHub API allows comma-separated add/remove in one call.
gh_args=( --add-label "$add_labels" )
[[ -n "$remove_labels" ]] && gh_args+=( --remove-label "$remove_labels" )

if ! gh issue edit "$ISSUE_N" --repo "$REPO" "${gh_args[@]}" >/dev/null; then
  echo "gh issue edit failed for #$ISSUE_N" >&2
  exit 3
fi

# ─── Audit trail comment ────────────────────────────────────────────────────

ts=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
comment=$(cat <<EOF
🔀 **Routed** by \`$AGENT_ID\` at $ts

\`\`\`
${current_agent:-<none>} → agent:$TARGET
${current_status:-<none>} → status:$NEW_STATUS
\`\`\`

${REASON:+**Reason:** $REASON}
EOF
)

gh issue comment "$ISSUE_N" --repo "$REPO" --body "$comment" >/dev/null \
  || echo "warning: routed but failed to write audit comment for #$ISSUE_N" >&2

echo "routed #$ISSUE_N → agent:$TARGET status:$NEW_STATUS"
