#!/usr/bin/env bash
# setup.sh — claim issue, set up branch, start journal
#
# Mode A (pencil-spec) doesn't open a PR (no code change); branch is
# optional but useful for any working files (e.g., explore/draft).
#
# Mode B (visual-review) doesn't need a branch (review only); just claim
# and start journal.
#
# Usage:
#   setup.sh --issue N [--repo OWNER/REPO] [--mode A|B|auto]
#
# Exit codes:
#   0 success
#   1 arg/setup error
#   2 claim conflict (someone else has the issue)

set -euo pipefail

REPO="${REPO:-}"
ISSUE=""
MODE="auto"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --issue) ISSUE="$2"; shift 2 ;;
    --repo)  REPO="$2"; shift 2 ;;
    --mode)  MODE="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

[[ -z "$ISSUE" ]] && { echo "missing --issue" >&2; exit 1; }
[[ -z "$REPO" ]] && { echo "missing --repo (and \$REPO not set)" >&2; exit 1; }

SHARED_ACTIONS="${SHARED_ACTIONS:-$(dirname "$0")/../../_shared/actions}"
[[ -d "$SHARED_ACTIONS" ]] || { echo "shared actions not found at $SHARED_ACTIONS" >&2; exit 1; }

CLAIMS_SH="${CLAIMS_SH:-$(dirname "$0")/../../scripts/claims.sh}"
[[ -x "$CLAIMS_SH" ]] || { echo "claims.sh not executable at $CLAIMS_SH" >&2; exit 1; }

# 1. Claim the issue
if ! "$CLAIMS_SH" claim "$ISSUE" --repo "$REPO" --agent-id "design-$$"; then
  echo "claim failed for #$ISSUE" >&2
  exit 2
fi

# 2. Detect mode if auto
if [[ "$MODE" == "auto" ]]; then
  body=$(gh issue view "$ISSUE" --repo "$REPO" --json body --jq '.body' 2>/dev/null || echo "")
  has_spec=false
  if echo "$body" | grep -q '<!-- design-spec-begin -->'; then has_spec=true; fi
  
  has_open_pr=false
  if gh pr list --repo "$REPO" --state open --search "in:body #$ISSUE" --json number --jq 'length' 2>/dev/null | grep -q '^[1-9]'; then
    has_open_pr=true
  fi
  
  if $has_spec && $has_open_pr; then
    MODE="B"
  else
    MODE="A"
  fi
fi

echo "Mode: $MODE"

# 3. Branch (Mode A only; Mode B doesn't need code branch)
if [[ "$MODE" == "A" ]]; then
  BRANCH="design/issue-$ISSUE-spec"
  bash "$SHARED_ACTIONS/setup-branch.sh" --branch "$BRANCH" || {
    echo "branch setup failed" >&2; exit 1;
  }
fi

# 4. Start journal
bash "$SHARED_ACTIONS/write-journal.sh" \
  --issue "$ISSUE" \
  --role "design" \
  --event "claim-and-setup" \
  --note "mode=$MODE" || true

echo "setup complete: issue #$ISSUE, mode $MODE"
exit 0
