# Case: Visual Review Heuristics

Learned patterns for Mode C (visual review). This file grows from review experience — each review teaches what to look for next.

---

## First Impression Test (2 seconds)

Open the screenshot. In 2 seconds:
1. **Where does your eye go first?** That should be the primary action/content
2. **Can you tell what this page is for?** If not, hierarchy is broken
3. **Does anything feel "off"?** Trust the gut reaction, then analyze why

---

## Common Issues by Category

### Layout Issues

| What you see | Root cause | Feedback to give |
|-------------|-----------|-----------------|
| Content hugging edges | Missing page padding | "Add `px-6 lg:px-8` to the page container" |
| Everything same width | No visual hierarchy | "Feature the primary content, use sidebar or smaller cards for secondary" |
| Huge gap then cramped area | Inconsistent spacing | "Use consistent spacing scale: 16/24/32/48px" |
| Mobile just squishes desktop | No responsive design | "Stack vertically on mobile, show key content first" |

### Typography Issues

| What you see | Root cause | Feedback to give |
|-------------|-----------|-----------------|
| Can't tell heading from body | No size/weight contrast | "Increase heading size or weight to create clear hierarchy" |
| Text feels crowded | Line-height too tight | "Body text needs `leading-relaxed` (1.625)" |
| Long lines hard to read | No max-width on text | "Add `max-w-prose` to text containers" |

### Color Issues

| What you see | Root cause | Feedback to give |
|-------------|-----------|-----------------|
| Can't find the primary action | Everything same visual weight | "Primary button should be solid fill, others should be outline/ghost" |
| Feels muddy/gray | Too many neutral tones | "Add one accent color for interactive elements" |
| Dark mode looks inverted | Just flipped colors | "Reduce contrast slightly, elevate cards above background" |

### Component Issues

| What you see | Root cause | Feedback to give |
|-------------|-----------|-----------------|
| Button doesn't look clickable | No visual affordance | "Add fill/border + hover state" |
| Input field blends into background | No border/ring | "Add `ring-1 ring-border` to input" |
| Cards feel flat | No elevation | "Add `shadow-sm` or `ring-1 ring-border` to cards" |
| Everything looks the same | No state variation | "Loading skeleton? Error state? Empty state?" |

---

## Review Comparison Technique

When reviewing a PR, compare:
1. **Before vs after** — did the change improve or regress visual quality?
2. **This page vs sibling pages** — is it consistent with the rest of the app?
3. **Mobile vs desktop** — does the responsive version feel intentional?

---

## Severity Guide

| Severity | Criteria | Action |
|----------|---------|--------|
| **Block** | Broken layout, unreadable text, inaccessible controls | Reject PR |
| **Major** | Wrong visual hierarchy, inconsistent with app, missing states | Reject with specific fixes |
| **Minor** | Suboptimal spacing, could-be-better hover states | Approve with suggestions |
| **Nitpick** | Preference-level (I'd use 24px not 20px) | Approve, mention as optional |

Only **Block** and **Major** should prevent merge.

---

*Add new heuristics after each review. What did you almost miss? What pattern keeps recurring?*
