#!/usr/bin/env bash
# test-classify.sh — unit tests for dispatcher's classify() function.
# Pure local: no GitHub API calls. Stubs out helpers that need network.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DISPATCHER="$SCRIPT_DIR/../dispatcher.sh"

[[ -f "$DISPATCHER" ]] || { echo "FAIL: dispatcher.sh not found at $DISPATCHER"; exit 1; }

# Extract just classify() and its body-helpers (body_has_feedback, has_label).
TMP=$(mktemp); trap 'rm -f "$TMP"' EXIT
awk '
  /^body_has_feedback\(\)/,/^}/ { print; next }
  /^has_label\(\)/,/^}/         { print; next }
  /^classify\(\)/,/^}/          { print; next }
' "$DISPATCHER" > "$TMP"
# shellcheck disable=SC1090
source "$TMP"

# ─── Test runner ────────────────────────────────────────────────────────────
PASS=0; FAIL=0

assert() {
  local name="$1" labels="$2" body="$3" intake="$4" expected="$5"
  local actual
  actual=$(classify "$labels" "$body" "$intake")
  if [[ "$actual" == "$expected" ]]; then
    PASS=$((PASS + 1))
    printf "  ✓ %s\n" "$name"
  else
    FAIL=$((FAIL + 1))
    printf "  ✗ %s\n     expected: %s\n     got:      %s\n     labels:   %s\n     intake:   %s\n     body:     %s\n" \
      "$name" "$expected" "$actual" "$labels" "$intake" "${body:0:60}"
  fi
}

echo "Running classify() tests..."
echo ""

# Rule 0: feedback overrides everything
assert "feedback alone → arch-feedback" \
  "agent:arch source:human status:ready" \
  "Technical Feedback from fe-agent: spec issue" \
  "" \
  "arch-feedback"

assert "feedback overrides intake-kind:business" \
  "agent:arch source:human status:ready" \
  "blah blah\nTechnical Feedback from fe-agent" \
  "business" \
  "arch-feedback"

assert "feedback overrides intake-kind:qa-audit" \
  "agent:arch source:human status:ready" \
  "Technical Feedback from be-agent" \
  "qa-audit" \
  "arch-feedback"

# Rule 1: audits
assert "qa-audit → arch-audit" \
  "agent:arch source:human status:ready" \
  "" \
  "qa-audit" \
  "arch-audit"

assert "design-audit → arch-audit" \
  "agent:arch source:human status:ready" \
  "" \
  "design-audit" \
  "arch-audit"

# Rule 2: business
assert "business → arch-shape" \
  "agent:arch source:hermes status:ready" \
  "" \
  "business" \
  "arch-shape"

# Rule 3: architecture
assert "architecture → arch-shape" \
  "agent:arch source:human status:ready" \
  "" \
  "architecture" \
  "arch-shape"

# Rule 4: bug on agent:arch (anomaly) → judgment
assert "bug on agent:arch → arch-judgment" \
  "agent:arch source:human status:ready" \
  "" \
  "bug" \
  "arch-judgment"

# Rule 5: escape hatch
assert "no markers → arch-judgment" \
  "agent:arch source:human status:ready" \
  "Plain prose" \
  "" \
  "arch-judgment"

assert "unknown intake-kind → arch-judgment" \
  "agent:arch source:human status:ready" \
  "" \
  "rfc" \
  "arch-judgment"

# Edge: empty body, no intake-kind
assert "empty body, empty intake → arch-judgment" \
  "agent:arch source:human status:ready" \
  "" \
  "" \
  "arch-judgment"

# Edge: feedback wins even when intake-kind is bug (weird state, feedback first)
assert "feedback + bug → arch-feedback (feedback first)" \
  "agent:arch source:human status:ready" \
  "Technical Feedback from debug" \
  "bug" \
  "arch-feedback"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
