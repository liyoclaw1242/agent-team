#!/usr/bin/env bash
# deliver.sh — BE delivery gate.
#
# Same shape as fe/actions/deliver.sh but with one BE-specific check:
# the branch must contain at least one commit whose message starts with
# `test(` (TDD iron law evidence).
#
# Usage:
#   deliver.sh
#       --issue N
#       --self-test PATH
#       --pr-title "..."
#       --pr-body-file PATH
#       [--route-to ROLE]
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Exit codes:
#   0 delivered
#   1 argument error
#   2 self-test gate failed (or TDD evidence missing)
#   3 git/gh failure
#   4 routing failure (PR opened but routing failed)

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-be}"
ISSUE_N=""
SELF_TEST=""
PR_TITLE=""
PR_BODY_FILE=""
ROUTE_TO=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)        ISSUE_N="$2"; shift 2 ;;
    --self-test)    SELF_TEST="$2"; shift 2 ;;
    --pr-title)     PR_TITLE="$2"; shift 2 ;;
    --pr-body-file) PR_BODY_FILE="$2"; shift 2 ;;
    --route-to)     ROUTE_TO="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --agent-id)     AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"        ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N"     ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$SELF_TEST"   ]] && { echo "--self-test required" >&2; exit 1; }
[[ -z "$PR_TITLE"    ]] && { echo "--pr-title required" >&2; exit 1; }
[[ -z "$PR_BODY_FILE" || ! -f "$PR_BODY_FILE" ]] && { echo "--pr-body-file required and must exist" >&2; exit 1; }

# ─── Self-test gate ─────────────────────────────────────────────────────────
echo "Self-test gate: checking $SELF_TEST"
[[ -f "$SELF_TEST" ]] || { echo "GATE FAIL: self-test record not found: $SELF_TEST" >&2; exit 2; }

grep -q "^## Acceptance criteria" "$SELF_TEST" \
  || { echo "GATE FAIL: missing '## Acceptance criteria' section" >&2; exit 2; }

ac_section=$(awk '/^## Acceptance criteria/,/^## /' "$SELF_TEST" | grep -E '^- \[' || true)
unchecked=$(echo "$ac_section" | grep -E '^- \[ \]' || true)
if [[ -n "$unchecked" ]]; then
  echo "GATE FAIL: unchecked AC in self-test:" >&2
  echo "$unchecked" >&2
  exit 2
fi

grep -q "^## Ready for review: yes" "$SELF_TEST" \
  || { echo "GATE FAIL: missing '## Ready for review: yes' line" >&2; exit 2; }

echo "  ✓ self-test gate passed"

# ─── BE-specific: TDD evidence check ────────────────────────────────────────
echo "TDD evidence check: looking for test(...) commits"
current_branch=$(git rev-parse --abbrev-ref HEAD)
default_branch=$(git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null | sed 's|^origin/||' || echo "main")

test_commit_count=$(git log "origin/$default_branch..$current_branch" --grep "^test(" --oneline | wc -l)
if [[ "$test_commit_count" -lt 1 ]]; then
  echo "GATE FAIL: no test(...) commits in branch (TDD iron law violation)" >&2
  echo "  At least one commit with message starting 'test(' is required." >&2
  echo "  See _shared/rules/git.md for commit format and rules/tdd-iron-law.md." >&2
  exit 2
fi
echo "  ✓ found $test_commit_count test commit(s)"

# ─── Helpers ────────────────────────────────────────────────────────────────
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

# ─── Determine routing ──────────────────────────────────────────────────────
if [[ -z "$ROUTE_TO" ]]; then
  parent=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body' \
             | grep -oP '<!--\s*parent:\s*#\K[0-9]+' | head -n1 || true)
  if [[ -n "$parent" ]]; then
    qa_sibling=$(gh issue list --repo "$REPO" \
      --label "agent:qa" \
      --state open \
      --search "in:body parent:#$parent" \
      --json number --jq '.[0].number // ""' 2>/dev/null || echo "")
    if [[ -n "$qa_sibling" ]]; then
      ROUTE_TO="qa"
    else
      ROUTE_TO="arch"
    fi
  else
    ROUTE_TO="arch"
  fi
  echo "  auto-detected route target: $ROUTE_TO"
fi

# ─── Push branch ────────────────────────────────────────────────────────────
echo "Pushing branch: $current_branch"
git push -u origin "$current_branch" >/dev/null 2>&1 \
  || { echo "git push failed" >&2; exit 3; }

# ─── Compose PR body ────────────────────────────────────────────────────────
PR_BODY_TMP=$(mktemp)
trap 'rm -f "$PR_BODY_TMP"' EXIT

cat "$PR_BODY_FILE" > "$PR_BODY_TMP"
{
  echo ""
  echo "---"
  echo ""
  echo "## Self-test record"
  echo ""
  echo '<details>'
  echo '<summary>Click to expand</summary>'
  echo ""
  cat "$SELF_TEST"
  echo ""
  echo '</details>'
  echo ""
  echo "Refs: #$ISSUE_N"
} >> "$PR_BODY_TMP"

# ─── Open PR ────────────────────────────────────────────────────────────────
echo "Opening PR..."
pr_url=$(gh pr create --repo "$REPO" \
  --title "$PR_TITLE" \
  --body-file "$PR_BODY_TMP" 2>&1 | grep -E 'https?://github.com/.*/pull/' | head -n1)

if [[ -z "$pr_url" ]]; then
  echo "gh pr create failed" >&2
  exit 3
fi

pr_n=$(echo "$pr_url" | grep -oE '[0-9]+$')
echo "  ✓ PR #$pr_n opened: $pr_url"

# ─── Route ──────────────────────────────────────────────────────────────────
"$ROUTE_SH" "$ISSUE_N" "$ROUTE_TO" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "be delivered PR #$pr_n; ready for $ROUTE_TO review" \
  >/dev/null \
  || { echo "ERROR: routing failed; PR #$pr_n is open" >&2; exit 4; }

# ─── Journal ────────────────────────────────────────────────────────────────
[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "delivered" "pr=#$pr_n route=$ROUTE_TO test_commits=$test_commit_count" \
  || true

echo "delivered: issue #$ISSUE_N → PR #$pr_n → agent:$ROUTE_TO"
