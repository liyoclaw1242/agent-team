#!/usr/bin/env bash
# post-verdict.sh — validate, post, and route a QA verdict.
#
# This is the most contract-strict action in the QA skill. The verdict format
# is parsed by pre-triage.sh; any deviation breaks downstream automation.
# This action validates format BEFORE posting.
#
# Usage:
#   post-verdict.sh
#       --issue N                       the QA issue number
#       --pr PR_N                       the PR being verified
#       --verdict-file PATH             markdown file with the verdict
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Exit codes:
#   0 verdict posted, issue routed
#   1 argument error
#   2 verdict format invalid
#   3 GitHub API error
#   4 routing failure (verdict posted but routing failed)

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-qa}"
ISSUE_N=""
PR_N=""
VERDICT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)        ISSUE_N="$2"; shift 2 ;;
    --pr)           PR_N="$2"; shift 2 ;;
    --verdict-file) VERDICT_FILE="$2"; shift 2 ;;
    --repo)         REPO="$2"; shift 2 ;;
    --agent-id)     AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$PR_N"    ]] && { echo "--pr required" >&2; exit 1; }
[[ -z "$VERDICT_FILE" || ! -f "$VERDICT_FILE" ]] && { echo "--verdict-file required and must exist" >&2; exit 1; }

# ─── Validate verdict format ────────────────────────────────────────────────
echo "Validating verdict format..."

# Check 1: first non-blank line must match exactly
first_line=$(grep -v '^$' "$VERDICT_FILE" | head -n1)
if [[ ! "$first_line" =~ ^##\ QA\ Verdict:\ (PASS|FAIL)$ ]]; then
  echo "VERDICT FORMAT FAIL: first line must be exactly '## QA Verdict: PASS' or '## QA Verdict: FAIL'" >&2
  echo "  found: $first_line" >&2
  exit 2
fi
verdict_outcome=$(echo "$first_line" | grep -oE 'PASS|FAIL')

# Check 2: triage line present
triage_line=$(grep -E '^triage:\s+' "$VERDICT_FILE" | head -n1 || true)
if [[ -z "$triage_line" ]]; then
  echo "VERDICT FORMAT FAIL: missing 'triage:' line" >&2
  exit 2
fi

triage_value=$(echo "$triage_line" | sed -E 's/^triage:\s+//; s/[[:space:]]*$//')
case "$triage_value" in
  none|fe|be|ops|design) ;;
  *) echo "VERDICT FORMAT FAIL: triage: must be one of {none, fe, be, ops, design}; found '$triage_value'" >&2; exit 2 ;;
esac

# Check 3: triage consistency with outcome
if [[ "$verdict_outcome" == "PASS" && "$triage_value" != "none" ]]; then
  echo "VERDICT FORMAT FAIL: PASS verdict requires 'triage: none'; found '$triage_value'" >&2
  exit 2
fi

if [[ "$verdict_outcome" == "FAIL" && "$triage_value" == "none" ]]; then
  echo "VERDICT FORMAT FAIL: FAIL verdict requires a triage role (fe/be/ops/design), not 'none'" >&2
  exit 2
fi

# Check 4: Verified-on line present
verified_on=$(grep -oE '^Verified-on:\s+[a-f0-9]{7,}' "$VERDICT_FILE" || true)
if [[ -z "$verified_on" ]]; then
  echo "VERDICT FORMAT FAIL: missing 'Verified-on: <SHA>' line (SHA must be ≥7 hex chars)" >&2
  exit 2
fi

echo "  ✓ verdict format OK ($verdict_outcome, triage: $triage_value)"

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

# ─── Post verdict on PR ─────────────────────────────────────────────────────
echo "Posting verdict on PR #$PR_N..."
gh pr comment "$PR_N" --repo "$REPO" --body-file "$VERDICT_FILE" >/dev/null \
  || { echo "failed to post verdict on PR #$PR_N" >&2; exit 3; }

# ─── Post summary on the QA issue ───────────────────────────────────────────
SUMMARY_TMP=$(mktemp)
trap 'rm -f "$SUMMARY_TMP"' EXIT
{
  echo "## Verdict: $verdict_outcome"
  echo ""
  echo "Posted to PR #$PR_N. See the verdict comment for AC walk and evidence."
  echo ""
  if [[ "$verdict_outcome" == "FAIL" ]]; then
    echo "**Triage**: $triage_value"
  fi
} > "$SUMMARY_TMP"
gh issue comment "$ISSUE_N" --repo "$REPO" --body-file "$SUMMARY_TMP" >/dev/null \
  || echo "warning: failed to post summary on QA issue #$ISSUE_N" >&2

# ─── Route the QA issue ─────────────────────────────────────────────────────
# PASS: close the QA issue (status:done). The PR's merge will close the
#       implementer's issue separately via scan-complete-requests.sh or
#       pre-triage.sh.
# FAIL: route to agent:arch (dispatcher → pre-triage will read the verdict
#       on the PR and route per `triage:`).

if [[ "$verdict_outcome" == "PASS" ]]; then
  "$ROUTE_SH" "$ISSUE_N" "qa" \
    --repo "$REPO" \
    --agent-id "$AGENT_ID" \
    --reason "verdict PASS for PR #$PR_N" \
    --status done \
    >/dev/null \
    || { echo "ERROR: failed to route QA issue to status:done" >&2; exit 4; }
  gh issue close "$ISSUE_N" --repo "$REPO" >/dev/null || true
else
  "$ROUTE_SH" "$ISSUE_N" "arch" \
    --repo "$REPO" \
    --agent-id "$AGENT_ID" \
    --reason "verdict FAIL for PR #$PR_N; triage to $triage_value" \
    >/dev/null \
    || { echo "ERROR: failed to route QA issue to arch" >&2; exit 4; }
fi

# ─── Journal ────────────────────────────────────────────────────────────────
[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "verdict-posted" "outcome=$verdict_outcome triage=$triage_value pr=#$PR_N" \
  || true

echo "verdict posted: $verdict_outcome on PR #$PR_N (triage: $triage_value)"
