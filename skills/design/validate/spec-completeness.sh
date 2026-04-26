#!/usr/bin/env bash
# spec-completeness.sh — verify a design spec file has all three required
# sections with substantive content.
#
# Used by Mode A self-test and as the primary validator for spec authoring.
#
# Usage:
#   spec-completeness.sh <spec-file>
#
# Exit codes:
#   0 spec is complete
#   1 arg error
#   2 missing section(s) or insufficient content

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $(basename "$0") <spec-file>" >&2
  exit 1
fi

SPEC_FILE="$1"

if [[ ! -f "$SPEC_FILE" ]]; then
  echo "spec file not found: $SPEC_FILE" >&2
  exit 1
fi

errors=0

# 1. All three section headers present
for section in "Visual spec" "Interaction spec" "Accessibility spec"; do
  if ! grep -qE "^## $section\b" "$SPEC_FILE"; then
    echo "missing section: '## $section'" >&2
    errors=$((errors + 1))
  fi
done

if [[ $errors -gt 0 ]]; then
  echo "result: FAIL ($errors missing sections)" >&2
  exit 2
fi

# 2. Each section has substantive content (≥3 non-empty lines after header)
for section in "Visual spec" "Interaction spec" "Accessibility spec"; do
  content_lines=$(awk -v s="^## $section" '
    $0 ~ s {flag=1; next}
    /^## / {flag=0}
    flag {print}
  ' "$SPEC_FILE" | grep -cE '\S' || true)
  
  if [[ "$content_lines" -lt 3 ]]; then
    echo "section '$section' has only $content_lines non-empty lines (need ≥3)" >&2
    errors=$((errors + 1))
  fi
done

if [[ $errors -gt 0 ]]; then
  echo "result: FAIL ($errors sections insufficiently populated)" >&2
  exit 2
fi

echo "result: PASS"
exit 0
