#!/bin/bash
# Design validation — checklist gate
# Unlike BE/FE, design quality can't be grep'd.
# This script prints the mandatory checklists the agent MUST review
# and self-confirm before delivery.
#
# Usage: check-all.sh [mode]
#   mode: "implement" (default) | "review"
set -e

MODE="${1:-implement}"

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

if [ "$MODE" = "implement" ]; then
cat << 'IMPLEMENT_CHECKLIST'

── Implementation-Specific ──
- [ ] Matches design sketch / Pencil output (if Mode A)
- [ ] Spacing follows 4px grid (4/8/12/16/24/32/48)
- [ ] Typography hierarchy is clear (display > h1 > h2 > body > caption)
- [ ] Interactive elements have hover/focus/active states
- [ ] Transitions under 300ms
- [ ] No dead code or unused imports
- [ ] design-decisions.md updated (if applicable)
IMPLEMENT_CHECKLIST
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
echo "── Code Quality (rules/code-quality.md) ──"
echo "- [ ] No console.log in production code"
echo "- [ ] No TODO without issue number"
echo "- [ ] Follows existing code style"
echo ""
echo "── Git (rules/git.md) ──"
echo "- [ ] Branch follows agent/{ID}/issue-{N} pattern"
echo "- [ ] Commit message follows {prefix}: {description} (closes #{N})"
echo ""
echo "═══ Review every item. Fix failures. Then deliver. ═══"
