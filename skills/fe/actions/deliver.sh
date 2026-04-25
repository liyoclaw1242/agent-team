#!/usr/bin/env bash
# deliver.sh — the FE delivery gate.
#
# Verifies the self-test record, pushes the branch, opens a PR with the
# self-test summary in the body, then routes the issue forward.
#
# Usage:
#   deliver.sh
#       --issue N
#       --self-test PATH                  path to /tmp/self-test-issue-{N}.md
#       --pr-title "..."
#       --pr-body-file PATH               path to PR body markdown
#       [--route-to ROLE]                 default: auto-detect (qa if sibling exists, else arch)
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Exit codes:
#   0 delivered
#   1 argument error
#   2 self-test gate failed
#   3 git/gh failure
#   4 routing failure (PR opened but routing failed; issue is stuck)

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-fe}"
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

# Must contain "## Acceptance criteria" section
grep -q "^## Acceptance criteria" "$SELF_TEST" \
  || { echo "GATE FAIL: missing '## Acceptance criteria' section in self-test" >&2; exit 2; }

# Every checkbox under that section must be [x]
ac_section=$(awk '/^## Acceptance criteria/,/^## /' "$SELF_TEST" | grep -E '^- \[' || true)
unchecked=$(echo "$ac_section" | grep -E '^- \[ \]' || true)
if [[ -n "$unchecked" ]]; then
  echo "GATE FAIL: unchecked AC in self-test:" >&2
  echo "$unchecked" >&2
  exit 2
fi

# Must contain explicit ready line
grep -q "^## Ready for review: yes" "$SELF_TEST" \
  || { echo "GATE FAIL: missing '## Ready for review: yes' line" >&2; exit 2; }

echo "  ✓ self-test gate passed"

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

# ─── Determine routing target ───────────────────────────────────────────────
# Auto-detect: if a sibling QA task exists (same parent), route to qa.
# Otherwise route to arch.
if [[ -z "$ROUTE_TO" ]]; then
  parent=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body' \
             | grep -oP '<!--\s*parent:\s*#\K[0-9]+' | head -n1 || true)

  if [[ -n "$parent" ]]; then
    # Look for sibling tasks tagged agent:qa with same parent
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
current_branch=$(git rev-parse --abbrev-ref HEAD)
echo "Pushing branch: $current_branch"
git push -u origin "$current_branch" >/dev/null 2>&1 \
  || { echo "git push failed" >&2; exit 3; }

# ─── Compose PR body with self-test embedded ────────────────────────────────
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

# ─── Route the issue ────────────────────────────────────────────────────────
"$ROUTE_SH" "$ISSUE_N" "$ROUTE_TO" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "fe delivered PR #$pr_n; ready for $ROUTE_TO review" \
  >/dev/null \
  || { echo "ERROR: routing failed; PR #$pr_n is open but issue routing did not complete" >&2; exit 4; }

# ─── Journal ────────────────────────────────────────────────────────────────
[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "delivered" "pr=#$pr_n route=$ROUTE_TO" \
  || true

echo "delivered: issue #$ISSUE_N → PR #$pr_n → agent:$ROUTE_TO"
