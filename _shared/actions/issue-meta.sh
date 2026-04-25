#!/usr/bin/env bash
# issue-meta.sh — read and write hidden metadata stored as HTML comments in
# GitHub issue bodies.
#
# Why HTML comments: see LABEL_RULES.md "On HTML comment metadata".
#
# Usage:
#   issue-meta.sh get    <issue-number> <key>
#   issue-meta.sh set    <issue-number> <key> <value>
#   issue-meta.sh delete <issue-number> <key>
#   issue-meta.sh list   <issue-number>
#   issue-meta.sh debug  <issue-number>     # human-readable dump
#
# Required env:
#   REPO  — owner/repo
#
# Exit codes:
#   0  success
#   1  argument error
#   2  GitHub API error
#   3  key not found (get only)

set -euo pipefail

: "${REPO:?REPO must be set, e.g. owner/repo}"

usage() {
  sed -n '/^# Usage:/,/^$/p' "$0" | sed 's/^# \?//'
  exit 1
}

[[ $# -lt 2 ]] && usage

CMD="$1"
N="$2"

# ─── Helpers ────────────────────────────────────────────────────────────────

# Validate issue number is a positive integer.
[[ "$N" =~ ^[0-9]+$ ]] || { echo "issue number must be a positive integer" >&2; exit 1; }

read_body() {
  gh issue view "$N" --repo "$REPO" --json body --jq '.body // ""' \
    || { echo "failed to read issue #$N" >&2; exit 2; }
}

write_body() {
  local new_body="$1"
  # gh issue edit reads body from --body-file; piping --body has limits
  local tmp
  tmp=$(mktemp)
  printf '%s' "$new_body" > "$tmp"
  gh issue edit "$N" --repo "$REPO" --body-file "$tmp" >/dev/null \
    || { rm -f "$tmp"; echo "failed to update issue #$N" >&2; exit 2; }
  rm -f "$tmp"
}

# Extract a single metadata value by key.
# Pattern: <!-- key: value --> on its own logical line (whitespace-tolerant).
extract_value() {
  local body="$1" key="$2"
  echo "$body" | grep -oP "<!--\s*${key}:\s*\K[^>]*?(?=\s*-->)" | head -n1 | sed 's/[[:space:]]*$//'
}

# List all key: value pairs from HTML comments matching our schema.
# Lines look like: key: value
extract_all() {
  local body="$1"
  echo "$body" | grep -oP '<!--\s*\K[a-z][a-z0-9-]*:\s*[^>]*?(?=\s*-->)' \
    | sed -E 's/^([a-z0-9-]+):\s*/\1: /' \
    | sed 's/[[:space:]]*$//'
}

# Replace or insert a metadata line in body. Returns new body on stdout.
upsert_meta() {
  local body="$1" key="$2" value="$3"
  local marker="<!-- ${key}: ${value} -->"

  # If key exists, replace the line. Otherwise append.
  if echo "$body" | grep -qP "<!--\s*${key}:\s*[^>]*-->"; then
    # Use perl for in-place replacement that handles newlines properly.
    echo "$body" | perl -pe "s|<!--\\s*${key}:\\s*[^>]*-->|${marker}|"
  else
    # Append on its own line at the end, separated by blank line if body
    # doesn't already end with one.
    if [[ -n "$body" && "$body" != *$'\n\n' ]]; then
      printf '%s\n\n%s\n' "$body" "$marker"
    else
      printf '%s%s\n' "$body" "$marker"
    fi
  fi
}

# Delete a metadata line. Returns new body on stdout.
delete_meta() {
  local body="$1" key="$2"
  echo "$body" | perl -pe "s|<!--\\s*${key}:\\s*[^>]*-->\\n?||g" | sed -e '/^$/N;/^\n$/d'
}

# ─── Commands ───────────────────────────────────────────────────────────────

case "$CMD" in
  get)
    [[ $# -eq 3 ]] || usage
    KEY="$3"
    body=$(read_body)
    value=$(extract_value "$body" "$KEY")
    if [[ -z "$value" ]]; then
      exit 3
    fi
    echo "$value"
    ;;

  set)
    [[ $# -eq 4 ]] || usage
    KEY="$3"
    VALUE="$4"
    # Reject angle brackets in key/value to prevent injection
    if [[ "$KEY" == *"<"* || "$KEY" == *">"* || "$VALUE" == *"<"* || "$VALUE" == *">"* ]]; then
      echo "key/value cannot contain < or >" >&2; exit 1
    fi
    # Key naming: lowercase alphanumeric + hyphen
    if ! [[ "$KEY" =~ ^[a-z][a-z0-9-]*$ ]]; then
      echo "key must match ^[a-z][a-z0-9-]*$" >&2; exit 1
    fi
    body=$(read_body)
    new_body=$(upsert_meta "$body" "$KEY" "$VALUE")
    write_body "$new_body"
    ;;

  delete)
    [[ $# -eq 3 ]] || usage
    KEY="$3"
    body=$(read_body)
    new_body=$(delete_meta "$body" "$KEY")
    write_body "$new_body"
    ;;

  list)
    body=$(read_body)
    extract_all "$body"
    ;;

  debug)
    body=$(read_body)
    echo "── Issue #$N metadata ──"
    extract_all "$body" || echo "(no metadata)"
    echo ""
    echo "── Body length: $(echo "$body" | wc -c) bytes ──"
    ;;

  *)
    usage
    ;;
esac
