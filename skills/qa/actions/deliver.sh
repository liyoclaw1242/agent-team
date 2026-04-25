#!/usr/bin/env bash
# deliver.sh — finish a QA task. Mode-aware:
#   - test-plan: verify the plan was published, route issue to status:done
#   - verify: deliver was already done by post-verdict.sh; this is a no-op
#     wrapper for symmetry, accepting the same flags but exits 0 with a hint
#
# Usage:
#   deliver.sh
#       --issue N
#       --self-test PATH
#       --mode {test-plan|verify}
#       [--repo OWNER/REPO]
#       [--agent-id ID]

set -euo pipefail

REPO="${REPO:-}"
AGENT_ID="${AGENT_ID:-qa}"
ISSUE_N=""
SELF_TEST=""
MODE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)     ISSUE_N="$2"; shift 2 ;;
    --self-test) SELF_TEST="$2"; shift 2 ;;
    --mode)      MODE="$2"; shift 2 ;;
    --repo)      REPO="$2"; shift 2 ;;
    --agent-id)  AGENT_ID="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$REPO"    ]] && { echo "REPO not set" >&2; exit 1; }
[[ -z "$ISSUE_N" ]] && { echo "--issue required" >&2; exit 1; }
[[ -z "$SELF_TEST" ]] && { echo "--self-test required" >&2; exit 1; }
[[ -z "$MODE"    ]] && { echo "--mode required" >&2; exit 1; }

case "$MODE" in
  test-plan|verify) ;;
  *) echo "invalid --mode: $MODE" >&2; exit 1 ;;
esac

# ─── Self-test gate ─────────────────────────────────────────────────────────
[[ -f "$SELF_TEST" ]] || { echo "GATE FAIL: self-test record not found: $SELF_TEST" >&2; exit 2; }

grep -q "^## Acceptance criteria" "$SELF_TEST" \
  || { echo "GATE FAIL: missing '## Acceptance criteria' section in self-test" >&2; exit 2; }

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

# ─── Mode-specific behaviour ────────────────────────────────────────────────
if [[ "$MODE" == "verify" ]]; then
  echo ""
  echo "Verify mode: nothing to deliver here. Use post-verdict.sh instead." >&2
  echo "(Verify-mode delivery happens via post-verdict.sh, which posts the verdict and routes." >&2
  echo " This deliver.sh is just a self-test gate check for symmetry.)" >&2
  exit 0
fi

# Test-plan mode: confirm the plan is in the issue body, then route to done

body=$(gh issue view "$ISSUE_N" --repo "$REPO" --json body --jq '.body // ""') \
  || { echo "cannot read issue #$ISSUE_N" >&2; exit 3; }

if ! echo "$body" | grep -q "<!-- qa-test-plan-begin -->"; then
  echo "GATE FAIL: issue body has no qa-test-plan block; did you run publish-test-plan.sh?" >&2
  exit 2
fi

# Locate route.sh
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

# Route to status:done; siblings depending on this issue will unblock via scan-unblock.sh
"$ROUTE_SH" "$ISSUE_N" "qa" \
  --repo "$REPO" \
  --agent-id "$AGENT_ID" \
  --reason "shift-left test plan published; sibling implementers can proceed" \
  --status done \
  >/dev/null \
  || { echo "failed to route #$ISSUE_N to status:done" >&2; exit 3; }

# Close the issue — the plan is ready, no further QA work in shift-left mode for this task
gh issue close "$ISSUE_N" --repo "$REPO" >/dev/null \
  || echo "warning: failed to close #$ISSUE_N" >&2

[[ -x "$WRITE_JOURNAL_SH" ]] && \
  AGENT_ID="$AGENT_ID" "$WRITE_JOURNAL_SH" "$SKILL_DIR" "$ISSUE_N" "delivered" "mode=$MODE" \
  || true

echo "delivered: test plan for #$ISSUE_N is published; issue closed"
