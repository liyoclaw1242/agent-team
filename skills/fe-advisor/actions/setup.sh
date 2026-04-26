#!/usr/bin/env bash
# setup.sh — claim the consultation issue and start journal.
#
# fe-advisor doesn't need a code branch (no code changes). Just claim
# and journal-start.
#
# Usage:
#   setup.sh --issue N [--repo OWNER/REPO]
#
# Exit codes:
#   0 success
#   1 arg/setup error
#   2 claim conflict

set -euo pipefail

REPO="${REPO:-}"
ISSUE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE="$2"; shift 2 ;;
    --repo)  REPO="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE" ]] && { echo "missing --issue" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "missing --repo (and \$REPO not set)" >&2; exit 1; }

CLAIMS_SH="${CLAIMS_SH:-$(dirname "$0")/../../scripts/claims.sh}"
[[ -x "$CLAIMS_SH" ]] || { echo "claims.sh not executable at $CLAIMS_SH" >&2; exit 1; }

# 1. Claim the issue
if ! "$CLAIMS_SH" claim "$ISSUE" --repo "$REPO" --agent-id "fe-advisor-$$"; then
  echo "claim failed for #$ISSUE" >&2
  exit 2
fi

# 2. Verify this is actually a consultation issue (sanity)
body=$(gh issue view "$ISSUE" --repo "$REPO" --json body --jq '.body' 2>/dev/null || echo "")
if ! echo "$body" | grep -q '<!-- consultation-of: '; then
  echo "warning: issue #$ISSUE doesn't have consultation-of marker; proceeding anyway" >&2
fi

# 3. Journal-start
SHARED_ACTIONS="${SHARED_ACTIONS:-$(dirname "$0")/../../_shared/actions}"
if [[ -x "$SHARED_ACTIONS/write-journal.sh" ]]; then
  bash "$SHARED_ACTIONS/write-journal.sh" \
    --issue "$ISSUE" \
    --role "fe-advisor" \
    --event "consultation-start" \
    --note "claimed consultation" || true
fi

echo "setup complete: consultation #$ISSUE claimed"
exit 0
