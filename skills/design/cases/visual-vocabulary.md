# Case: Visual Vocabulary

A growing reference of visual patterns, learned from past tasks and inspiration research. Design agents should READ this before every implementation task and CONTRIBUTE to it after.

---

## Spacing Systems

### 4px Base Grid
Everything aligns to a 4px grid. Common values:
- `4px` (1) — tight inline spacing
- `8px` (2) — between related elements
- `12px` (3) — between grouped elements
- `16px` (4) — section padding
- `24px` (6) — between sections
- `32px` (8) — major section gaps
- `48px` (12) — page-level breathing room

### Spacing Relationships
- Elements that are **related** should be **closer together** than elements that aren't
- The gap between a heading and its content should be **smaller** than the gap between two sections
- White space is not empty — it communicates hierarchy

---

## Color Relationships

### The 60-30-10 Rule
- **60%** — background/neutral (bg-background, bg-card)
- **30%** — secondary (text-muted-foreground, borders)
- **10%** — accent/primary (buttons, links, active states)

### Contrast Pairs
- Primary action: high contrast against background (solid fill)
- Secondary action: medium contrast (outline or ghost)
- Destructive: red family, but not raw red — use `destructive` token

### Dark Mode
Not "invert everything." Instead:
- Reduce contrast slightly (pure white text on pure black is harsh)
- Elevate surfaces with lighter shades (cards slightly lighter than background)
- Maintain the same visual hierarchy — what's prominent in light stays prominent in dark

---

## Typography Hierarchy

### Scale (use project tokens, these are principles)
- **Display**: 36-48px, tight tracking (-0.02em), for hero sections
- **H1**: 24-30px, tight tracking, for page titles
- **H2**: 18-22px, for section headings
- **H3**: 16px, semibold, for sub-sections
- **Body**: 14-16px, normal tracking, 1.5-1.6 line-height
- **Small/Caption**: 12px, muted color

### Eyebrow Pattern
Monospace or uppercase small text above a heading:
```
CATEGORY                          ← eyebrow: text-xs uppercase tracking-wider text-muted
Build Your Dashboard              ← heading: text-2xl font-semibold tracking-tight
Create custom widgets...          ← description: text-muted-foreground
```

---

## Container Patterns

### Card Hierarchy (3 levels)

```
Level 1 (primary):    bg-card rounded-xl ring-1 ring-border shadow-sm
Level 2 (nested):     bg-muted/50 rounded-lg ring-1 ring-border/50
Level 3 (inline):     bg-muted rounded-md p-2
```

### Ring vs Border
- **Ring** (`ring-1 ring-black/5`): subtle, composable, doesn't affect layout
- **Border** (`border border-gray-200`): heavier, adds 1px to layout
- Prefer ring for most cases. Use border only for dividers (`border-t`).

---

## Interaction Patterns

### Button Hierarchy
1. **Primary**: solid fill, high contrast → main action
2. **Secondary**: outline or ghost → alternative action
3. **Destructive**: red-toned → irreversible action
4. **Ghost**: transparent → subtle action (icon buttons, menus)

### Hover/Focus States
- Hover: subtle change (darken 10%, or add shadow)
- Focus: visible ring (`focus-visible:ring-2 ring-ring`)
- Active: slight scale (`active:scale-[0.98]`)
- Disabled: reduced opacity (0.5), no pointer events

### Transition Timing
- Color/opacity: `transition-colors duration-150`
- Transform: `transition-transform duration-150`
- Layout: `transition-all duration-200`
- Never > 300ms for UI feedback

---

## Layout Patterns

### Asymmetric > Centered
Centered layouts feel static. Prefer:
- Left-aligned text with right-aligned actions
- 2/3 + 1/3 content splits
- Featured item larger than siblings

### Dashboard Grid
```
┌──────────────────────────────────┐
│  Stats row (4 metric cards)      │
├────────────────────┬─────────────┤
│  Main chart        │  Side list  │
│  (2/3 width)       │  (1/3)      │
├────────────────────┴─────────────┤
│  Table (full width)              │
└──────────────────────────────────┘
```

### Settings Page
```
┌──────────┬───────────────────────┐
│  Nav     │  Content              │
│  (fixed) │  (scrollable)         │
│  tabs    │  form sections        │
│          │  with clear headings  │
└──────────┴───────────────────────┘
```

---

## Anti-Patterns (things that look wrong)

| Pattern | Problem | Fix |
|---------|---------|-----|
| Everything centered | No visual flow, eye wanders | Left-align text, asymmetric layout |
| Identical card grid | No hierarchy, feels like a spreadsheet | Feature one card, vary sizes |
| Solid gray borders everywhere | Looks dated, heavy | Ring technique with opacity |
| Too many font sizes | Chaotic | Stick to 4-5 sizes max |
| Padding too uniform | Feels boxy | Vary by content importance |
| Pure black text on white | Harsh | Use `text-foreground` (usually a soft dark) |

---

*This file grows over time. After each task, add new patterns you discovered or confirmed.*
