#!/usr/bin/env bash
# Initialize a target repo for use with the agent-team workflow pipeline.
#
# Usage:
#   ./init-target-repo.sh --repo ORG/NAME --path /abs/local/path
#
# What it does:
#   1. Creates all required GitHub labels in the target repo
#   2. Updates .workflow-repos.json so sweet-home polls the target repo
#   3. Writes ~/.hermes/agent-team.env so Hermes skills know the target repo
#
# Idempotent: safe to re-run; existing labels are left unchanged.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
REPO=""
LOCAL_PATH=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)   REPO="$2";       shift 2 ;;
    --path)   LOCAL_PATH="$2"; shift 2 ;;
    --help|-h) sed -n '2,7p' "$0"; exit 0 ;;
    *)        echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$REPO" || -z "$LOCAL_PATH" ]]; then
  echo "Usage: $0 --repo ORG/NAME --path /abs/local/path" >&2
  exit 1
fi

if [[ ! -d "$LOCAL_PATH" ]]; then
  echo "Error: local path does not exist: $LOCAL_PATH" >&2
  exit 1
fi

echo "Initializing agent-team pipeline for repo: $REPO"
echo "Local path: $LOCAL_PATH"
echo ""

# ---------------------------------------------------------------------------
# 1. GitHub labels
# ---------------------------------------------------------------------------
echo "[1/3] Creating GitHub labels in $REPO..."

create_label() {
  local name="$1" color="$2" description="$3"
  if gh label list --repo "$REPO" --json name --jq '.[].name' 2>/dev/null | grep -qxF "$name"; then
    echo "  skip  $name (already exists)"
  else
    gh label create "$name" \
      --repo "$REPO" \
      --color "$color" \
      --description "$description" 2>/dev/null \
      && echo "  OK    $name" \
      || echo "  WARN  $name (create failed, check permissions)"
  fi
}

# kind -- blue family
create_label "kind:spec"        "0075ca" "Specification document"
create_label "kind:workpackage" "0052cc" "Vertical-slice work unit for Worker"

# status -- lifecycle progression
create_label "status:proposed"    "e4e669" "Draft created, awaiting confirmation"
create_label "status:approved"    "0e8a16" "Approved, ready for next agent"
create_label "status:in-progress" "f9d0c4" "Agent is actively working"
create_label "status:blocked"     "b60205" "Waiting on human input"
create_label "status:delivered"   "6f42c1" "Work delivered, in validation"
create_label "status:validated"   "0e8a16" "All validators passed"
create_label "status:done"        "006b75" "Merged and closed"
create_label "status:cancelled"   "e4e669" "Cancelled"

# agent routing -- teal family
create_label "agent:hermes-intake"      "00aabb" "Assigned to Hermes intake skill"
create_label "agent:hermes-design"      "00aabb" "Assigned to Hermes design skill"
create_label "agent:worker"             "00aabb" "Assigned to Worker"
create_label "agent:validator"          "00aabb" "Assigned to WhiteBox Validator"
create_label "agent:blackbox-validator" "00aabb" "Assigned to BlackBox Validator"
create_label "agent:arbiter"            "00aabb" "Assigned to Arbiter (recovery)"
create_label "agent:human-help"         "d93f0b" "Blocked -- needs human response"

# coordination
create_label "human-review"           "e99695" "PR ready for human merge"
create_label "awaiting-wp-completion" "c5def5" "Spec waiting for all WPs to complete"

echo ""

# ---------------------------------------------------------------------------
# 2. Update .workflow-repos.json
# ---------------------------------------------------------------------------
echo "[2/3] Updating .workflow-repos.json..."

REPOS_FILE="$SCRIPT_DIR/.workflow-repos.json"
printf '[{"repo":"%s","path":"%s"}]\n' "$REPO" "$LOCAL_PATH" > "$REPOS_FILE"
echo "  Wrote: $REPOS_FILE"
echo "  repo: $REPO  path: $LOCAL_PATH"
echo ""

# ---------------------------------------------------------------------------
# 3. Write ~/.hermes/agent-team.env
# ---------------------------------------------------------------------------
echo "[3/3] Writing ~/.hermes/agent-team.env..."

HERMES_ENV="$HOME/.hermes/agent-team.env"
cat > "$HERMES_ENV" <<EOF
# Written by init-target-repo.sh -- source this in Hermes skills that need
# to know the active agent-team target repo.
AGENT_TEAM_REPO="$REPO"
AGENT_TEAM_LOCAL_PATH="$LOCAL_PATH"
AGENT_TEAM_DIR="$SCRIPT_DIR"
EOF

echo "  Wrote: $HERMES_ENV"
echo ""

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------
echo "Done. Next steps:"
echo ""
echo "  1. Start sweet-home:"
echo "     cd ~/Projects/agent-sweet-home"
echo "     WORKFLOW_FILE=$SCRIPT_DIR/agent-team.workflow.yaml \\"
echo "         cargo run --manifest-path src-tauri/Cargo.toml --no-default-features"
echo ""
echo "  2. Open sweet-home Persistent tab, cwd = $SCRIPT_DIR"
echo "     Tell Claude: 'Run signal-to-spec -- I want to build a todo list app'"
