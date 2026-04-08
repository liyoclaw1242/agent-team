#!/bin/bash
# Route an issue to a target role. Enforces routing rules before changing labels.
#
# Usage: route.sh <REPO_SLUG> <ISSUE_NUMBER> <TARGET_ROLE> [AGENT_ID]
#   TARGET_ROLE: fe, be, ops, qa, design, debug, arch, merge, done
#   "merge" = merge the PR + close issue + mark done
#   "done"  = close issue + mark done (no PR)
#
# Exit 0 = routed, 1 = blocked by validation
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required}"
ISSUE_N="${2:?ISSUE_NUMBER required}"
TARGET="${3:?TARGET_ROLE required (fe/be/ops/qa/design/debug/arch/merge/done)}"
AGENT_ID="${4:-unknown}"

# ── Gather current state ──
LABELS=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json labels --jq '[.labels[].name] | join(",")')
COMMENTS=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json comments --jq '.comments')

# Extract last verdict (if any)
QA_PASS=$(echo "$COMMENTS" | jq -r '[.[].body | select(test("Verdict.*PASS|Code.*APPROVED|all.*pass"; "i"))] | last // empty')
QA_FAIL=$(echo "$COMMENTS" | jq -r '[.[].body | select(test("Verdict.*FAIL|Code.*REJECT"; "i"))] | last // empty')
DESIGN_APPROVED=$(echo "$COMMENTS" | jq -r '[.[].body | select(test("Verdict.*APPROVED|Visual.*APPROVED"; "i"))] | last // empty')
DESIGN_NEEDS_CHANGES=$(echo "$COMMENTS" | jq -r '[.[].body | select(test("Verdict.*NEEDS.CHANGES|Visual.*NEEDS.CHANGES"; "i"))] | last // empty')

# Find associated PR
PR_NUMBER=$(gh pr list --repo "$REPO_SLUG" --search "closes #${ISSUE_N}" --json number --jq '.[0].number // empty' 2>/dev/null || true)

# ── Validation rules ──

# Rule 0: Block if pre-triage already handled this issue recently
# pre-triage.sh leaves comments containing "pre-triage" when it routes or merges.
# If such a comment exists within the last 10 minutes, block all label changes.
PRETRIAGE_COMMENT_TS=$(echo "$COMMENTS" | jq -r '[.[] | select(.body | test("pre-triage"; "i")) | .createdAt] | last // empty')
if [ -n "$PRETRIAGE_COMMENT_TS" ]; then
  AGE=$(python3 -c "
from datetime import datetime, timezone
ts = datetime.fromisoformat('${PRETRIAGE_COMMENT_TS}'.replace('Z','+00:00'))
now = datetime.now(timezone.utc)
print(int((now - ts).total_seconds()))
" 2>/dev/null || echo "9999")
  if [ "$AGE" -lt 600 ] && [ "$AGE" -ge 0 ]; then
    echo "BLOCKED: #${ISSUE_N} was handled by pre-triage ${AGE}s ago. Cannot override."
    echo "  Wait 10 minutes or resolve manually."
    exit 1
  fi
fi

# Rule 1: Don't route to QA if QA already gave a verdict
if [ "$TARGET" = "qa" ]; then
  if [ -n "$QA_PASS" ] || [ -n "$QA_FAIL" ]; then
    echo "BLOCKED: QA already gave a verdict on #${ISSUE_N}. Cannot re-route to QA."
    echo "  QA_PASS='${QA_PASS:0:80}'"
    echo "  QA_FAIL='${QA_FAIL:0:80}'"
    echo "  → If QA passed, use: route.sh $REPO_SLUG $ISSUE_N merge"
    echo "  → If QA failed, route to implementer: route.sh $REPO_SLUG $ISSUE_N fe"
    exit 1
  fi
fi

# Rule 2: Don't route to design if design already gave a verdict
if [ "$TARGET" = "design" ]; then
  if [ -n "$DESIGN_APPROVED" ] || [ -n "$DESIGN_NEEDS_CHANGES" ]; then
    echo "BLOCKED: Design already gave a verdict on #${ISSUE_N}. Cannot re-route to Design."
    exit 1
  fi
fi

# Rule 3: If QA passed and no design concern, suggest merge instead of routing
if [ "$TARGET" != "merge" ] && [ "$TARGET" != "done" ] && [ "$TARGET" != "design" ]; then
  if [ -n "$QA_PASS" ] && [ -z "$DESIGN_NEEDS_CHANGES" ]; then
    echo "WARN: QA already PASSED on #${ISSUE_N}. Consider merging instead."
    echo "  → route.sh $REPO_SLUG $ISSUE_N merge"
  fi
fi

# ── Execute routing ──

case "$TARGET" in
  merge)
    if [ -z "$PR_NUMBER" ]; then
      echo "BLOCKED: No PR found for #${ISSUE_N}. Cannot merge."
      exit 1
    fi
    echo "Merging PR #${PR_NUMBER} for issue #${ISSUE_N}..."
    gh pr merge "$PR_NUMBER" --repo "$REPO_SLUG" --squash --delete-branch
    gh issue close "$ISSUE_N" --repo "$REPO_SLUG"
    # Remove all agent/status labels, add done
    for LABEL in $(echo "$LABELS" | tr ',' '\n' | grep -E '^(agent:|status:)'); do
      gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" --remove-label "$LABEL" 2>/dev/null || true
    done
    gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" --add-label "status:done"
    echo "MERGED: PR #${PR_NUMBER}, issue #${ISSUE_N} closed."
    ;;

  done)
    gh issue close "$ISSUE_N" --repo "$REPO_SLUG"
    for LABEL in $(echo "$LABELS" | tr ',' '\n' | grep -E '^(agent:|status:)'); do
      gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" --remove-label "$LABEL" 2>/dev/null || true
    done
    gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" --add-label "status:done"
    echo "DONE: issue #${ISSUE_N} closed."
    ;;

  fe|be|ops|qa|design|debug|arch)
    # Remove all existing agent: labels
    for LABEL in $(echo "$LABELS" | tr ',' '\n' | grep '^agent:'); do
      gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" --remove-label "$LABEL" 2>/dev/null || true
    done
    # Remove in-progress if present, ensure ready
    gh issue edit "$ISSUE_N" --repo "$REPO_SLUG" \
      --remove-label "status:in-progress" \
      --add-label "agent:${TARGET}" --add-label "status:ready" 2>/dev/null
    echo "ROUTED: #${ISSUE_N} → agent:${TARGET}"
    ;;

  *)
    echo "ERROR: Unknown target '${TARGET}'. Use: fe/be/ops/qa/design/debug/arch/merge/done"
    exit 1
    ;;
esac

# ── Post-routing verification ──
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
bash "${SCRIPT_DIR}/verify-labels.sh" "$REPO_SLUG" "$ISSUE_N" || {
  echo "LABEL VERIFICATION FAILED after routing #${ISSUE_N} → ${TARGET}"
  exit 1
}
