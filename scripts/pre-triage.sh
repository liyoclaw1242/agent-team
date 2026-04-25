#!/usr/bin/env bash
# pre-triage.sh — deterministic handlers for post-implementation state.
#
# The dispatcher handles intake-side routing (issues with no PR yet).
# This script handles the "Mode D" deterministic decisions that happen after
# implementation: read PR verdict comments, decide merge / route-to-fix /
# escalate-to-judgment.
#
# Should be run on cron alongside dispatcher.sh.
#
# Usage:
#   pre-triage.sh
#       [--repo OWNER/REPO]
#       [--dry-run]
#
# Exit codes:
#   0 success
#   1 arg error
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

# ─── Find issues with open PRs awaiting decision ────────────────────────────
#
# Candidates: agent:arch + status:ready issues where we can find an open PR
# linked to them and a verdict comment present.

candidates=$(gh issue list --repo "$REPO" \
  --label "agent:arch" \
  --label "status:ready" \
  --state open \
  --limit 100 \
  --json number) || { echo "gh issue list failed" >&2; exit 2; }

count_processed=0
count_skipped=0
count_failed=0

for n in $(echo "$candidates" | jq -r '.[].number'); do
  # Find PRs that mention this issue. We use the closing keyword convention:
  # PRs that say "Refs: #N" or "Closes #N" in the body.
  pr_data=$(gh pr list --repo "$REPO" --state open --search "in:body #$n" --json number,body,statusCheckRollup --limit 5 \
    || echo "[]")

  pr_count=$(echo "$pr_data" | jq 'length')
  if [[ "$pr_count" -eq 0 ]]; then
    count_skipped=$((count_skipped + 1))
    continue
  fi

  # Take the first matching PR
  pr_n=$(echo "$pr_data" | jq -r '.[0].number')

  # Read PR comments for verdict from QA / Design.
  pr_comments=$(gh pr view "$pr_n" --repo "$REPO" --json comments \
    --jq '.comments | map(.body) | join("\n---\n")' 2>/dev/null || echo "")

  qa_pass=false
  qa_fail=false
  qa_triage=""
  design_approved=false
  design_changes=false

  if echo "$pr_comments" | grep -qE '^## QA Verdict.*PASS' ; then qa_pass=true; fi
  if echo "$pr_comments" | grep -qE '^## QA Verdict.*FAIL' ; then qa_fail=true; fi
  if echo "$pr_comments" | grep -qE '^## Design Verdict.*APPROVED' ; then design_approved=true; fi
  if echo "$pr_comments" | grep -qE '^## Design Verdict.*NEEDS_CHANGES' ; then design_changes=true; fi

  # Extract triage suggestion from QA: "triage: fe" / "triage: be" etc.
  qa_triage=$(echo "$pr_comments" | grep -oP 'triage:\s*\K[a-z-]+' | head -n1 || true)

  # ── Decision tree ─────────────────────────────────────────────────────────

  if $qa_pass && ! $design_changes; then
    # Either Design approved or design review not required for this issue.
    echo "  #$n / PR #$pr_n: QA PASS → merge"
    if [[ "$DRY_RUN" == "1" ]]; then
      count_processed=$((count_processed + 1))
      continue
    fi
    # Use squash merge with branch deletion.
    if gh pr merge "$pr_n" --repo "$REPO" --squash --delete-branch >/dev/null; then
      "$ROUTE_SH" "$n" "arch" --repo "$REPO" --agent-id "pre-triage" \
        --status done --reason "PR merged" >/dev/null \
        || true
      gh issue close "$n" --repo "$REPO" >/dev/null || true
      count_processed=$((count_processed + 1))
    else
      count_failed=$((count_failed + 1))
    fi
    continue
  fi

  if $qa_fail && [[ -n "$qa_triage" ]]; then
    echo "  #$n: QA FAIL → route to $qa_triage"
    if [[ "$DRY_RUN" == "1" ]]; then
      count_processed=$((count_processed + 1))
      continue
    fi
    if "$ROUTE_SH" "$n" "$qa_triage" --repo "$REPO" --agent-id "pre-triage" \
        --reason "QA FAIL routed to $qa_triage"; then
      count_processed=$((count_processed + 1))
    else
      count_failed=$((count_failed + 1))
    fi
    continue
  fi

  if $design_changes && ! $qa_fail; then
    echo "  #$n: Design NEEDS_CHANGES → route to fe"
    # Default implementer is fe for design changes; could be made smarter.
    if [[ "$DRY_RUN" == "1" ]]; then
      count_processed=$((count_processed + 1))
      continue
    fi
    if "$ROUTE_SH" "$n" "fe" --repo "$REPO" --agent-id "pre-triage" \
        --reason "Design NEEDS_CHANGES"; then
      count_processed=$((count_processed + 1))
    else
      count_failed=$((count_failed + 1))
    fi
    continue
  fi

  if $qa_fail && $design_changes; then
    echo "  #$n: QA FAIL + Design NEEDS_CHANGES → escalate to arch-judgment"
    if [[ "$DRY_RUN" == "1" ]]; then
      count_processed=$((count_processed + 1))
      continue
    fi
    if "$ROUTE_SH" "$n" "arch-judgment" --repo "$REPO" --agent-id "pre-triage" \
        --reason "conflicting QA and Design verdicts"; then
      count_processed=$((count_processed + 1))
    else
      count_failed=$((count_failed + 1))
    fi
    continue
  fi

  # Fall through: PR open, no decisive verdict yet.
  count_skipped=$((count_skipped + 1))
done

echo "done: $count_processed processed, $count_skipped skipped, $count_failed failed"
[[ $count_failed -eq 0 ]] && exit 0 || exit 2
