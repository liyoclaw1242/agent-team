#!/usr/bin/env bash
# write-journal.sh — append a journal entry under the calling skill's log/.
#
# Usage:
#   write-journal.sh <skill-dir> <issue-number> <event> [details...]
#
# <skill-dir>    absolute path to the calling skill (e.g. /path/to/skills/fe)
# <issue-number> issue this entry pertains to
# <event>        short event tag (claimed, delivered, blocked, fail, etc.)
# [details]      free-form trailing args, joined with spaces
#
# Output goes to <skill-dir>/log/YYYY-MM-DD.jsonl, one JSON object per line.
# This is deliberately simple (JSONL, not structured DB) so any agent can
# tail/grep without tooling.

set -euo pipefail

[[ $# -ge 3 ]] || { echo "usage: $0 <skill-dir> <issue-number> <event> [details...]" >&2; exit 1; }

SKILL_DIR="$1"; shift
ISSUE_N="$1"; shift
EVENT="$1"; shift
DETAILS="$*"

[[ -d "$SKILL_DIR" ]] || { echo "skill-dir not found: $SKILL_DIR" >&2; exit 1; }
[[ "$ISSUE_N" =~ ^[0-9]+$ ]] || { echo "issue-number must be numeric: $ISSUE_N" >&2; exit 1; }

LOG_DIR="$SKILL_DIR/log"
mkdir -p "$LOG_DIR"

LOG_FILE="$LOG_DIR/$(date -u +%Y-%m-%d).jsonl"
TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
AGENT_ID="${AGENT_ID:-unknown}"

# JSON-escape DETAILS via jq for safety.
jq -n -c \
  --arg ts "$TS" \
  --arg agent "$AGENT_ID" \
  --argjson issue "$ISSUE_N" \
  --arg event "$EVENT" \
  --arg details "$DETAILS" \
  '{ts: $ts, agent: $agent, issue: $issue, event: $event, details: $details}' \
  >> "$LOG_FILE"
