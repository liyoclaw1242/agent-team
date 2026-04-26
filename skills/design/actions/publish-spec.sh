#!/usr/bin/env bash
# publish-spec.sh — atomically embed a design spec between markers in
# the issue body. Idempotent: running with a new spec replaces the old.
#
# Validates the spec has all three required sections before publishing.
#
# Usage:
#   publish-spec.sh --issue N --spec-file PATH [--repo OWNER/REPO]
#
# Exit codes:
#   0 success
#   1 arg/setup error
#   2 spec validation failed (missing sections)
#   3 update failed

set -euo pipefail

REPO="${REPO:-}"
ISSUE=""
SPEC_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)     ISSUE="$2"; shift 2 ;;
    --repo)      REPO="$2"; shift 2 ;;
    --spec-file) SPEC_FILE="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE" ]] && { echo "missing --issue" >&2; exit 1; }
[[ -z "$SPEC_FILE" ]] && { echo "missing --spec-file" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "missing --repo (and \$REPO not set)" >&2; exit 1; }
[[ -f "$SPEC_FILE" ]] || { echo "spec file not found: $SPEC_FILE" >&2; exit 1; }

# 1. Validate spec has all three required sections
missing=()
grep -qE '^## Visual spec\b' "$SPEC_FILE" || missing+=("Visual spec")
grep -qE '^## Interaction spec\b' "$SPEC_FILE" || missing+=("Interaction spec")
grep -qE '^## Accessibility spec\b' "$SPEC_FILE" || missing+=("Accessibility spec")

if [[ ${#missing[@]} -gt 0 ]]; then
  echo "spec is missing required sections: ${missing[*]}" >&2
  echo "spec must contain '## Visual spec', '## Interaction spec', '## Accessibility spec' headers" >&2
  exit 2
fi

# 2. Each section must have substantive content (3+ non-empty lines after header)
for section in "Visual spec" "Interaction spec" "Accessibility spec"; do
  # Extract lines from this header to next ## or EOF
  content=$(awk -v s="## $section" '
    $0 ~ "^"s {flag=1; next}
    /^## / {flag=0}
    flag {print}
  ' "$SPEC_FILE" | grep -cE '\S' || true)
  
  if [[ "$content" -lt 3 ]]; then
    echo "section '$section' has too little content ($content non-empty lines; need ≥3)" >&2
    exit 2
  fi
done

# 3. Read current issue body
current_body=$(gh issue view "$ISSUE" --repo "$REPO" --json body --jq '.body' 2>/dev/null) || {
  echo "failed to read issue body" >&2; exit 3;
}

# 4. Read spec content
spec_content=$(cat "$SPEC_FILE")

# 5. Build new body — strip any existing design-spec block, then append fresh
new_body=$(echo "$current_body" | awk '
  /<!-- design-spec-begin -->/ {skip=1; next}
  /<!-- design-spec-end -->/ {skip=0; next}
  !skip
')

# Trim trailing whitespace
new_body=$(echo "$new_body" | sed -e 's/[[:space:]]*$//')

# Append new spec block
new_body="$new_body

<!-- design-spec-begin -->

$spec_content

<!-- design-spec-end -->"

# 6. Update the issue
tmp=$(mktemp)
printf '%s' "$new_body" > "$tmp"

if ! gh issue edit "$ISSUE" --repo "$REPO" --body-file "$tmp" >/dev/null; then
  echo "failed to update issue body" >&2
  rm -f "$tmp"
  exit 3
fi

rm -f "$tmp"
echo "spec published to #$ISSUE"
exit 0
