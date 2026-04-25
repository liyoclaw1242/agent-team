#!/usr/bin/env bash
# verdict-format.sh — verify a verdict file matches the format contract.
#
# This is the same validation logic that post-verdict.sh applies, exposed
# as a standalone validator so agents can sanity-check before posting and
# tests can reference it without invoking the full action.
#
# Usage:
#   bash validate/verdict-format.sh /path/to/verdict.md
#
# Exit codes:
#   0 verdict format OK
#   1 argument error
#   2 format invalid (specific reason on stderr)

set -euo pipefail

[[ $# -eq 1 ]] || { echo "usage: $0 <verdict-file>" >&2; exit 1; }
VERDICT_FILE="$1"
[[ -f "$VERDICT_FILE" ]] || { echo "file not found: $VERDICT_FILE" >&2; exit 1; }

# Check 1: first non-blank line
first_line=$(grep -v '^$' "$VERDICT_FILE" | head -n1)
if [[ ! "$first_line" =~ ^##\ QA\ Verdict:\ (PASS|FAIL)$ ]]; then
  echo "✗ first line must be exactly '## QA Verdict: PASS' or '## QA Verdict: FAIL'" >&2
  echo "  found: $first_line" >&2
  exit 2
fi
verdict_outcome=$(echo "$first_line" | grep -oE 'PASS|FAIL')

# Check 2: triage line
triage_line=$(grep -E '^triage:\s+' "$VERDICT_FILE" | head -n1 || true)
if [[ -z "$triage_line" ]]; then
  echo "✗ missing 'triage:' line" >&2
  exit 2
fi
triage_value=$(echo "$triage_line" | sed -E 's/^triage:\s+//; s/[[:space:]]*$//')
case "$triage_value" in
  none|fe|be|ops|design) ;;
  *) echo "✗ triage: must be one of {none, fe, be, ops, design}; found '$triage_value'" >&2; exit 2 ;;
esac

# Check 3: triage / outcome consistency
if [[ "$verdict_outcome" == "PASS" && "$triage_value" != "none" ]]; then
  echo "✗ PASS verdict requires 'triage: none'; found '$triage_value'" >&2
  exit 2
fi
if [[ "$verdict_outcome" == "FAIL" && "$triage_value" == "none" ]]; then
  echo "✗ FAIL verdict requires a triage role (fe/be/ops/design), not 'none'" >&2
  exit 2
fi

# Check 4: Verified-on SHA
if ! grep -qE '^Verified-on:\s+[a-f0-9]{7,}' "$VERDICT_FILE"; then
  echo "✗ missing 'Verified-on: <SHA>' line (SHA must be ≥7 hex chars)" >&2
  exit 2
fi

# Check 5: at least one AC line
ac_lines=$(grep -cE '^- AC' "$VERDICT_FILE" || echo 0)
if [[ "$ac_lines" -lt 1 ]]; then
  echo "✗ no AC lines found (expected '- AC #N: ...' format)" >&2
  exit 2
fi

echo "✓ verdict format OK ($verdict_outcome, triage: $triage_value, $ac_lines AC lines)"
