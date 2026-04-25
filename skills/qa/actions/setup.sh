#!/usr/bin/env bash
# setup.sh — claim a QA issue, create branch (test-plan mode only), journal.
#
# Usage:
#   setup.sh
#       --issue N
#       --mode {test-plan|verify}
#       [--slug SLUG]                  required only for test-plan mode (no branch in verify)
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Note: verify mode doesn't create a branch — QA is verifying someone else's
# branch, not making code changes.

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-qa}"
ISSUE_N=""
MODE=""
SLUG=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)    ISSUE_N="$2"; shift 2 ;;
    --mode)     MODE="$2"; shift 2 ;;
    --slug)     SLUG="$2"; shift 2 ;;
    --repo)     REPO="$2"; shift 2 ;;
    --agent-id) AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$MODE"    ]] && { echo "--mode required" >&2; exit 1; }

case "$MODE" in
  test-plan)
    [[ -z "$SLUG" ]] && { echo "--slug required for test-plan mode" >&2; exit 1; }
    ;;
  verify)
    if [[ -n "$SLUG" ]]; then
      echo "warn: --slug ignored in verify mode (no branch created)"
    fi
    ;;
  *) echo "invalid --mode: $MODE (must be test-plan or verify)" >&2; exit 1 ;;
esac

# Helpers
CLAIMS_SH="${CLAIMS_SH:-}"
if [[ -z "$CLAIMS_SH" ]]; then
  if   [[ -x "$HOME/.claude/scripts/claims.sh" ]]; then CLAIMS_SH="$HOME/.claude/scripts/claims.sh"
  elif [[ -x "scripts/claims.sh"               ]]; then CLAIMS_SH="$(pwd)/scripts/claims.sh"
  else echo "claims.sh not found" >&2; exit 1
  fi
fi

WRITE_JOURNAL_SH="${WRITE_JOURNAL_SH:-}"
if [[ -z "$WRITE_JOURNAL_SH" ]]; then
  if   [[ -x "$HOME/.claude/skills/_shared/actions/write-journal.sh" ]]; then WRITE_JOURNAL_SH="$HOME/.claude/skills/_shared/actions/write-journal.sh"
  elif [[ -x "skills/_shared/actions/write-journal.sh"               ]]; then WRITE_JOURNAL_SH="$(pwd)/skills/_shared/actions/write-journal.sh"
  fi
fi

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)"

# Claim
"$CLAIMS_SH" "$ISSUE_N" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --note "qa starting work in $MODE mode" \
  || { echo "failed to claim issue #$ISSUE_N" >&2; exit 3; }

# Branch only for test-plan mode
if [[ "$MODE" == "test-plan" ]]; then
  SETUP_BRANCH_SH="${SETUP_BRANCH_SH:-}"
  if [[ -z "$SETUP_BRANCH_SH" ]]; then
    if   [[ -x "$HOME/.claude/skills/_shared/actions/setup-branch.sh" ]]; then SETUP_BRANCH_SH="$HOME/.claude/skills/_shared/actions/setup-branch.sh"
    elif [[ -x "skills/_shared/actions/setup-branch.sh"               ]]; then SETUP_BRANCH_SH="$(pwd)/skills/_shared/actions/setup-branch.sh"
    else echo "setup-branch.sh not found" >&2; exit 1
    fi
  fi
  branch=$("$SETUP_BRANCH_SH" qa "$ISSUE_N" "$SLUG") \
    || { echo "failed to create branch" >&2; exit 3; }
else
  branch="(no branch — verify mode)"
fi

[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "claimed" "mode=$MODE branch=$branch" \
  || true

echo "$branch"
