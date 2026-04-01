#!/bin/bash
# Sync agent-team to ~/.claude/ (or .claude/ with --project)
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TARGET="$HOME/.claude"

if [ "$1" = "--project" ]; then
  TARGET="$(pwd)/.claude"
fi

echo "Syncing agent-team → $TARGET"

# Commands
mkdir -p "$TARGET/commands"
cp "$SCRIPT_DIR/commands/create-agent-employ.md" "$TARGET/commands/"
echo "  commands/create-agent-employ.md"

# Skills (8 role-based skills with full directory structure)
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  skill_name="$(basename "$skill_dir")"
  cp -r "$skill_dir" "$TARGET/skills/$skill_name"
  echo "  skills/$skill_name/"
done

# Config (don't overwrite user customizations)
if [ ! -f "$TARGET/agent-team.config.md" ]; then
  cp "$SCRIPT_DIR/agent-team.config.md" "$TARGET/"
  echo "  agent-team.config.md (new)"
else
  echo "  agent-team.config.md (skipped, already exists)"
fi

# Journal dir
mkdir -p "$HOME/.agent-team/journal"

echo "Done."
