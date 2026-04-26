#!/usr/bin/env bash
# token-usage.sh — scan changed files for likely-hardcoded design values
# that should reference design tokens instead.
#
# Detects:
#  - Hardcoded hex colors (e.g., #3B82F6) in CSS/JSX/TSX (excluding test files)
#  - Off-scale spacing values (specific px values not on a recognized scale)
#
# Usage:
#   token-usage.sh [--diff-base BRANCH] [--root DIR]
#
# Exit codes:
#   0 clean (no findings)
#   1 arg error
#   2 findings present (warnings only — does not block; informational)

set -euo pipefail

DIFF_BASE="${DIFF_BASE:-origin/main}"
ROOT="${ROOT:-.}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff-base) DIFF_BASE="$2"; shift 2 ;;
    --root)      ROOT="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

cd "$ROOT"

# Get changed files (relative to diff base)
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "not in a git repo at $ROOT" >&2
  exit 1
fi

changed_files=$(git diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null \
  || git diff --name-only "$DIFF_BASE" 2>/dev/null \
  || echo "")

if [[ -z "$changed_files" ]]; then
  echo "result: PASS (no changed files)"
  exit 0
fi

# Filter to relevant file types and exclude tests / mocks
relevant=$(echo "$changed_files" | grep -E '\.(css|scss|less|tsx|jsx|ts|js|vue|svelte|html)$' | \
  grep -vE '(\.test\.|\.spec\.|__tests__|__mocks__|/test/|/tests/|/mocks/)' || true)

if [[ -z "$relevant" ]]; then
  echo "result: PASS (no relevant files changed)"
  exit 0
fi

findings=0

# Check 1: hardcoded hex colors
# Match #RGB, #RRGGBB, #RRGGBBAA — but allow inside SVG <path>, comments,
# and explicitly-allowed contexts (logo files, brand assets)
echo "Scanning for hardcoded hex colors..."

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ ! -f "$file" ]] && continue
  
  # Skip likely brand-asset files
  case "$file" in
    *logo*|*brand-asset*|*illustration*|*favicon*) continue ;;
  esac
  
  # Find hex codes outside of comments
  matches=$(grep -nE '#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})\b' "$file" 2>/dev/null \
    | grep -vE '^\s*(//|#|\*)' \
    | grep -vE 'currentColor' \
    || true)
  
  if [[ -n "$matches" ]]; then
    echo "  $file: hardcoded hex color(s):"
    echo "$matches" | sed 's/^/    /' | head -n 10
    findings=$((findings + $(echo "$matches" | wc -l)))
  fi
done <<< "$relevant"

# Check 2: off-scale spacing in CSS files
# Common scale values (4px-based and 8px-based combined)
echo ""
echo "Scanning for off-scale spacing values..."

# Acceptable px values (4px-based scale): 0,1,2,4,8,12,16,20,24,32,40,48,64,80,96,128
# Plus border / line widths typically 1-3px
# Anything else with px in spacing properties is suspicious

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ ! -f "$file" ]] && continue
  case "$file" in
    *.css|*.scss|*.less) ;;
    *) continue ;;
  esac
  
  # Match spacing properties with px values
  matches=$(grep -nE '(padding|margin|gap|top|right|bottom|left|width|height|max-width|min-width):\s*[0-9]+px' "$file" 2>/dev/null \
    | grep -vE ':\s*(0|1|2|4|8|12|16|20|24|32|40|48|64|80|96|128|160|192|240|256|320|384|480|512|640|768|1024|1280|1440|1536)px' \
    || true)
  
  if [[ -n "$matches" ]]; then
    echo "  $file: off-scale spacing value(s):"
    echo "$matches" | sed 's/^/    /' | head -n 10
    findings=$((findings + $(echo "$matches" | wc -l)))
  fi
done <<< "$relevant"

# Check 3: explicit color values in JS/TS components (Tailwind users might
# accidentally use inline styles)
echo ""
echo "Scanning for inline-style hardcoded colors in components..."

while IFS= read -r file; do
  [[ -z "$file" ]] && continue
  [[ ! -f "$file" ]] && continue
  case "$file" in
    *.tsx|*.jsx|*.ts|*.js|*.vue|*.svelte) ;;
    *) continue ;;
  esac
  
  # Match style={{ color: '...' }} or style={{ background: '...' }} patterns
  matches=$(grep -nE "style=\{\{[^}]*(color|background|border|fill|stroke):\s*['\"]" "$file" 2>/dev/null \
    | grep -vE "['\"]currentColor['\"]" \
    | grep -vE "['\"]inherit['\"]" \
    | grep -vE "['\"]transparent['\"]" \
    || true)
  
  if [[ -n "$matches" ]]; then
    echo "  $file: inline-style color value(s):"
    echo "$matches" | sed 's/^/    /' | head -n 5
    findings=$((findings + $(echo "$matches" | wc -l)))
  fi
done <<< "$relevant"

echo ""
if [[ $findings -eq 0 ]]; then
  echo "result: PASS (clean)"
  exit 0
else
  echo "result: $findings finding(s) — review and consider tokens"
  exit 2
fi
