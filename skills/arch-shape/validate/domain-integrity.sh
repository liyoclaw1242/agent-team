#!/usr/bin/env bash
# domain-integrity.sh — verify arch-ddd consistency before delivery.
#
# Usage:
#   ARCH_DDD_DIR=/path/to/arch-ddd bash validate/domain-integrity.sh
#
# Default ARCH_DDD_DIR: ./arch-ddd
#
# Checks performed:
#   1. service-chain.mermaid is parseable mermaid
#   2. Every bounded context has at least one domain story (warning, not error)
#   3. README.md indices reference files that exist
#   4. glossary.md has no duplicate entries

set -euo pipefail

ARCH_DDD_DIR="${ARCH_DDD_DIR:-./arch-ddd}"

if [[ ! -d "$ARCH_DDD_DIR" ]]; then
  echo "warn: $ARCH_DDD_DIR does not exist (not a project repo?)"
  exit 0
fi

errors=0
warnings=0

# ─── 1. mermaid syntax ──────────────────────────────────────────────────────
chain_file="$ARCH_DDD_DIR/service-chain.mermaid"
if [[ -f "$chain_file" ]]; then
  if command -v mmdc >/dev/null; then
    if ! mmdc -i "$chain_file" -o /dev/null 2>/dev/null; then
      echo "✗ service-chain.mermaid has syntax errors"
      errors=$((errors + 1))
    fi
  else
    echo "warn: mmdc not installed; skipping mermaid syntax check"
    warnings=$((warnings + 1))
  fi
else
  echo "warn: service-chain.mermaid missing"
  warnings=$((warnings + 1))
fi

# ─── 2. each context has a story ────────────────────────────────────────────
ctx_dir="$ARCH_DDD_DIR/bounded-contexts"
story_dir="$ARCH_DDD_DIR/domain-stories"
if [[ -d "$ctx_dir" && -d "$story_dir" ]]; then
  ctx_count=$(find "$ctx_dir" -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l)
  story_count=$(find "$story_dir" -maxdepth 1 -name '*.md' ! -name 'README.md' | wc -l)
  if [[ "$ctx_count" -gt 0 && "$story_count" -eq 0 ]]; then
    echo "warn: $ctx_count bounded contexts but no domain stories"
    warnings=$((warnings + 1))
  fi
fi

# ─── 3. README indices ──────────────────────────────────────────────────────
for readme in \
    "$ARCH_DDD_DIR/README.md" \
    "$ARCH_DDD_DIR/bounded-contexts/README.md" \
    "$ARCH_DDD_DIR/domain-stories/README.md"; do
  [[ -f "$readme" ]] || continue
  # Extract markdown links to local .md files
  while IFS= read -r ref; do
    target="$(dirname "$readme")/$ref"
    if [[ ! -f "$target" ]]; then
      echo "✗ $readme references missing file: $ref"
      errors=$((errors + 1))
    fi
  done < <(grep -oP '\[[^]]+\]\(\K[^)]+\.md(?=\))' "$readme" | grep -v '^http')
done

# ─── 4. glossary duplicates ─────────────────────────────────────────────────
glossary="$ARCH_DDD_DIR/glossary.md"
if [[ -f "$glossary" ]]; then
  dups=$(grep -oP '^\*\*\K[^*]+(?=\*\*)' "$glossary" | sort | uniq -d || true)
  if [[ -n "$dups" ]]; then
    echo "✗ glossary has duplicate term entries:"
    echo "$dups" | sed 's/^/  - /'
    errors=$((errors + 1))
  fi
fi

# ─── Summary ────────────────────────────────────────────────────────────────
echo ""
echo "domain-integrity: $errors error(s), $warnings warning(s)"
[[ $errors -eq 0 ]] && exit 0 || exit 1
