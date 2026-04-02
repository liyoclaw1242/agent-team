#!/bin/bash
# DEBUG validation pipeline — investigation quality gate
# Checks the investigation report posted on the issue
# Exit code: 0 = all pass, non-zero = failures found
set -e

FAILURES=0

echo "═══ DEBUG Investigation Quality Gate ═══"

# 1. Root Cause clarity
echo "── Root Cause ──"
# Check for hedging language in recent commit messages or staged changes
HEDGING=$(git diff --cached 2>/dev/null | grep "^+" | grep -iE "might be|probably|could be|possibly|not sure|maybe" || true)
if [ -n "$HEDGING" ]; then
  echo "FAIL: Hedging language detected — root cause must be certain:"
  echo "$HEDGING" | head -5
  FAILURES=$((FAILURES+1))
else
  echo "PASS: No hedging language"
fi

# 2. Evidence completeness
echo "── Evidence ──"
DIFF=$(git diff --cached 2>/dev/null || git diff origin/main 2>/dev/null || echo "")

# Check for trace ID reference
TRACE_REF=$(echo "$DIFF" | grep -iE "trace.id|traceId|trace_id" || true)
if [ -z "$TRACE_REF" ]; then
  echo "WARN: No trace ID referenced in report — include observability evidence"
fi

# Check for file:line reference
FILE_REF=$(echo "$DIFF" | grep -E "[a-zA-Z0-9_/]+\.(ts|tsx|js|jsx|py|go|rs):[0-9]+" || true)
if [ -z "$FILE_REF" ]; then
  echo "WARN: No file:line references found — include specific code locations"
fi

# 3. No code fixes (Iron Law)
echo "── Iron Law ──"
# DEBUG agents diagnose, they don't fix. Check for source code changes.
SRC_CHANGES=$(git diff --cached --name-only 2>/dev/null | grep -E "\.(ts|tsx|js|jsx|py|go|rs)$" | grep -v "test\|spec\|__test__" || true)
if [ -n "$SRC_CHANGES" ]; then
  echo "FAIL: Source code changes detected — DEBUG agents diagnose, others fix:"
  echo "$SRC_CHANGES"
  FAILURES=$((FAILURES+1))
else
  echo "PASS: No source code changes (diagnosis only)"
fi

# 4. Git hygiene
echo "── Git ──"
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
echo "Branch: $BRANCH"

BAD_COMMITS=$(git log origin/main..HEAD --format="%s" 2>/dev/null | grep -cvE "^(diag|debug|investigate|chore):" || true)
if [ "$BAD_COMMITS" -gt 0 ] 2>/dev/null; then
  echo "FAIL: $BAD_COMMITS commit(s) with bad message format (use diag:/debug:/investigate: prefix):"
  git log origin/main..HEAD --format="%s" 2>/dev/null | grep -vE "^(diag|debug|investigate|chore):"
  FAILURES=$((FAILURES+1))
fi

# 5. Secrets check
echo "── Security ──"
SECRETS=$(git diff --cached 2>/dev/null | grep "^+" | grep -E "sk-|ghp_|AKIA|password\s*=\s*['\"]" || true)
if [ -n "$SECRETS" ]; then
  echo "FAIL: Potential secrets in diff:"
  echo "$SECRETS" | head -3
  FAILURES=$((FAILURES+1))
else
  echo "PASS: No secrets detected"
fi

echo "═══ Results: $FAILURES failure(s) ═══"
exit $FAILURES
