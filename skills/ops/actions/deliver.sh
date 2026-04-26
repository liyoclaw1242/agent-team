#!/usr/bin/env bash
# deliver.sh — OPS delivery gate.
#
# Adds OPS-specific gates beyond fe/be's:
#  - self-test record must include "Dry-run captured" section
#  - self-test record must include "Rollback" section (or "Change is irreversible")
#  - self-test record must include "Change-window awareness" section
#  - issue body must have an ops-plan block (from plan-change.sh)
#  - PR body must include "## Rollback" section
#
# Usage:
#   deliver.sh
#       --issue N
#       --self-test PATH
#       --pr-title "..."
#       --pr-body-file PATH
#       [--route-to ROLE]              default: arch
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Exit codes:
#   0 delivered
#   1 argument error
#   2 self-test gate failed (or OPS-specific section missing)
#   3 git/gh failure
#   4 routing failure (PR opened but routing failed)

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-ops}"
ISSUE_N=""
SELF_TEST=""
PR_TITLE=""
PR_BODY_FILE=""
ROUTE_TO="arch"

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

# ─── Standard self-test gate ────────────────────────────────────────────────
echo "Self-test gate: checking $SELF_TEST"
[[ -f "$SELF_TEST" ]] || { echo "GATE FAIL: self-test record not found" >&2; exit 2; }

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

# ─── OPS-specific gates ─────────────────────────────────────────────────────

# Dry-run section
if ! grep -qE "^## Dry-run captured" "$SELF_TEST"; then
  echo "GATE FAIL: missing '## Dry-run captured' section in self-test" >&2
  echo "  see rules/dry-run-first.md" >&2
  exit 2
fi

# Rollback section (or explicit irreversibility ack)
if ! grep -qE "^## Rollback|^## Change is irreversible" "$SELF_TEST"; then
  echo "GATE FAIL: self-test must include '## Rollback' or '## Change is irreversible' section" >&2
  echo "  see rules/reversibility.md" >&2
  exit 2
fi

# Change-window awareness section
if ! grep -qE "^## Change-window awareness" "$SELF_TEST"; then
  echo "GATE FAIL: missing '## Change-window awareness' section in self-test" >&2
  echo "  see rules/change-windows.md" >&2
  exit 2
fi

# PR body must include ## Rollback section
if ! grep -qE "^## Rollback" "$PR_BODY_FILE"; then
  echo "GATE FAIL: PR body must include '## Rollback' section" >&2
  echo "  see rules/reversibility.md" >&2
  exit 2
fi

# Issue body should have a plan block (best-effort check)
issue_body=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body // ""' 2>/dev/null || echo "")
if ! echo "$issue_body" | grep -q "<!-- ops-plan-begin -->"; then
  echo "GATE WARN: issue body has no ops-plan block (run plan-change.sh)" >&2
  echo "  proceeding anyway; reviewer should request this if missing" >&2
fi

echo "  ✓ self-test gate (incl. OPS sections) passed"

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

# ─── Push branch ────────────────────────────────────────────────────────────
current_branch=$(git rev-parse --abbrev-ref HEAD)
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
  --reason "ops delivered PR #$pr_n; ready for $ROUTE_TO review" \
  >/dev/null \
  || { echo "ERROR: routing failed; PR #$pr_n is open" >&2; exit 4; }

# ─── Journal ────────────────────────────────────────────────────────────────
[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "delivered" "pr=#$pr_n route=$ROUTE_TO" \
  || true

echo "delivered: issue #$ISSUE_N → PR #$pr_n → agent:$ROUTE_TO"
