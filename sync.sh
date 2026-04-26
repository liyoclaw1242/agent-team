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

# Shared scripts (route, claims, poll, pre-triage, scan-*)
mkdir -p "$TARGET/scripts"
cp "$SCRIPT_DIR/scripts/"*.sh "$TARGET/scripts/"
chmod +x "$TARGET/scripts/"*.sh
echo "  scripts/"

# Shared contract layer (rules, actions, validate, domain, design-foundations)
# Skills reference _shared/ — must be present at the install target.
rm -rf "$TARGET/_shared"
cp -r "$SCRIPT_DIR/_shared" "$TARGET/_shared"
find "$TARGET/_shared" -name '*.sh' -exec chmod +x {} +
echo "  _shared/"

# Skills (role-based skills with full directory structure)
mkdir -p "$TARGET/skills"
for skill_dir in "$SCRIPT_DIR/skills/"*/; do
  skill_name="$(basename "$skill_dir")"
  rm -rf "$TARGET/skills/$skill_name"
  cp -r "$skill_dir" "$TARGET/skills/$skill_name"
  find "$TARGET/skills/$skill_name" -name '*.sh' -exec chmod +x {} +
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
