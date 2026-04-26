# Pattern — Modals and Overlays

UI elements that appear above other content. Modals, dialogs, popovers, tooltips, sheets, drawers. The most over-used family of patterns; often the wrong choice.

## When to overlay (and when not)

Overlays interrupt the user's flow. Use them when:

- The action is **focused** (single task, can't continue without it)
- The action is **temporary** (won't be revisited; not a primary surface)
- The decision **depends on showing other content** (preview-while-deciding)

Don't use them when:

- The action is part of a longer workflow (use a separate page)
- The user might want to reference the underlying content while completing it (use a sheet or panel instead)
- There's any plausible alternative (inline forms, dedicated pages, expandable sections all preserve context better)

The default should be inline UI, not modals. Modals are escape hatches.

## Modal dialogs

A floating box that interrupts to demand attention.

### Anatomy

```
        ┌───────────────────────────┐
        │ Title                  [X]│
        ├───────────────────────────┤
        │                           │
        │  Content / form / message │
        │                           │
        ├───────────────────────────┤
        │       [Cancel]  [Confirm] │
        └───────────────────────────┘
        
        (background behind dimmed)
```

Required elements:
- Title (heading; what is this dialog for)
- Close affordance (X in top right, plus Escape key)
- Content area
- Action area (typically: Cancel + primary action)
- Backdrop (dimming the rest of the page)

### Sizing

- **Small**: ~360-480px wide; for confirmations, alerts, simple forms
- **Medium**: ~560-720px wide; for moderate forms, multi-field inputs
- **Large**: ~800-1000px wide; for complex forms, multi-step content
- **Full-screen mobile**: 100vw on phone (modal becomes a temporary page)

Don't use medium / large modals on mobile — they cramp at small viewports.

### When to use

- Confirmations of destructive actions
- Brief forms (sign up modal on a marketing page)
- Image / video lightboxes
- Simple selectors (date picker, color picker — though popover is often better)

### When NOT to use

- Forms that need >7 fields (use a page)
- Multi-step flows (use a wizard page)
- Anything users may want to reference alongside other content (use a side sheet or panel)

### Accessibility (critical for modals)

- **Focus trap**: Tab cycles within the modal; doesn't escape to background
- **Focus on open**: focus moves to the first interactive element (or the modal container with `tabindex="-1"`)
- **Focus on close**: focus returns to the trigger element
- **Escape key closes**: with confirmation if data would be lost
- **Backdrop click**: closes (or with confirmation for forms)
- **Screen readers**: `role="dialog"` with `aria-labelledby` pointing to the title
- **Announcement**: `aria-modal="true"` so screen readers know background is inert

```html
<div role="dialog" aria-modal="true" aria-labelledby="modal-title">
  <h2 id="modal-title">Confirm deletion</h2>
  ...
</div>
```

### Spec must include

- Width / max-width per breakpoint
- Backdrop style (color, opacity)
- Open / close transitions (typically 150-200ms fade + scale)
- Focus management (where focus goes on open / close)
- Escape key behavior (close immediately or confirm-first)
- Close X position and styling
- Action button order (Cancel left, primary right is platform-conventional)

## Sheets / drawers

Modal content sliding in from an edge of the screen (right, bottom, sometimes left).

### When to use

- **Side sheets**: detail panels alongside main content; user can reference both
- **Bottom sheets** (mobile): action lists, filter selectors; finger-friendly
- **Drawers** (left, mobile): nav menus from hamburger

### Anatomy

Side sheet:
```
┌──────────────────────────┬──────────────┐
│                          │ Detail title │
│                          │              │
│  main content (still     │  detail      │
│  visible behind)         │  content     │
│                          │              │
│                          │  [Close]     │
└──────────────────────────┴──────────────┘
```

Bottom sheet:
```
┌────────────────────────────────────────┐
│                                        │
│         main content                   │
│                                        │
├────────────────────────────────────────┤
│ ━━━                                    │  ← drag handle
│ Sheet title                            │
│ • Option 1                             │
│ • Option 2                             │
│ • Option 3                             │
└────────────────────────────────────────┘
```

### When sheets > modals

When the user benefits from seeing both:
- Detail view of a row in a table → side sheet (table behind)
- Filters / sort options → side sheet or bottom sheet (results visible behind)
- Mobile menus → drawer

### Accessibility

Same focus / aria patterns as modals. Sheets often have a drag-to-dismiss affordance — provide a close button + escape too.

## Popovers

Small floating element anchored to a trigger.

### Anatomy

```
              [Trigger]
                  ↓
         ┌──────────────────┐
         │  Popover content │
         └──────────────────┘
```

### When to use

- Action menus (right-click style or three-dot menus)
- Date / time / color pickers
- Helpful contextual UI (settings for an item, options for a row)
- Rich tooltips with interactive content

### Versus tooltips

- **Tooltip**: appears on hover/focus, shows brief read-only info, dismisses on leave
- **Popover**: appears on click, can contain interactive content, persists until dismissed

Popovers are clicked; tooltips are hovered.

### Positioning

Anchor to the trigger, with logic for:

- **Preferred position** (e.g., below + centered)
- **Flip** if it would overflow (try above)
- **Shift** if it would clip horizontally (slide left/right)
- **Arrow / pointer** indicating which trigger it relates to

Use a positioning library (Floating UI, Popper) — don't roll your own positioning math.

### Accessibility

- `aria-haspopup="true"` on trigger
- `aria-expanded="true|false"` on trigger
- Popover content has `role="dialog"` (for complex popovers) or `role="menu"` (for action menus)
- Focus management: clicking trigger opens AND moves focus into popover

## Tooltips

Brief on-hover/focus info.

### When to use

- Icon-only buttons (label what they do)
- Truncated text (full text on hover)
- Disabled controls (explain why disabled)
- Brief contextual help

### When NOT to use

- Critical information (hiding info behind hover means mobile users miss it)
- Long content (a tooltip with paragraphs is the wrong shape)
- Anything users need to act on (interactive content needs popover, not tooltip)

### Behavior

- Appear on hover or keyboard focus (not click)
- Delay before showing (~500-700ms; avoid flicker)
- No delay before hiding
- Disappear on mouse leave or focus loss

### Mobile

Tooltips don't work on touch. Either:
- Disable tooltips on touch devices (rely on labels and obvious affordances)
- Show on long-press
- Keep the info visible for important content (don't hide it in tooltip)

### Accessibility

- `aria-describedby` from trigger to tooltip
- Tooltip has `role="tooltip"`
- Always available via keyboard focus (not hover-only)

## Common overlay mistakes

- **Modal for things that should be a page** — multi-field forms, settings, anything users might want to reference elsewhere
- **Modal stacked on modal** — never. The first modal should resolve before the second.
- **No focus trap** — keyboard user tabs into the background while modal is open
- **No focus return on close** — focus jumps to body; user is lost
- **Backdrop click closes form modal** — accidental click loses entered data
- **Tooltip with critical info** — mobile users have no way to see it
- **Popover that doesn't position smartly** — off-screen, clipped
- **Modal width inconsistent across product** — every modal a different size
- **Modal doesn't trap focus on iOS** — Safari focus behavior is different; test specifically
- **Sheets that don't slide back** — the close transition matters as much as open

## Spec must include

For any modal / overlay:
- Trigger (what causes it to appear)
- Position (anchored, centered, edge)
- Size at each breakpoint
- Open / close transitions
- Focus management (in / out)
- Escape / backdrop / close behavior
- Action area (buttons; their priority)
- ARIA structure
- Mobile behavior (full-screen? sheet? drawer?)

## Quick checklist

- [ ] Could this be inline / a page instead?
- [ ] Focus trap (Tab cycles within)
- [ ] Focus moves into modal on open
- [ ] Focus returns to trigger on close
- [ ] Escape closes
- [ ] `aria-modal="true"` and `aria-labelledby` set
- [ ] Backdrop dims background
- [ ] Action buttons: Cancel + primary; primary on the right
- [ ] Mobile behavior (sheet, full-screen, etc.)
- [ ] Open/close transitions short (150-200ms)
