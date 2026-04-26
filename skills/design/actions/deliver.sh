#!/usr/bin/env bash
# deliver.sh — design's deliver gate. Mode-aware.
#
# Mode A (pencil-spec): verifies self-test record + that issue body
#   contains a design-spec block. Routes issue to arch.
#
# Mode B (visual-review): verifies self-test record (with verdict reference).
#   Verdict already posted via post-verdict.sh; deliver mostly checks the
#   self-test and routes to arch (which post-verdict already did, but
#   deliver acts as the consistency check).
#
# Usage:
#   deliver.sh --issue N --self-test PATH [--mode A|B|auto] [--route-to TARGET]
#
# Exit codes:
#   0 success
#   1 arg error
#   2 self-test gate failed
#   3 missing required artifact
#   4 route failed

set -euo pipefail

REPO="${REPO:-}"
ISSUE=""
SELF_TEST=""
MODE="auto"
ROUTE_TO="arch"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue)     ISSUE="$2"; shift 2 ;;
    --repo)      REPO="$2"; shift 2 ;;
    --self-test) SELF_TEST="$2"; shift 2 ;;
    --mode)      MODE="$2"; shift 2 ;;
    --route-to)  ROUTE_TO="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE" ]] && { echo "missing --issue" >&2; exit 1; }
[[ -z "$SELF_TEST" ]] && { echo "missing --self-test" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "missing --repo (and \$REPO not set)" >&2; exit 1; }
[[ -f "$SELF_TEST" ]] || { echo "self-test file not found: $SELF_TEST" >&2; exit 1; }

# 1. Self-test base gate (same as fe/be/qa/ops)

# 1a. Has Acceptance criteria section
if ! grep -qE '^## Acceptance criteria' "$SELF_TEST"; then
  echo "self-test missing '## Acceptance criteria' section" >&2
  exit 2
fi

# 1b. Every checkbox in Acceptance criteria is checked
unchecked=$(awk '
  /^## Acceptance criteria/ {flag=1; next}
  /^## / {flag=0}
  flag && /^- \[/ {print}
' "$SELF_TEST" | grep -E '^- \[ \]' | wc -l)

if [[ "$unchecked" -gt 0 ]]; then
  echo "self-test has $unchecked unchecked AC items; all must be [x]" >&2
  exit 2
fi

# 1c. Has 'Ready for review: yes'
if ! grep -qE '^## Ready for review:\s*yes' "$SELF_TEST"; then
  echo "self-test missing '## Ready for review: yes'" >&2
  exit 2
fi

# 2. Detect mode if auto
if [[ "$MODE" == "auto" ]]; then
  # If self-test references "Verdict reference" → Mode B; else Mode A
  if grep -qE '^## Verdict reference' "$SELF_TEST"; then
    MODE="B"
  else
    MODE="A"
  fi
fi

echo "delivery mode: $MODE"

# 3. Mode-specific checks
case "$MODE" in
  A)
    # 3a. Self-test has spec sections present checklist (all 3 checked)
    if ! grep -qE '^## Spec sections present' "$SELF_TEST"; then
      echo "Mode A self-test missing '## Spec sections present' section" >&2
      exit 2
    fi
    
    spec_unchecked=$(awk '
      /^## Spec sections present/ {flag=1; next}
      /^## / {flag=0}
      flag && /^- \[/ {print}
    ' "$SELF_TEST" | grep -E '^- \[ \]' | wc -l)
    
    if [[ "$spec_unchecked" -gt 0 ]]; then
      echo "Mode A self-test has $spec_unchecked unchecked spec section items" >&2
      exit 2
    fi
    
    # 3b. Self-test has Foundations consulted
    if ! grep -qE '^## Foundations consulted' "$SELF_TEST"; then
      echo "Mode A self-test missing '## Foundations consulted' section" >&2
      exit 2
    fi
    
    # 3c. Verify the issue body actually contains a design-spec block
    body=$(gh issue view "$ISSUE" --repo "$REPO" --json body --jq '.body' 2>/dev/null) || {
      echo "failed to read issue body for verification" >&2; exit 3;
    }
    
    if ! echo "$body" | grep -q '<!-- design-spec-begin -->'; then
      echo "Mode A: issue #$ISSUE body does not contain '<!-- design-spec-begin -->' marker" >&2
      echo "did you run publish-spec.sh?" >&2
      exit 3
    fi
    
    if ! echo "$body" | grep -q '<!-- design-spec-end -->'; then
      echo "Mode A: issue #$ISSUE body does not contain '<!-- design-spec-end -->' marker" >&2
      exit 3
    fi
    ;;
  
  B)
    # 3a. Self-test has Verdict reference section
    if ! grep -qE '^## Verdict reference' "$SELF_TEST"; then
      echo "Mode B self-test missing '## Verdict reference' section" >&2
      exit 2
    fi
    
    # 3b. Self-test has Foundations consulted
    if ! grep -qE '^## Foundations consulted' "$SELF_TEST"; then
      echo "Mode B self-test missing '## Foundations consulted' section" >&2
      exit 2
    fi
    ;;
  
  *)
    echo "unknown mode: $MODE (must be A or B)" >&2
    exit 1
    ;;
esac

# 4. Route to target
ROUTE_SH="${ROUTE_SH:-$(dirname "$0")/../../scripts/route.sh}"
if [[ -x "$ROUTE_SH" ]]; then
  if ! "$ROUTE_SH" "$ISSUE" "$ROUTE_TO" --repo "$REPO" --agent-id "design-$$" \
      --reason "design Mode $MODE delivered" >/dev/null; then
    echo "route failed" >&2
    exit 4
  fi
  echo "issue #$ISSUE routed to agent:$ROUTE_TO"
fi

# 5. Append delivery to journal
SHARED_ACTIONS="${SHARED_ACTIONS:-$(dirname "$0")/../../_shared/actions}"
if [[ -x "$SHARED_ACTIONS/write-journal.sh" ]]; then
  bash "$SHARED_ACTIONS/write-journal.sh" \
    --issue "$ISSUE" \
    --role "design" \
    --event "deliver" \
    --note "mode=$MODE, routed-to=$ROUTE_TO" || true
fi

echo "delivery complete: issue #$ISSUE, mode $MODE"
exit 0
