#!/usr/bin/env bash
# respond.sh — validate advice format, post comment, close consultation.
#
# This is design-advisor's "delivery". Validates the schema (via validate/
# advice-format.sh), posts to the issue, then closes.
#
# Usage:
#   respond.sh --issue N --advice-file PATH [--repo OWNER/REPO]
#
# Exit codes:
#   0 success
#   1 arg/setup error
#   2 advice format invalid
#   3 post failed
#   4 close failed

set -euo pipefail

REPO="${REPO:-}"
ISSUE=""
ADVICE_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)        ISSUE="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --advice-file)  ADVICE_FILE="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE" ]] && { echo "missing --issue" >&2; exit 1; }
[[ -z "$ADVICE_FILE" ]] && { echo "missing --advice-file" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "missing --repo (and \$REPO not set)" >&2; exit 1; }
[[ -f "$ADVICE_FILE" ]] || { echo "advice file not found: $ADVICE_FILE" >&2; exit 1; }

# 1. Validate format
VALIDATOR="${VALIDATOR:-$(dirname "$0")/../validate/advice-format.sh}"
if [[ ! -x "$VALIDATOR" ]]; then
  # Try chmod
  chmod +x "$VALIDATOR" 2>/dev/null || true
fi

if ! bash "$VALIDATOR" --role design-advisor "$ADVICE_FILE"; then
  echo "advice format validation failed; refusing to post" >&2
  exit 2
fi

# 2. Post the advice as a comment
if ! gh issue comment "$ISSUE" --repo "$REPO" --body-file "$ADVICE_FILE" >/dev/null; then
  echo "failed to post advice comment to issue #$ISSUE" >&2
  exit 3
fi

echo "advice posted to #$ISSUE"

# 3. Close the consultation issue
# This is what scan-unblock.sh watches for.
if ! gh issue close "$ISSUE" --repo "$REPO" >/dev/null; then
  echo "failed to close issue #$ISSUE (advice was posted)" >&2
  exit 4
fi

echo "consultation #$ISSUE closed"

# 4. Journal-end
SHARED_ACTIONS="${SHARED_ACTIONS:-$(dirname "$0")/../../_shared/actions}"
if [[ -x "$SHARED_ACTIONS/write-journal.sh" ]]; then
  bash "$SHARED_ACTIONS/write-journal.sh" \
    --issue "$ISSUE" \
    --role "design-advisor" \
    --event "consultation-complete" \
    --note "advice posted; issue closed" || true
fi

exit 0
