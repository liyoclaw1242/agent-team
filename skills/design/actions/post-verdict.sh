#!/usr/bin/env bash
# post-verdict.sh — post a strictly-formatted Design Verdict to a PR.
# Validates the verdict format mechanically; rejects malformed.
#
# Format requirements (enforced):
#   - First non-empty line: '## Design Verdict: APPROVED' or
#     '## Design Verdict: NEEDS_CHANGES' (exactly)
#   - Contains a 'triage:' line with value in {fe, be, design, ops, none}
#   - Contains a 'Reviewed-on:' line with a SHA-like value
#   - APPROVED requires triage: none
#   - NEEDS_CHANGES requires triage: a role (not none)
#
# Usage:
#   post-verdict.sh --issue N --pr M --verdict-file PATH [--repo OWNER/REPO]
#
# Exit codes:
#   0 success
#   1 arg/setup error
#   2 verdict format invalid
#   3 post failed
#   4 routing failed

set -euo pipefail

REPO="${REPO:-}"
ISSUE=""
PR=""
VERDICT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)        ISSUE="$2"; shift 2 ;;
    --pr)           PR="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --verdict-file) VERDICT_FILE="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE" ]] && { echo "missing --issue" >&2; exit 1; }
[[ -z "$PR" ]] && { echo "missing --pr" >&2; exit 1; }
[[ -z "$VERDICT_FILE" ]] && { echo "missing --verdict-file" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "missing --repo (and \$REPO not set)" >&2; exit 1; }
[[ -f "$VERDICT_FILE" ]] || { echo "verdict file not found: $VERDICT_FILE" >&2; exit 1; }

# 1. Validate format
# 1a. First non-empty line must match exact verdict line
first_line=$(grep -m1 -E '\S' "$VERDICT_FILE" | head -n1)

verdict=""
if [[ "$first_line" == "## Design Verdict: APPROVED" ]]; then
  verdict="APPROVED"
elif [[ "$first_line" == "## Design Verdict: NEEDS_CHANGES" ]]; then
  verdict="NEEDS_CHANGES"
else
  echo "verdict format invalid: first non-empty line must be exactly:" >&2
  echo "  '## Design Verdict: APPROVED' or '## Design Verdict: NEEDS_CHANGES'" >&2
  echo "got: $first_line" >&2
  exit 2
fi

# 1b. Must have triage: line
triage=$(grep -oE '^triage:\s*[a-z-]+' "$VERDICT_FILE" | head -n1 | sed -E 's/^triage:\s*//')
if [[ -z "$triage" ]]; then
  echo "verdict format invalid: missing 'triage:' line" >&2
  exit 2
fi

# 1c. Triage must be a valid role
case "$triage" in
  fe|be|design|ops|none) ;;
  *) echo "verdict format invalid: triage '$triage' not in {fe,be,design,ops,none}" >&2; exit 2 ;;
esac

# 1d. Must have Reviewed-on: SHA
reviewed_on=$(grep -oE '^Reviewed-on:\s*[a-f0-9]+' "$VERDICT_FILE" | head -n1 | sed -E 's/^Reviewed-on:\s*//')
if [[ -z "$reviewed_on" ]]; then
  echo "verdict format invalid: missing 'Reviewed-on: <SHA>' line" >&2
  exit 2
fi

if [[ ! "$reviewed_on" =~ ^[a-f0-9]{7,40}$ ]]; then
  echo "verdict format invalid: Reviewed-on SHA '$reviewed_on' not in expected format (7-40 hex chars)" >&2
  exit 2
fi

# 1e. Internal consistency: APPROVED requires triage: none
if [[ "$verdict" == "APPROVED" && "$triage" != "none" ]]; then
  echo "verdict format invalid: APPROVED requires 'triage: none' (got '$triage')" >&2
  exit 2
fi

# 1f. NEEDS_CHANGES requires triage that's not 'none'
if [[ "$verdict" == "NEEDS_CHANGES" && "$triage" == "none" ]]; then
  echo "verdict format invalid: NEEDS_CHANGES requires triage to be a role (got 'none')" >&2
  exit 2
fi

echo "verdict format valid: $verdict, triage: $triage, Reviewed-on: $reviewed_on"

# 2. Post the verdict as PR comment
if ! gh pr comment "$PR" --repo "$REPO" --body-file "$VERDICT_FILE" >/dev/null; then
  echo "failed to post verdict comment to PR #$PR" >&2
  exit 3
fi

echo "verdict posted to PR #$PR"

# 3. Route the issue to arch (pre-triage will handle further routing)
ROUTE_SH="${ROUTE_SH:-$(dirname "$0")/../../scripts/route.sh}"
if [[ -x "$ROUTE_SH" ]]; then
  if ! "$ROUTE_SH" "$ISSUE" "arch" --repo "$REPO" --agent-id "design-$$" \
      --reason "design verdict posted: $verdict (triage: $triage)" >/dev/null; then
    echo "warning: failed to route issue to arch (verdict still posted)" >&2
    exit 4
  fi
  echo "issue #$ISSUE routed to agent:arch"
fi

exit 0
