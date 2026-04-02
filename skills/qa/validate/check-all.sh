#!/bin/bash
# QA post-verdict validation — enforces routing rules after Phase 7
# Usage: check-all.sh <VERDICT> <REPO_SLUG> <ISSUE_N> <PR_NUMBER> [API_URL]
#
#   VERDICT:    pass-merge | pass-design | fail
#   REPO_SLUG:  e.g. liyoclaw1242/whitelabel-admin
#   ISSUE_N:    e.g. 74
#   PR_NUMBER:  e.g. 75
#   API_URL:    default http://localhost:8000
#
# Exit code: 0 = all checks pass, N = number of violations
set -e

VERDICT="${1:?Usage: check-all.sh <pass-merge|pass-design|fail> <REPO_SLUG> <ISSUE_N> <PR_NUMBER> [API_URL]}"
REPO_SLUG="${2:?Repo slug required}"
ISSUE_N="${3:?Issue number required}"
PR_NUMBER="${4:?PR number required}"
API_URL="${5:-http://localhost:8000}"
FAILURES=0

echo "═══ QA Routing Validation ═══"
echo "Verdict: $VERDICT | Repo: $REPO_SLUG | Issue: #$ISSUE_N | PR: #$PR_NUMBER"
echo ""

# ── 1. Classification audit ──
# Fetch PR title + body, check that verdict matches signals
echo "── Classification Audit ──"

PR_JSON=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json title,body,labels 2>/dev/null || echo "{}")
PR_TITLE=$(echo "$PR_JSON" | jq -r '.title // ""' | tr '[:upper:]' '[:lower:]')
PR_BODY=$(echo "$PR_JSON" | jq -r '.body // ""' | tr '[:upper:]' '[:lower:]')
PR_TEXT="$PR_TITLE $PR_BODY"

# Detect signals
HAS_FIX_SIGNAL=$(echo "$PR_TEXT" | grep -cE '(fix|bug|broken|missing|repair|restore|patch|hotfix|regression)' || true)
HAS_VISUAL_SIGNAL=$(echo "$PR_TEXT" | grep -cE '(add new|new page|new component|redesign|restyle|layout change|visual overhaul|ui redesign)' || true)

# Check agent_type from bounty to determine if it's a frontend PR
BOUNTY_JSON=$(curl -sf "$API_URL/bounties/$REPO_SLUG/issues/$ISSUE_N" 2>/dev/null || echo "{}")
ORIGINAL_AGENT_TYPE=$(echo "$BOUNTY_JSON" | jq -r '.agent_type // "unknown"')

case "$VERDICT" in
  pass-merge)
    # If merging a frontend PR, it should have fix signals (not visual signals only)
    if [ "$ORIGINAL_AGENT_TYPE" = "fe" ] && [ "$HAS_FIX_SIGNAL" -eq 0 ] && [ "$HAS_VISUAL_SIGNAL" -gt 0 ]; then
      echo "FAIL: Merged a frontend PR with visual signals but no fix signals."
      echo "      This should have been routed to Design."
      echo "      Signals found: visual=$HAS_VISUAL_SIGNAL, fix=$HAS_FIX_SIGNAL"
      FAILURES=$((FAILURES+1))
    else
      echo "OK: Classification matches merge action"
    fi
    ;;
  pass-design)
    # If routing to Design, it should NOT be a pure fix
    if [ "$HAS_FIX_SIGNAL" -gt 0 ] && [ "$HAS_VISUAL_SIGNAL" -eq 0 ]; then
      echo "FAIL: Routed a pure bug-fix to Design review unnecessarily."
      echo "      This should have been merged directly."
      echo "      Signals found: fix=$HAS_FIX_SIGNAL, visual=$HAS_VISUAL_SIGNAL"
      FAILURES=$((FAILURES+1))
    else
      echo "OK: Classification matches design-route action"
    fi
    # Non-frontend PRs should never route to Design
    if [ "$ORIGINAL_AGENT_TYPE" != "fe" ]; then
      echo "FAIL: Routed a non-frontend PR (agent_type=$ORIGINAL_AGENT_TYPE) to Design."
      FAILURES=$((FAILURES+1))
    fi
    ;;
esac

# ── 2. State transition audit ──
# Verify the bounty board API state matches the verdict
echo ""
echo "── State Transition Audit ──"

# Re-fetch current bounty state (post-action)
CURRENT_JSON=$(curl -sf "$API_URL/bounties/$REPO_SLUG/issues/$ISSUE_N" 2>/dev/null || echo "{}")
CURRENT_TYPE=$(echo "$CURRENT_JSON" | jq -r '.agent_type // "unknown"')
CURRENT_STATUS=$(echo "$CURRENT_JSON" | jq -r '.status // "unknown"')

case "$VERDICT" in
  pass-merge)
    # After merge: PR should be merged
    PR_STATE=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
    if [ "$PR_STATE" != "MERGED" ]; then
      echo "FAIL: Verdict is pass-merge but PR state is $PR_STATE (expected MERGED)"
      FAILURES=$((FAILURES+1))
    else
      echo "OK: PR is merged"
    fi
    ;;
  pass-design)
    # After design route: agent_type must be 'design', PR must still be open
    if [ "$CURRENT_TYPE" != "design" ]; then
      echo "FAIL: Verdict is pass-design but agent_type=$CURRENT_TYPE (expected design)"
      echo "      The PATCH to change agent_type was likely skipped."
      FAILURES=$((FAILURES+1))
    else
      echo "OK: agent_type changed to design"
    fi

    PR_STATE=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json state --jq '.state' 2>/dev/null || echo "UNKNOWN")
    if [ "$PR_STATE" != "OPEN" ]; then
      echo "FAIL: Verdict is pass-design but PR state is $PR_STATE (expected OPEN)"
      FAILURES=$((FAILURES+1))
    else
      echo "OK: PR is still open for Design review"
    fi
    ;;
  fail)
    # After fail: status must be 'ready', agent_type must be fe/be/debug
    if [ "$CURRENT_STATUS" != "ready" ]; then
      echo "FAIL: Verdict is fail but status=$CURRENT_STATUS (expected ready)"
      FAILURES=$((FAILURES+1))
    else
      echo "OK: Status reset to ready"
    fi

    if ! echo "$CURRENT_TYPE" | grep -qE "^(fe|be|debug)$"; then
      echo "FAIL: Verdict is fail but agent_type=$CURRENT_TYPE (expected fe|be|debug)"
      FAILURES=$((FAILURES+1))
    else
      echo "OK: agent_type set to $CURRENT_TYPE for rework"
    fi
    ;;
  *)
    echo "FAIL: Unknown verdict '$VERDICT' (expected pass-merge|pass-design|fail)"
    FAILURES=$((FAILURES+1))
    ;;
esac

# ── 3. Comment audit ──
# Verify the QA comment was posted with correct verdict line
echo ""
echo "── Comment Audit ──"

LAST_COMMENT=$(gh pr view "$PR_NUMBER" --repo "$REPO_SLUG" --json comments --jq '.comments[-1].body' 2>/dev/null || echo "")

if [ -z "$LAST_COMMENT" ]; then
  echo "FAIL: No comments found on PR"
  FAILURES=$((FAILURES+1))
else
  case "$VERDICT" in
    pass-merge)
      if ! echo "$LAST_COMMENT" | grep -q "Visual: N/A"; then
        echo "FAIL: Merge verdict comment missing 'Visual: N/A' label"
        FAILURES=$((FAILURES+1))
      else
        echo "OK: Comment has correct verdict label"
      fi
      ;;
    pass-design)
      if ! echo "$LAST_COMMENT" | grep -q "Visual: PENDING"; then
        echo "FAIL: Design-route verdict comment missing 'Visual: PENDING' label"
        FAILURES=$((FAILURES+1))
      else
        echo "OK: Comment has correct verdict label"
      fi
      ;;
    fail)
      if ! echo "$LAST_COMMENT" | grep -q "Verdict: FAIL"; then
        echo "FAIL: Fail verdict comment missing 'Verdict: FAIL' label"
        FAILURES=$((FAILURES+1))
      else
        echo "OK: Comment has correct verdict label"
      fi
      ;;
  esac
fi

echo ""
echo "═══ Results: $FAILURES violation(s) ═══"
exit $FAILURES
