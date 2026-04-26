#!/usr/bin/env bash
# feedback.sh — post Mode C technical feedback and route to arch.
#
# Validates the feedback header is exactly '## Technical Feedback from design'
# (the marker that arch dispatcher uses to route to arch-feedback).
#
# Usage:
#   feedback.sh --issue N --feedback-file PATH [--repo OWNER/REPO]
#
# Exit codes:
#   0 success
#   1 arg/setup error
#   2 feedback format invalid
#   3 post failed
#   4 route failed

set -euo pipefail

REPO="${REPO:-}"
ISSUE=""
FEEDBACK_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)         ISSUE="$2"; shift 2 ;;
    --repo)          REPO="$2"; shift 2 ;;
    --feedback-file) FEEDBACK_FILE="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE" ]] && { echo "missing --issue" >&2; exit 1; }
[[ -z "$FEEDBACK_FILE" ]] && { echo "missing --feedback-file" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "missing --repo (and \$REPO not set)" >&2; exit 1; }
[[ -f "$FEEDBACK_FILE" ]] || { echo "feedback file not found: $FEEDBACK_FILE" >&2; exit 1; }

# 1. Validate first non-empty line is exact header
first_line=$(grep -m1 -E '\S' "$FEEDBACK_FILE" | head -n1)
if [[ "$first_line" != "## Technical Feedback from design" ]]; then
  echo "feedback format invalid: first non-empty line must be exactly:" >&2
  echo "  '## Technical Feedback from design'" >&2
  echo "got: $first_line" >&2
  exit 2
fi

# 2. Validate it has the standard sections (concern category, what-spec-says,
#    what-reality-shows, options, preference)
required_sections=(
  "### Concern category"
  "### What the spec says"
  "### Options I see"
  "### My preference"
)

# Reality-shows section can have varied wording
has_reality=false
if grep -qE '^### What the (foundation|pattern|codebase|domain)' "$FEEDBACK_FILE"; then
  has_reality=true
fi

if ! $has_reality; then
  echo "feedback format invalid: missing reality section" >&2
  echo "expected '### What the foundation/pattern/codebase/... reality shows'" >&2
  exit 2
fi

for section in "${required_sections[@]}"; do
  if ! grep -qF "$section" "$FEEDBACK_FILE"; then
    echo "feedback format invalid: missing '$section' section" >&2
    exit 2
  fi
done

# 3. Post the feedback as a comment on the issue
if ! gh issue comment "$ISSUE" --repo "$REPO" --body-file "$FEEDBACK_FILE" >/dev/null; then
  echo "failed to post feedback comment to issue #$ISSUE" >&2
  exit 3
fi

echo "feedback posted to #$ISSUE"

# 4. Route to arch
ROUTE_SH="${ROUTE_SH:-$(dirname "$0")/../../scripts/route.sh}"
if [[ -x "$ROUTE_SH" ]]; then
  if ! "$ROUTE_SH" "$ISSUE" "arch" --repo "$REPO" --agent-id "design-$$" \
      --reason "Mode C feedback from design (arch-dispatcher will route to arch-feedback)" >/dev/null; then
    echo "route failed" >&2
    exit 4
  fi
  echo "issue #$ISSUE routed to agent:arch"
fi

# 5. Journal
SHARED_ACTIONS="${SHARED_ACTIONS:-$(dirname "$0")/../../_shared/actions}"
if [[ -x "$SHARED_ACTIONS/write-journal.sh" ]]; then
  bash "$SHARED_ACTIONS/write-journal.sh" \
    --issue "$ISSUE" \
    --role "design" \
    --event "feedback" \
    --note "Mode C feedback posted; routed to arch" || true
fi

exit 0
