#!/usr/bin/env bash
# deliver.sh — finalise an arch-audit decomposition.
#
# Verifies fix issues are well-formed, posts summary on audit, closes audit.
#
# Usage:
#   deliver.sh
#       --audit-issue N
#       --fixes "#220,#221,#222"
#       --reason "..."
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-arch-audit}"
AUDIT_N=""
FIXES=""
REASON=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --audit-issue) AUDIT_N="$2"; shift 2 ;;
    --fixes)       FIXES="$2"; shift 2 ;;
    --reason)      REASON="$2"; shift 2 ;;
    --repo)        REPO="$2"; shift 2 ;;
    --agent-id)    AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$AUDIT_N" ]] && { echo "--audit-issue required" >&2; exit 1; }
[[ -z "$FIXES"   ]] && { echo "--fixes required" >&2; exit 1; }
[[ -z "$REASON"  ]] && { echo "--reason required" >&2; exit 1; }

# Self-test: each fix is well-formed
echo "Self-test: verifying fixes..."

IFS=',' read -ra fix_arr <<< "$FIXES"
for raw in "${fix_arr[@]}"; do
  n=$(echo "$raw" | tr -d '#[:space:]')
  [[ "$n" =~ ^[0-9]+$ ]] || { echo "invalid fix: $raw" >&2; exit 2; }

  labels=$(gh issue view "$n" --repo "$REPO" --json labels \
             --jq '[.labels[].name] | join(" ")') \
    || { echo "cannot read fix #$n" >&2; exit 2; }

  echo " $labels " | grep -q ' source:arch ' \
    || { echo "fix #$n missing source:arch" >&2; exit 2; }
  echo " $labels " | grep -qE ' agent:(fe|be|ops|qa|design) ' \
    || { echo "fix #$n missing agent label" >&2; exit 2; }

  body=$(gh issue view "$n" --repo "$REPO" --json body --jq '.body // ""')
  echo "$body" | grep -qE "<!--\s*parent:\s*#$AUDIT_N\s*-->" \
    || { echo "fix #$n missing parent marker" >&2; exit 2; }
  echo "$body" | grep -qE '<!--\s*audit-findings:\s*[0-9,\s]+\s*-->' \
    || { echo "fix #$n missing audit-findings marker" >&2; exit 2; }
  echo "$body" | grep -qE '<!--\s*severity:\s*[1-4]\s*-->' \
    || { echo "fix #$n missing severity marker" >&2; exit 2; }

  echo "  ✓ #$n"
done

# Compose summary
TMP=$(mktemp)
trap 'rm -f "$TMP"' EXIT

{
  echo "## ✅ Audit decomposed"
  echo ""
  echo "**Reason**: $REASON"
  echo ""
  echo "**Fix tasks**:"
  echo ""
  for raw in "${fix_arr[@]}"; do
    n=$(echo "$raw" | tr -d '#[:space:]')
    title=$(gh issue view "$n" --repo "$REPO" --json title --jq '.title')
    role=$(gh issue view "$n" --repo "$REPO" --json labels \
             --jq '[.labels[].name] | map(select(startswith("agent:"))) | .[0] // ""' \
             | sed 's/^agent://')
    sev=$(gh issue view "$n" --repo "$REPO" --json body --jq '.body' \
             | grep -oP '<!--\s*severity:\s*\K[1-4]' | head -n1)
    findings=$(gh issue view "$n" --repo "$REPO" --json body --jq '.body' \
             | grep -oP '<!--\s*audit-findings:\s*\K[0-9,\s]+' | head -n1 | tr -d ' ')
    echo "- [ ] #$n — \`$role\` Sev$sev — $title (findings: $findings)"
  done
  echo ""
  echo "Audit closing now."
} > "$TMP"

gh issue comment "$AUDIT_N" --repo "$REPO" --body-file "$TMP" >/dev/null \
  || { echo "failed to comment on audit #$AUDIT_N" >&2; exit 3; }

# Audit closes (terminal — fixes have their own lifecycle)
gh issue close "$AUDIT_N" --repo "$REPO" >/dev/null \
  || { echo "failed to close audit #$AUDIT_N" >&2; exit 3; }

echo "delivered: audit #$AUDIT_N closed, ${#fix_arr[@]} fixes opened"
