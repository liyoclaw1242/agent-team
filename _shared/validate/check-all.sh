#!/usr/bin/env bash
# check-all.sh — run every validator in the calling skill's validate/ folder.
#
# Usage:
#   check-all.sh <skill-dir>
#
# Discovery model:
#   - Calling skill's validate/ folder may contain individual *.sh validators
#     (lint.sh, typecheck.sh, security.sh, etc.).
#   - This script runs each one in alphabetical order.
#   - First non-zero exit aborts; remaining validators are not run.
#
# This is the plug-in approach from _shared-restructure.md: each role drops
# specific validators into its own validate/ folder; the aggregator is shared.

set -euo pipefail

[[ $# -eq 1 ]] || { echo "usage: $0 <skill-dir>" >&2; exit 1; }

SKILL_DIR="$1"
[[ -d "$SKILL_DIR/validate" ]] || { echo "no validate/ folder under $SKILL_DIR" >&2; exit 1; }

cd "$SKILL_DIR"

# shellcheck source=/dev/null
[[ -f "$(dirname "$0")/lib.sh" ]] && source "$(dirname "$0")/lib.sh"

echo "═══ Validation: $(basename "$SKILL_DIR") ═══"

shopt -s nullglob
checks=( validate/*.sh )

if [[ ${#checks[@]} -eq 0 ]]; then
  echo "(no checks defined)"
  exit 0
fi

for check in "${checks[@]}"; do
  name=$(basename "$check")
  # Skip self if symlinked into validate/.
  [[ "$name" == "check-all.sh" ]] && continue
  [[ ! -x "$check" ]] && continue

  echo ""
  echo "── $name ──"
  if ! bash "$check"; then
    rc=$?
    echo ""
    echo "✗ $name exited $rc — aborting"
    exit "$rc"
  fi
  echo "✓ $name"
done

echo ""
echo "═══ All checks passed ═══"
