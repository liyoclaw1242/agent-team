#!/usr/bin/env bash
# file-fix.sh — file the fix issue (or mitigation/instrumentation issue) for a
# bug investigation. Posts the root-cause report on the bug issue, creates the
# new fix issue, wires up the bug-of/fix markers and deps so the bug closes
# automatically when the fix lands.
#
# Usage:
#   file-fix.sh
#       --bug-issue N
#       --owning-role {fe|be|ops|qa|design}
#       --severity {1|2|3|4}
#       --report-file PATH
#       [--repo OWNER/REPO]
#       [--agent-id ID]
#
# Outputs to stdout: the new fix issue number.
#
# Side effects:
#   - Posts the report-file content as a comment on the bug issue
#   - Creates a new fix issue with source:arch + agent:{role} + status:ready
#   - Adds <!-- bug-of: #BUG --> to the new fix issue body
#   - Adds <!-- fix: #NEW --> to the bug issue body
#   - Routes bug to status:blocked with deps on the fix
#   - Bug stays OPEN until scan-complete-requests.sh closes it after fix merges

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-debug}"
BUG_N=""
ROLE=""
SEVERITY=""
REPORT_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --bug-issue)   BUG_N="$2"; shift 2 ;;
    --owning-role) ROLE="$2"; shift 2 ;;
    --severity)    SEVERITY="$2"; shift 2 ;;
    --report-file) REPORT_FILE="$2"; shift 2 ;;
    --repo)        REPO="$2"; shift 2 ;;
    --agent-id)    AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"        ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$BUG_N"       ]] && { echo "--bug-issue required" >&2; exit 1; }
[[ -z "$ROLE"        ]] && { echo "--owning-role required" >&2; exit 1; }
[[ -z "$SEVERITY"    ]] && { echo "--severity required" >&2; exit 1; }
[[ -z "$REPORT_FILE" || ! -f "$REPORT_FILE" ]] && { echo "--report-file required and must exist" >&2; exit 1; }

case "$ROLE" in
  fe|be|ops|qa|design) ;;
  *) echo "invalid --owning-role: $ROLE" >&2; exit 1 ;;
esac
[[ "$SEVERITY" =~ ^[1-4]$ ]] || { echo "--severity must be 1, 2, 3, or 4" >&2; exit 1; }

# Helpers
ROUTE_SH="${ROUTE_SH:-}"
if [[ -z "$ROUTE_SH" ]]; then
  if   [[ -x "$HOME/.claude/scripts/route.sh" ]]; then ROUTE_SH="$HOME/.claude/scripts/route.sh"
  elif [[ -x "scripts/route.sh"               ]]; then ROUTE_SH="$(pwd)/scripts/route.sh"
  else echo "route.sh not found" >&2; exit 1
  fi
fi

ISSUE_META_SH="${ISSUE_META_SH:-}"
if [[ -z "$ISSUE_META_SH" ]]; then
  if   [[ -x "$HOME/.claude/skills/_shared/actions/issue-meta.sh" ]]; then ISSUE_META_SH="$HOME/.claude/skills/_shared/actions/issue-meta.sh"
  elif [[ -x "skills/_shared/actions/issue-meta.sh"               ]]; then ISSUE_META_SH="$(pwd)/skills/_shared/actions/issue-meta.sh"
  else echo "issue-meta.sh not found" >&2; exit 1
  fi
fi

# ─── Read bug summary for fix title ─────────────────────────────────────────
bug_title=$(gh issue view "$BUG_N" --repo "$REPO" --json title --jq '.title') \
  || { echo "cannot read bug #$BUG_N" >&2; exit 2; }

# Strip "[Bug] " or "[Alert] " prefix if present
clean_title="${bug_title#[Bug] }"
clean_title="${clean_title#[Alert] }"

FIX_TITLE="[$(echo "$ROLE" | tr '[:lower:]' '[:upper:]')] Fix: $clean_title"

# ─── Compose fix issue body ─────────────────────────────────────────────────
FIX_BODY=$(mktemp)
trap 'rm -f "$FIX_BODY"' EXIT

{
  echo "## Bug"
  echo ""
  echo "This fixes #$BUG_N."
  echo ""
  echo "## Root cause summary"
  echo ""
  # Extract only the "Hypothesis confirmed" + "Why this happens" sections
  # from the report. Fallback to the whole report if extraction fails.
  if grep -q "### Hypothesis confirmed" "$REPORT_FILE"; then
    awk '/^### Hypothesis confirmed/,/^### Suggested owning role/' "$REPORT_FILE" \
      | grep -v "^### Suggested owning role"
  else
    cat "$REPORT_FILE"
  fi
  echo ""
  echo "Full investigation: see #$BUG_N comment thread."
  echo ""
  echo "## Acceptance criteria"
  echo ""
  echo "- [ ] Root cause from #$BUG_N is addressed"
  echo "- [ ] Reproduction recipe from #$BUG_N now passes"
  echo "- [ ] Regression test added covering the failing path"
  echo "- [ ] No regression in adjacent functionality"
  echo ""
  echo "## Severity: $SEVERITY"
  echo ""
  echo ""
  echo "<!-- bug-of: #$BUG_N -->"
  echo "<!-- parent: #$BUG_N -->"
  echo "<!-- severity: $SEVERITY -->"
} > "$FIX_BODY"

LABELS="source:arch,agent:$ROLE,status:ready"

# ─── Create fix issue ───────────────────────────────────────────────────────
new_n=$(gh issue create --repo "$REPO" \
  --title "$FIX_TITLE" \
  --body-file "$FIX_BODY" \
  --label "$LABELS" \
  | grep -oE '/issues/[0-9]+' \
  | grep -oE '[0-9]+$')

if [[ -z "$new_n" ]]; then
  echo "failed to extract new fix issue number" >&2
  exit 3
fi

# ─── Post root-cause report on the bug ──────────────────────────────────────
gh issue comment "$BUG_N" --repo "$REPO" --body-file "$REPORT_FILE" >/dev/null \
  || { echo "warning: failed to post report on bug #$BUG_N" >&2; }

# Add fix marker and deps to bug issue
REPO="$REPO" "$ISSUE_META_SH" set "$BUG_N" fix "#$new_n" \
  || echo "warning: failed to set fix marker on bug" >&2
REPO="$REPO" "$ISSUE_META_SH" set "$BUG_N" deps "#$new_n" \
  || echo "warning: failed to set deps marker on bug" >&2

# Route bug to status:blocked (it stays at agent:debug semantically; the deps marker is what scan-unblock watches)
"$ROUTE_SH" "$BUG_N" "debug" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "fix #$new_n filed; bug awaits fix merge" \
  --status blocked \
  >/dev/null \
  || { echo "warning: failed to route bug #$BUG_N to blocked" >&2; }

# Closing comment on the bug clarifying lifecycle
LIFECYCLE_TMP=$(mktemp)
{
  echo "## Investigation complete — fix filed at #$new_n"
  echo ""
  echo "**This bug issue stays open** until the fix PR (#$new_n's resulting PR) merges."
  echo "\`scan-complete-requests.sh\` will close this bug automatically at that point."
  echo ""
  echo "If you have additional info that would change the diagnosis, comment here and re-route to \`agent:debug\` for re-investigation."
} > "$LIFECYCLE_TMP"
gh issue comment "$BUG_N" --repo "$REPO" --body-file "$LIFECYCLE_TMP" >/dev/null \
  || echo "warning: failed to post lifecycle comment on bug" >&2
rm -f "$LIFECYCLE_TMP"

echo "$new_n"
