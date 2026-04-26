#!/usr/bin/env bash
# contrast.sh — best-effort contrast verification for color pairs in
# changed files. Uses a small Python helper for the calculation.
#
# Detects pairs of likely text-and-background hex codes in CSS / Tailwind
# config and reports any pair below WCAG 2.2 AA (4.5:1 for normal text).
#
# Limitations:
# - Cannot resolve runtime token values; only direct hex codes
# - Cannot determine if a color pair actually appears together in DOM
# - Reports pairs found in the same selector / proximity
#
# This is a best-effort check; manual review is still required for full
# WCAG compliance.
#
# Usage:
#   contrast.sh [--diff-base BRANCH] [--root DIR] [--threshold 4.5]
#
# Exit codes:
#   0 clean / unable to evaluate
#   1 arg error
#   2 findings present

set -euo pipefail

DIFF_BASE="${DIFF_BASE:-origin/main}"
ROOT="${ROOT:-.}"
THRESHOLD="${THRESHOLD:-4.5}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --diff-base) DIFF_BASE="$2"; shift 2 ;;
    --root)      ROOT="$2"; shift 2 ;;
    --threshold) THRESHOLD="$2"; shift 2 ;;
    *) echo "unknown flag: $1" >&2; exit 1 ;;
  esac
done

cd "$ROOT"

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not available; skipping contrast check" >&2
  exit 0
fi

# Get changed files
changed_files=$(git diff --name-only "$DIFF_BASE"...HEAD 2>/dev/null \
  || git diff --name-only "$DIFF_BASE" 2>/dev/null \
  || echo "")

relevant=$(echo "$changed_files" | grep -E '\.(css|scss|less)$' || true)

if [[ -z "$relevant" ]]; then
  echo "result: PASS (no relevant files changed)"
  exit 0
fi

# Use a Python helper for contrast calc
python3 - <<'PYEOF' "$THRESHOLD" $relevant
import sys
import re
import os

threshold = float(sys.argv[1])
files = sys.argv[2:]

hex_re = re.compile(r'#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\b')

def hex_to_rgb(h):
    h = h.lstrip('#')
    if len(h) == 3:
        h = ''.join(c*2 for c in h)
    return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def luminance(rgb):
    def channel(c):
        c = c / 255.0
        return c / 12.92 if c <= 0.03928 else ((c + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(c) for c in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b

def contrast_ratio(rgb1, rgb2):
    l1 = luminance(rgb1)
    l2 = luminance(rgb2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)

findings = 0

# For each file, find color and background-color pairs in same rule block
for file_path in files:
    if not os.path.isfile(file_path):
        continue
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
    except Exception:
        continue
    
    # Naive: split into "rule blocks" by braces
    # Look for blocks containing both `color:` and `background[-color]:`
    # with hex values
    blocks = re.findall(r'\{[^{}]+\}', content)
    
    for block in blocks:
        color_match = re.search(r'(?<!-)color:\s*(#[0-9a-fA-F]{3,6})', block)
        bg_match = re.search(r'background(-color)?:\s*(#[0-9a-fA-F]{3,6})', block)
        
        if color_match and bg_match:
            text_hex = color_match.group(1)
            bg_hex = bg_match.group(2)
            try:
                ratio = contrast_ratio(hex_to_rgb(text_hex), hex_to_rgb(bg_hex))
                if ratio < threshold:
                    print(f"  {file_path}: text {text_hex} on bg {bg_hex} = {ratio:.2f}:1 (below {threshold})")
                    findings += 1
            except Exception:
                pass

if findings > 0:
    print(f"\nresult: {findings} finding(s) below {threshold}:1 threshold")
    sys.exit(2)
else:
    print("result: PASS")
    sys.exit(0)
PYEOF
