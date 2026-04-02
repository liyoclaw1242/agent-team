#!/bin/bash
# ARCH pre-flight check — run before any mode
# Exit codes:
#   0 = arch.md exists, proceed normally
#   1 = arch.md missing, must bootstrap first
#   2 = arch.md exists but stale/incomplete
set -e

REPO_DIR="${1:-.}"
cd "$REPO_DIR"

echo "═══ ARCH Pre-flight Check ═══"

# 1. Does arch.md exist?
if [ ! -f "arch.md" ]; then
  echo "STATUS: BOOTSTRAP_REQUIRED"
  echo "arch.md does not exist. Run Mode 0 (Bootstrap) first."
  exit 1
fi

echo "OK: arch.md exists ($(wc -l < arch.md) lines)"

# 2. Required sections
MISSING=0
for section in "Domain Model" "System Architecture" "Tech Stack" "API Contracts" "User Journey"; do
  if grep -qi "$section" arch.md; then
    echo "OK: [$section]"
  else
    echo "MISSING: [$section]"
    MISSING=$((MISSING+1))
  fi
done

# 3. Staleness check — compare arch.md mtime vs latest code change
ARCH_MTIME=$(stat -f "%m" arch.md 2>/dev/null || stat -c "%Y" arch.md 2>/dev/null)
LATEST_CODE=$(find . -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" 2>/dev/null | \
  grep -v node_modules | \
  xargs stat -f "%m" 2>/dev/null | sort -rn | head -1 || \
  xargs stat -c "%Y" 2>/dev/null | sort -rn | head -1 || echo "0")

if [ -n "$LATEST_CODE" ] && [ "$LATEST_CODE" -gt "$ARCH_MTIME" ] 2>/dev/null; then
  DAYS_STALE=$(( (LATEST_CODE - ARCH_MTIME) / 86400 ))
  if [ "$DAYS_STALE" -gt 7 ]; then
    echo "WARN: arch.md is ${DAYS_STALE} days behind latest code change"
  fi
fi

# 4. TODO markers (unverified sections)
TODOS=$(grep -c "<!-- TODO" arch.md 2>/dev/null || echo "0")
if [ "$TODOS" -gt 0 ]; then
  echo "WARN: $TODOS unverified sections (<!-- TODO --> markers)"
fi

# 5. Result
if [ "$MISSING" -gt 2 ]; then
  echo ""
  echo "STATUS: INCOMPLETE"
  echo "arch.md is missing $MISSING required sections. Consider re-bootstrapping."
  exit 2
fi

echo ""
echo "STATUS: READY"
exit 0
