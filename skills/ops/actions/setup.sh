#!/usr/bin/env bash
# setup.sh — claim an OPS issue, create branch, journal.
# Mirrors fe/be/qa setup.sh.
#
# Usage:
#   setup.sh
#       --issue N
#       --slug SLUG
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-ops}"
ISSUE_N=""
SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)    ISSUE_N="$2"; shift 2 ;;
    --slug)     SLUG="$2"; shift 2 ;;
    --repo)     REPO="$2"; shift 2 ;;
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$SLUG"    ]] && { echo "--slug required" >&2; exit 1; }

CLAIMS_SH="${CLAIMS_SH:-}"
if [[ -z "$CLAIMS_SH" ]]; then
  if   [[ -x "$HOME/.claude/scripts/claims.sh" ]]; then CLAIMS_SH="$HOME/.claude/scripts/claims.sh"
  elif [[ -x "scripts/claims.sh"               ]]; then CLAIMS_SH="$(pwd)/scripts/claims.sh"
  else echo "claims.sh not found" >&2; exit 1
  fi
fi

SETUP_BRANCH_SH="${SETUP_BRANCH_SH:-}"
if [[ -z "$SETUP_BRANCH_SH" ]]; then
  if   [[ -x "$HOME/.claude/skills/_shared/actions/setup-branch.sh" ]]; then SETUP_BRANCH_SH="$HOME/.claude/skills/_shared/actions/setup-branch.sh"
  elif [[ -x "skills/_shared/actions/setup-branch.sh"               ]]; then SETUP_BRANCH_SH="$(pwd)/skills/_shared/actions/setup-branch.sh"
  else echo "setup-branch.sh not found" >&2; exit 1
  fi
fi

WRITE_JOURNAL_SH="${WRITE_JOURNAL_SH:-}"
if [[ -z "$WRITE_JOURNAL_SH" ]]; then
  if   [[ -x "$HOME/.claude/skills/_shared/actions/write-journal.sh" ]]; then WRITE_JOURNAL_SH="$HOME/.claude/skills/_shared/actions/write-journal.sh"
  elif [[ -x "skills/_shared/actions/write-journal.sh"               ]]; then WRITE_JOURNAL_SH="$(pwd)/skills/_shared/actions/write-journal.sh"
  fi
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

"$CLAIMS_SH" "$ISSUE_N" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --note "ops starting work" \
  || { echo "failed to claim issue #$ISSUE_N" >&2; exit 3; }

branch=$("$SETUP_BRANCH_SH" ops "$ISSUE_N" "$SLUG") \
  || { echo "failed to create branch" >&2; exit 3; }

[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "claimed" "branch=$branch" \
  || true

echo "$branch"
