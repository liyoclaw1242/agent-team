#!/usr/bin/env bash
# setup-branch.sh — create and check out a working branch following the
# project's branch naming convention (see _shared/rules/git.md).
#
# Usage:
#   setup-branch.sh <role> <issue-number> <slug>
#
# Example:
#   setup-branch.sh fe 142 cancel-button
#   → creates branch fe/issue-142-cancel-button from origin's default branch
#
# Behaviour:
#   - Fetches origin
#   - Creates branch from origin's HEAD of the default branch
#   - Refuses to overwrite an existing branch unless FORCE=1
#   - Checks out the new branch

set -euo pipefail

[[ $# -eq 3 ]] || { echo "usage: $0 <role> <issue-number> <slug>" >&2; exit 1; }

ROLE="$1"
ISSUE_N="$2"
SLUG="$3"

# Validate inputs against git.md naming rules.
[[ "$ROLE" =~ ^(fe|be|ops|qa|design|debug|arch-[a-z]+)$ ]] \
  || { echo "invalid role: $ROLE (must match the LABEL_RULES.md agent set)" >&2; exit 1; }
[[ "$ISSUE_N" =~ ^[0-9]+$ ]] \
  || { echo "issue-number must be numeric: $ISSUE_N" >&2; exit 1; }
[[ "$SLUG" =~ ^[a-z0-9-]+$ ]] \
  || { echo "slug must be lowercase a-z, 0-9, hyphen: $SLUG" >&2; exit 1; }

BRANCH="$ROLE/issue-$ISSUE_N-$SLUG"

# Determine default branch from origin (handles repos using main, master, etc.)
git fetch --quiet origin
DEFAULT_BRANCH=$(git symbolic-ref --short refs/remotes/origin/HEAD | sed 's|^origin/||') \
  || DEFAULT_BRANCH=main

# Check if branch already exists, locally or on origin.
if git show-ref --verify --quiet "refs/heads/$BRANCH" \
   || git show-ref --verify --quiet "refs/remotes/origin/$BRANCH"; then
  if [[ "${FORCE:-0}" != "1" ]]; then
    echo "branch already exists: $BRANCH (set FORCE=1 to overwrite)" >&2
    exit 1
  fi
  git branch -D "$BRANCH" 2>/dev/null || true
fi

# Create from origin's default branch HEAD.
git checkout -b "$BRANCH" "origin/$DEFAULT_BRANCH"

echo "$BRANCH"
