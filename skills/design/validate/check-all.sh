#!/bin/bash
# Design validation — checklist gate
# Unlike BE/FE, design quality can't be grep'd.
# This script prints the mandatory checklists the agent MUST review
# and self-confirm before delivery.
#
# Usage: check-all.sh [mode]
#   mode: "spec" (default) | "review"
set -e

MODE="${1:-spec}"

echo "═══ Design Validation Gate ═══"
echo ""
echo "Before delivering, confirm EVERY item below."
echo "If any item fails, fix it before proceeding."
echo ""

# ── Always run ──

cat << 'CHECKLIST'
── AI Design Audit (rules/ai-design-audit.md) ──
- [ ] Max 2 font families
- [ ] Heading/body font-weight contrast exists
- [ ] No low-contrast gray text (min 4.5:1)
- [ ] No pure black backgrounds (use gray-950/zinc-950)
- [ ] Color hierarchy: primary > secondary > ghost
- [ ] Left-aligned text (not center-everything)
- [ ] No card-in-card-in-card (max 2 nesting levels)
- [ ] Buttons 36-38px height, not oversized
- [ ] All component states present (loading, error, empty, disabled)
- [ ] Ring borders preferred over solid gray
- [ ] Subtle shadows (shadow-sm, not shadow-xl)
- [ ] Realistic sample data (no Lorem ipsum)

── Accessibility (rules/accessibility.md) ──
- [ ] Semantic HTML (<button> not <div onClick>)
- [ ] All interactive elements have accessible names
- [ ] Visible focus indicators
- [ ] WCAG AA contrast (4.5:1 text, 3:1 large)
- [ ] Keyboard navigation works
- [ ] Images have alt text, forms have labels

── Responsive (rules/responsive.md) ──
- [ ] Mobile (320px) — layout stacks, content readable
- [ ] Tablet (768px) — layout adapts, no horizontal scroll
- [ ] Desktop (1280px) — uses space well, not just stretched mobile

── Screenshots Captured ──
- [ ] Captured at 3 breakpoints (mobile/tablet/desktop)
- [ ] Visually reviewed each screenshot
CHECKLIST

if [ "$MODE" = "spec" ]; then
cat << 'SPEC_CHECKLIST'

── Design Spec-Specific ──
- [ ] Layout structure clearly described
- [ ] Typography hierarchy specified (heading levels, sizes, weights)
- [ ] Color tokens specified (not raw hex values)
- [ ] All component states described (loading, error, empty, interactive)
- [ ] Responsive behavior described for 3 breakpoints
- [ ] Accessibility requirements noted (keyboard flow, ARIA)
- [ ] Backend data needs flagged (if design requires new API fields)
- [ ] Sketch exported and attached
SPEC_CHECKLIST
fi

if [ "$MODE" = "review" ]; then
cat << 'REVIEW_CHECKLIST'

── Visual Review-Specific ──
- [ ] First-impression test passed (eye goes to primary content)
- [ ] Consistent with rest of app (no one-off styling)
- [ ] Before vs after comparison done
- [ ] Mobile vs desktop both feel intentional
- [ ] Severity classified (block / major / minor / nitpick)
- [ ] Corrective Pencil sketch created (if rejecting)
REVIEW_CHECKLIST
fi

echo ""
echo "── Git (rules/git.md) ──"
echo "- [ ] .pen file committed to design/ directory (if Mode A)"
echo ""
echo "═══ Review every item. Fix failures. Then deliver. ═══"
