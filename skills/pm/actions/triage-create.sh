#!/bin/bash
# Create a decomposed issue on the bounty board with duplicate detection.
# PM calls this once per sub-issue when triaging/decomposing a request.
#
# Usage: triage-create.sh <API_URL> <REPO_SLUG> <TITLE> <AGENT_TYPE> [PRIORITY] [DEPENDS_ON]
#   AGENT_TYPE: fe, be, ops, arch, design, qa, debug, pm
#   PRIORITY:   low, medium, high (default: medium)
#   DEPENDS_ON: comma-separated issue numbers (e.g. "12,15")
#
# Exit 0 = created, 1 = duplicate found, 2 = API error
set -euo pipefail

API_URL="${1:?API_URL required}"
REPO_SLUG="${2:?REPO_SLUG required}"
TITLE="${3:?TITLE required}"
AGENT_TYPE="${4:?AGENT_TYPE required (fe/be/ops/arch/design/qa/debug/pm)}"
PRIORITY="${5:-medium}"
DEPENDS_ON="${6:-}"

echo "═══ PM: Triage — Create Issue ═══"
echo "Repo: ${REPO_SLUG}"
echo "Title: ${TITLE}"
echo "Type: ${AGENT_TYPE} | Priority: ${PRIORITY}"

# 1. Duplicate detection: search existing issues with similar title
EXISTING=$(curl -sf "${API_URL}/bounties?repo_slug=${REPO_SLUG}" || {
  echo "FAIL: Cannot reach ${API_URL}"; exit 2
})

# Normalize title for comparison (lowercase, strip punctuation)
NORM_TITLE=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | xargs)

DUPLICATE=$(echo "$EXISTING" | jq -r --arg norm "$NORM_TITLE" '
  .[] | select(
    (.title // "" | ascii_downcase | gsub("[^a-z0-9 ]"; "") | ltrimstr(" ") | rtrimstr(" ")) == $norm
  ) | "#\(.issue_number) (\(.status))"
' | head -1)

if [ -n "$DUPLICATE" ]; then
  echo "DUPLICATE: '${TITLE}' matches existing issue ${DUPLICATE}"
  echo "Skipping creation. Resolve manually if these are distinct tasks."
  exit 1
fi

# 2. Build payload
DEPS_JSON="[]"
if [ -n "$DEPENDS_ON" ]; then
  DEPS_JSON=$(echo "$DEPENDS_ON" | tr ',' '\n' | jq -R 'tonumber' | jq -s '.')
fi

PAYLOAD=$(jq -n \
  --arg repo "$REPO_SLUG" \
  --arg title "$TITLE" \
  --arg agent_type "$AGENT_TYPE" \
  --arg priority "$PRIORITY" \
  --argjson depends_on "$DEPS_JSON" \
  '{
    repo_slug: $repo,
    title: $title,
    agent_type: $agent_type,
    priority: $priority,
    status: "ready",
    depends_on: $depends_on
  }')

# 3. Create
echo "Creating issue..."
RESPONSE=$(curl -sf -X POST "${API_URL}/bounties" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" || {
  echo "FAIL: POST /bounties failed"; exit 2
})

ISSUE_N=$(echo "$RESPONSE" | jq -r '.issue_number // .id // "unknown"')
echo "CREATED: #${ISSUE_N} — ${TITLE} (${AGENT_TYPE}, ${PRIORITY})"

# 4. If depends_on is non-empty and the new issue should be blocked, set status
if [ "$DEPENDS_ON" != "" ]; then
  echo "Setting status to 'blocked' (has dependencies: ${DEPENDS_ON})"
  curl -sf -o /dev/null \
    -X PATCH "${API_URL}/bounties/${REPO_SLUG}/issues/${ISSUE_N}" \
    -H "Content-Type: application/json" \
    -d '{"status": "blocked"}' || echo "WARN: Could not set blocked status"
fi

echo "═══ Done ═══"
