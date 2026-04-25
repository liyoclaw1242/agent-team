#!/usr/bin/env bash
# feedback.sh — QA Mode C feedback. Mirrors fe/be feedback.sh.
#
# Usage:
#   feedback.sh
#       --issue N
#       --feedback-file PATH
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-qa}"
ISSUE_N=""
FB_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)         ISSUE_N="$2"; shift 2 ;;
    --feedback-file) FB_FILE="$2"; shift 2 ;;
    --repo)          REPO="$2"; shift 2 ;;
    --agent-id)      AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$FB_FILE" || ! -f "$FB_FILE" ]] && { echo "--feedback-file required and must exist" >&2; exit 1; }

# Header validation
first_line=$(grep -v '^$' "$FB_FILE" | head -n1)
expected="## Technical Feedback from qa"
if [[ "$first_line" != "$expected" ]]; then
  echo "feedback file does not start with the required header." >&2
  echo "expected: $expected" >&2
  echo "found:    $first_line" >&2
  exit 1
fi

# Helpers
ROUTE_SH="${ROUTE_SH:-}"
if [[ -z "$ROUTE_SH" ]]; then
  if   [[ -x "$HOME/.claude/scripts/route.sh" ]]; then ROUTE_SH="$HOME/.claude/scripts/route.sh"
  elif [[ -x "scripts/route.sh"               ]]; then ROUTE_SH="$(pwd)/scripts/route.sh"
  else echo "route.sh not found" >&2; exit 1
  fi
fi

WRITE_JOURNAL_SH="${WRITE_JOURNAL_SH:-}"
if [[ -z "$WRITE_JOURNAL_SH" ]]; then
  if   [[ -x "$HOME/.claude/skills/_shared/actions/write-journal.sh" ]]; then WRITE_JOURNAL_SH="$HOME/.claude/skills/_shared/actions/write-journal.sh"
  elif [[ -x "skills/_shared/actions/write-journal.sh"               ]]; then WRITE_JOURNAL_SH="$(pwd)/skills/_shared/actions/write-journal.sh"
  fi
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

gh issue comment "$ISSUE_N" --repo "$REPO" --body-file "$FB_FILE" >/dev/null \
  || { echo "failed to post feedback comment on #$ISSUE_N" >&2; exit 3; }

"$ROUTE_SH" "$ISSUE_N" "arch" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "Mode C feedback from qa; awaiting arch-feedback decision" \
  >/dev/null \
  || { echo "failed to route #$ISSUE_N back to arch" >&2; exit 3; }

[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "feedback-posted" "routed to arch" \
  || true

echo "feedback posted on #$ISSUE_N, routed to agent:arch"
