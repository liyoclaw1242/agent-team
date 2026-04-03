#!/bin/bash
# ARCH validation pipeline — verify architecture artifacts are maintained
# Exit code: 0 = all pass, non-zero = failures found
set -e

FAILURES=0

echo "═══ ARCH Validation Pipeline ═══"

# 1. arch.md exists and was updated
echo "── arch.md ──"
if [ ! -f "arch.md" ]; then
  echo "FAIL: arch.md does not exist at repo root"
  FAILURES=$((FAILURES+1))
else
  echo "OK: arch.md exists ($(wc -l < arch.md) lines)"

  # Check arch.md was modified in this branch's commits
  ARCH_CHANGED=$(git diff --name-only origin/main 2>/dev/null | grep "^arch.md$" || true)
  if [ -z "$ARCH_CHANGED" ]; then
    echo "WARN: arch.md was NOT modified — did you forget to update it?"
  else
    echo "OK: arch.md was updated in this branch"
  fi

  # Check required sections exist
  for section in "Domain Model" "System Architecture" "Tech Stack" "API Contracts"; do
    if grep -qi "$section" arch.md; then
      echo "OK: Section '$section' found"
    else
      echo "FAIL: Missing section '$section' in arch.md"
      FAILURES=$((FAILURES+1))
    fi
  done
fi

# 2. ADR format check (if any ADRs were created/modified)
echo "── ADRs ──"
ADRS=$(git diff --name-only origin/main 2>/dev/null | grep "docs/adr/" || true)
if [ -n "$ADRS" ]; then
  echo "$ADRS" | while read adr; do
    if [ -f "$adr" ]; then
      for field in "Status" "Context" "Decision" "Consequences"; do
        if grep -qi "## $field" "$adr"; then
          echo "OK: $adr has '$field'"
        else
          echo "FAIL: $adr missing '## $field' section"
          FAILURES=$((FAILURES+1))
        fi
      done
    fi
  done
else
  echo "SKIP: No ADRs modified"
fi

# 3. Issue state consistency — done bounties must have closed GitHub issues
echo "── Issue State ──"
API_URL="${API_URL:-http://localhost:8000}"
REPO_SLUG="${REPO_SLUG:-}"
if [ -n "$REPO_SLUG" ]; then
  DONE_ISSUES=$(curl -sf "${API_URL}/bounties?status=done&repo_slug=${REPO_SLUG}" 2>/dev/null | jq -r '.[].number // empty' 2>/dev/null || true)
  if [ -n "$DONE_ISSUES" ]; then
    for ISSUE_N in $DONE_ISSUES; do
      GH_STATE=$(gh issue view "$ISSUE_N" --repo "$REPO_SLUG" --json state -q '.state' 2>/dev/null || echo "unknown")
      if [ "$GH_STATE" = "CLOSED" ]; then
        echo "OK: #${ISSUE_N} done + closed"
      else
        echo "FAIL: #${ISSUE_N} is status:done but GitHub state is '${GH_STATE}' — run: gh issue close ${ISSUE_N} --repo ${REPO_SLUG}"
        FAILURES=$((FAILURES+1))
      fi
    done
  else
    echo "SKIP: No done issues found"
  fi
else
  echo "SKIP: REPO_SLUG not set"
fi

# 4. Git hygiene
echo "── Git ──"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "Branch: $BRANCH"

git log origin/main..HEAD --format="%s" 2>/dev/null | while read msg; do
  echo "$msg" | grep -qE "^(feat|fix|docs|design|test|chore):" || echo "FAIL: Bad commit message: $msg"
done

echo "═══ Results: $FAILURES failure(s) ═══"
exit $FAILURES
