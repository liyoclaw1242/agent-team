#!/usr/bin/env bash
# advice-format.sh — validate the structured-advice schema.
#
# Used by both fe-advisor and be-advisor (schema is shared); pass --role
# to validate the header line.
#
# Usage:
#   advice-format.sh [--role fe-advisor|be-advisor|ops-advisor|design-advisor] <advice-file>
#
# Exit codes:
#   0 valid
#   1 arg error
#   2 format invalid

set -euo pipefail

ROLE="fe-advisor"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --role) ROLE="$2"; shift 2 ;;
    --*) echo "unknown flag: $1" >&2; exit 1 ;;
    *) ADVICE_FILE="$1"; shift ;;
  esac
done

if [[ -z "${ADVICE_FILE:-}" ]]; then
  echo "usage: $(basename "$0") [--role ROLE] <advice-file>" >&2
  exit 1
fi

if [[ ! -f "$ADVICE_FILE" ]]; then
  echo "advice file not found: $ADVICE_FILE" >&2
  exit 1
fi

case "$ROLE" in
  fe-advisor|be-advisor|ops-advisor|design-advisor) ;;
  *) echo "invalid role: $ROLE" >&2; exit 1 ;;
esac

errors=0

# 1. First non-empty line is exactly the role header
first_line=$(grep -m1 -E '\S' "$ADVICE_FILE" | head -n1)
expected="## Advice from $ROLE"

if [[ "$first_line" != "$expected" ]]; then
  echo "header invalid: first non-empty line must be '$expected'" >&2
  echo "got: $first_line" >&2
  errors=$((errors + 1))
fi

# 2. All six required sections present
required=(
  "### Existing constraints"
  "### Suggested approach"
  "### Conflicts with request"
  "### Estimated scope"
  "### Risks"
  "### Drift noticed"
)

for section in "${required[@]}"; do
  if ! grep -qF "$section" "$ADVICE_FILE"; then
    echo "missing section: '$section'" >&2
    errors=$((errors + 1))
  fi
done

if [[ $errors -gt 0 ]]; then
  echo "result: FAIL ($errors error(s))" >&2
  exit 2
fi

# 3. Each section has at least one non-empty content line
for section in "${required[@]}"; do
  content=$(awk -v s="$section" '
    $0 == s {flag=1; next}
    /^### / {flag=0}
    /^## / {flag=0}
    flag {print}
  ' "$ADVICE_FILE" | grep -cE '\S' || true)
  
  if [[ "$content" -lt 1 ]]; then
    echo "section '$section' has no content" >&2
    errors=$((errors + 1))
  fi
done

if [[ $errors -gt 0 ]]; then
  echo "result: FAIL ($errors empty section(s))" >&2
  exit 2
fi

# 4. Estimated scope contains S, M, or L
scope_section=$(awk '
  $0 == "### Estimated scope" {flag=1; next}
  /^### / {flag=0}
  /^## / {flag=0}
  flag {print}
' "$ADVICE_FILE")

if ! echo "$scope_section" | grep -qE '\b(S|M|L|L\+)\b'; then
  echo "Estimated scope section must contain S, M, L, or L+" >&2
  echo "got:" >&2
  echo "$scope_section" >&2
  exit 2
fi

echo "result: PASS"
exit 0
