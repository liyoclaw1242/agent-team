#!/bin/bash
# Pre-triage: handle deterministic cases before ARCH Mode D judgment.
# Run at the start of every ARCH triage cycle. Processes all agent:arch issues
# and auto-resolves cases that don't need LLM judgment.
#
# Usage: pre-triage.sh <REPO_SLUG>
# Exit 0 = success. Prints remaining issues that need ARCH judgment.
set -euo pipefail

REPO_SLUG="${1:?REPO_SLUG required (e.g. owner/repo)}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "=== Pre-triage: ${REPO_SLUG} ==="

# Fetch all issues routed to ARCH
# ARCH issues come from two sources:
#   1. New tasks (created by users/ARCH) → status:ready
#   2. Routed back from other agents → status:review
READY_ISSUES=$(gh issue list --repo "$REPO_SLUG" --label "agent:arch" --label "status:ready" --json number --jq '.[].number' 2>/dev/null || true)
REVIEW_ISSUES=$(gh issue list --repo "$REPO_SLUG" --label "agent:arch" --label "status:review" --json number --jq '.[].number' 2>/dev/null || true)
ISSUES=$(echo "$READY_ISSUES $REVIEW_ISSUES" | tr ' ' '\n' | sort -u | tr '\n' ' ')

if [ -z "$ISSUES" ]; then
  echo "No issues for ARCH. Nothing to triage."
  exit 0
fi

HANDLED=0
REMAINING=""

for N in $ISSUES; do
  TITLE=$(gh issue view "$N" --repo "$REPO_SLUG" --json title --jq '.title' 2>/dev/null)

  # Find associated PR
  PR_NUMBER=$(gh pr list --repo "$REPO_SLUG" --search "closes #${N}" --json number,state --jq '.[0].number // empty' 2>/dev/null || true)
  PR_STATE=""

  # Collect comments from BOTH issue AND PR (QA often posts verdict on PR, not issue)
  ISSUE_COMMENTS=$(gh issue view "$N" --repo "$REPO_SLUG" --json comments --jq '.comments' 2>/dev/null || echo "[]")
  PR_COMMENTS="[]"
  if [ -n "$PR_NUMBER" ]; then
    PR_COMMENTS=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json comments --jq '.comments' 2>/dev/null || echo "[]")
  fi
  ALL_COMMENTS=$(echo "$ISSUE_COMMENTS $PR_COMMENTS" | jq -s 'add')

  # Detect verdicts from combined issue + PR comments
  QA_PASS=$(echo "$ALL_COMMENTS" | jq -r '[.[].body | select(test("Verdict.*PASS|Code.*APPROVED|all.*pass|PASS.*verdict"; "i"))] | last // empty')
  QA_FAIL=$(echo "$ALL_COMMENTS" | jq -r '[.[].body | select(test("Verdict.*FAIL|Code.*REJECT"; "i"))] | last // empty')
  DESIGN_APPROVED=$(echo "$ALL_COMMENTS" | jq -r '[.[].body | select(test("Verdict.*APPROVED|Visual.*APPROVED"; "i"))] | last // empty')
  DESIGN_NEEDS_CHANGES=$(echo "$ALL_COMMENTS" | jq -r '[.[].body | select(test("Verdict.*NEEDS.CHANGES|Visual.*NEEDS.CHANGES"; "i"))] | last // empty')

  # PR state
  if [ -n "$PR_NUMBER" ]; then
    PR_STATE=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
  fi

  # ── Case 1: QA PASS + PR open → merge (if Design review not needed or done) ──
  if [ -n "$QA_PASS" ] && [ -n "$PR_NUMBER" ] && [ "$PR_STATE" = "OPEN" ]; then
    # Check if Design rejected
    if [ -n "$DESIGN_NEEDS_CHANGES" ]; then
      REMAINING="$REMAINING $N"
      continue
    fi

    # Check if this is a frontend PR that still needs Design review
    PR_BRANCH=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json headRefName --jq '.headRefName' 2>/dev/null || echo "")
    IS_FRONTEND=false
    echo "$PR_BRANCH" | grep -qiE "^agent/fe" && IS_FRONTEND=true
    echo "$TITLE" | grep -qiE "^(fe|frontend|design):" && IS_FRONTEND=true

    if [ "$IS_FRONTEND" = true ] && [ -z "$DESIGN_APPROVED" ]; then
      echo "#${N}: QA PASS but frontend PR #${PR_NUMBER} needs Design review → leaving for ARCH"
      REMAINING="$REMAINING $N"
      continue
    fi

    echo "#${N}: QA PASS + PR #${PR_NUMBER} open → MERGE"
    gh pr merge "$PR_NUMBER" --repo "$REPO_SLUG" --squash --delete-branch 2>/dev/null || {
      echo "  WARN: merge failed for PR #${PR_NUMBER}, leaving for ARCH"
      REMAINING="$REMAINING $N"
      continue
    }
    gh issue close "$N" --repo "$REPO_SLUG" 2>/dev/null
    for L in $(gh issue view "$N" --repo "$REPO_SLUG" --json labels --jq '[.labels[].name] | .[]' 2>/dev/null | grep -E '^(agent:|status:)'); do
      gh issue edit "$N" --repo "$REPO_SLUG" --remove-label "$L" 2>/dev/null || true
    done
    gh issue edit "$N" --repo "$REPO_SLUG" --add-label "status:done" 2>/dev/null
    gh issue comment "$N" --repo "$REPO_SLUG" \
      --body "Auto-merged by pre-triage — QA PASS, PR #${PR_NUMBER} squash-merged." 2>/dev/null
    HANDLED=$((HANDLED + 1))
    continue
  fi

  # ── Case 2: QA PASS + PR already merged → close ──
  if [ -n "$QA_PASS" ] && [ -n "$PR_NUMBER" ] && [ "$PR_STATE" = "MERGED" ]; then
    echo "#${N}: QA PASS + PR #${PR_NUMBER} already merged → CLOSE"
    gh issue close "$N" --repo "$REPO_SLUG" 2>/dev/null
    for L in $(gh issue view "$N" --repo "$REPO_SLUG" --json labels --jq '[.labels[].name] | .[]' 2>/dev/null | grep -E '^(agent:|status:)'); do
      gh issue edit "$N" --repo "$REPO_SLUG" --remove-label "$L" 2>/dev/null || true
    done
    gh issue edit "$N" --repo "$REPO_SLUG" --add-label "status:done" 2>/dev/null
    HANDLED=$((HANDLED + 1))
    continue
  fi

  # ── Case 3: Design APPROVED + QA PASS → merge ──
  if [ -n "$DESIGN_APPROVED" ] && [ -n "$QA_PASS" ] && [ -n "$PR_NUMBER" ] && [ "$PR_STATE" = "OPEN" ]; then
    echo "#${N}: Design APPROVED + QA PASS + PR #${PR_NUMBER} → MERGE"
    gh pr merge "$PR_NUMBER" --repo "$REPO_SLUG" --squash --delete-branch 2>/dev/null || {
      echo "  WARN: merge failed, leaving for ARCH"
      REMAINING="$REMAINING $N"
      continue
    }
    gh issue close "$N" --repo "$REPO_SLUG" 2>/dev/null
    for L in $(gh issue view "$N" --repo "$REPO_SLUG" --json labels --jq '[.labels[].name] | .[]' 2>/dev/null | grep -E '^(agent:|status:)'); do
      gh issue edit "$N" --repo "$REPO_SLUG" --remove-label "$L" 2>/dev/null || true
    done
    gh issue edit "$N" --repo "$REPO_SLUG" --add-label "status:done" 2>/dev/null
    gh issue comment "$N" --repo "$REPO_SLUG" \
      --body "Auto-merged by pre-triage — QA PASS + Design APPROVED, PR #${PR_NUMBER} squash-merged." 2>/dev/null
    HANDLED=$((HANDLED + 1))
    continue
  fi

  # ── Case 4: PR exists + no verdict → route to QA ──
  if [ -n "$PR_NUMBER" ] && [ "$PR_STATE" = "OPEN" ] && [ -z "$QA_PASS" ] && [ -z "$QA_FAIL" ] && [ -z "$DESIGN_APPROVED" ] && [ -z "$DESIGN_NEEDS_CHANGES" ]; then
    echo "#${N}: PR #${PR_NUMBER} delivered, no verdict → route to QA"
    bash "${SCRIPT_DIR}/route.sh" "$REPO_SLUG" "$N" qa "pre-triage" 2>/dev/null || {
      echo "  WARN: route.sh failed, leaving for ARCH"
      REMAINING="$REMAINING $N"
      continue
    }
    gh issue comment "$N" --repo "$REPO_SLUG" \
      --body "Routed to QA by pre-triage — PR #${PR_NUMBER} needs verification." 2>/dev/null || true
    HANDLED=$((HANDLED + 1))
    continue
  fi

  # ── Not deterministic → leave for ARCH ──
  REMAINING="$REMAINING $N"
done

echo ""
echo "=== Pre-triage done: ${HANDLED} auto-handled ==="
if [ -n "$REMAINING" ]; then
  echo "Remaining for ARCH judgment:${REMAINING}"
else
  echo "All issues handled. Nothing for ARCH to judge."
fi
