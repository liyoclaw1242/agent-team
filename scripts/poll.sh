#!/bin/bash
# Poll for tasks. For ARCH role, runs deterministic housekeeping BEFORE returning results.
# This is the ONLY way agents should poll. Embeds pre-triage so agents can't skip it.
#
# Usage: poll.sh <REPO_SLUG> <ROLE> [AGENT_ID]
# Output: JSON array of available issues (same as gh issue list output)
# Exit 0 = results (may be empty), 1 = error
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required}"
ROLE="${2:?ROLE required (be/fe/ops/arch/design/qa/debug)}"
AGENT_ID="${3:-unknown}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# ── ARCH housekeeping: runs EVERY cycle, BEFORE polling ──
if [ "$ROLE" = "arch" ]; then
  # 1. Auto-merge QA PASS + auto-route delivered PRs to QA
  bash "${SCRIPT_DIR}/pre-triage.sh" "$REPO_SLUG" 2>/dev/null || true

  # 2. Unblock issues whose deps are all resolved
  UNBLOCK_SCRIPT="${SCRIPT_DIR}/../skills/arch/actions/scan-unblock.sh"
  [ ! -f "$UNBLOCK_SCRIPT" ] && UNBLOCK_SCRIPT="$HOME/.claude/skills/arch/actions/scan-unblock.sh"
  [ -f "$UNBLOCK_SCRIPT" ] && bash "$UNBLOCK_SCRIPT" "$REPO_SLUG" 2>/dev/null || true

  # 3. Close orphaned status:done issues
  COMPLETE_SCRIPT="${SCRIPT_DIR}/../skills/arch/actions/scan-complete-requests.sh"
  [ ! -f "$COMPLETE_SCRIPT" ] && COMPLETE_SCRIPT="$HOME/.claude/skills/arch/actions/scan-complete-requests.sh"
  [ -f "$COMPLETE_SCRIPT" ] && bash "$COMPLETE_SCRIPT" "$REPO_SLUG" 2>/dev/null || true
fi

# ── Poll for tasks ──
if [ "$ROLE" = "arch" ]; then
  # ARCH has two task sources:
  #   1. New tasks (created by users/ARCH) → status:ready
  #   2. Routed back from other agents → status:review
  # Query both and merge results
  READY=$(gh issue list --repo "$REPO_SLUG" \
    --label "agent:arch" --label "status:ready" \
    --json number,title --jq '.[]' 2>/dev/null || true)
  REVIEW=$(gh issue list --repo "$REPO_SLUG" \
    --label "agent:arch" --label "status:review" \
    --json number,title --jq '.[]' 2>/dev/null || true)
  echo "$READY"
  echo "$REVIEW"
else
  gh issue list --repo "$REPO_SLUG" \
    --label "agent:${ROLE}" --label "status:ready" \
    --json number,title \
    --jq '.[]'
fi
