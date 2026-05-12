#!/usr/bin/env bash
# Copies Hermes-domain skills from .claude/skills/ to ~/.hermes/skills/{category}/{skill-name}/
# Category mapping mirrors agent-team.workflow.yaml hermes-intake/hermes-design add_dirs.
# Run from anywhere; uses SCRIPT_DIR to locate source skills.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$SCRIPT_DIR/.claude/skills"
DEST="${HERMES_SKILLS_DIR:-$HOME/.hermes/skills}"

# Source of truth: workflow yaml hermes-intake.add_dirs + hermes-design.add_dirs
INTAKE_SKILLS=(
  signal-to-spec
  business-model-probe
  deployment-constraints-probe
  production-monitor
  intake-confirmation
)

DESIGN_SKILLS=(
  decompose-spec
  compute-impact-scope
  select-deployment-strategy
  draft-adr
  draft-contract
  design-dialogue
  design-approval
)

copy_skill() {
  local category="$1"
  local skill="$2"
  local src_dir="$SRC/$skill"
  local dst_dir="$DEST/$category/$skill"

  if [[ ! -d "$src_dir" ]]; then
    echo "  WARN  $skill — source not found at $src_dir, skipping" >&2
    return
  fi

  mkdir -p "$dst_dir"
  # Always sync SKILL.md
  cp "$src_dir/SKILL.md" "$dst_dir/SKILL.md"

  # Sync optional subdirs if present
  for subdir in references scripts templates; do
    if [[ -d "$src_dir/$subdir" ]]; then
      rsync -a --delete "$src_dir/$subdir/" "$dst_dir/$subdir/"
    fi
  done

  echo "  OK    $category/$skill"
}

echo "Syncing Hermes skills → $DEST"
echo ""

echo "[intake]"
for skill in "${INTAKE_SKILLS[@]}"; do
  copy_skill intake "$skill"
done

echo ""
echo "[design]"
for skill in "${DESIGN_SKILLS[@]}"; do
  copy_skill design "$skill"
done

echo ""
echo "Done."
