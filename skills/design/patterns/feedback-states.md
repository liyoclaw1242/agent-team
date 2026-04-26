# Pattern — Feedback States

Loading, empty, error, success, confirmation. The non-default states that determine whether a UI feels finished.

## Why these matter

The default state is what designers spend most time on. The other states are where users get stuck:

- **Loading**: "is anything happening?"
- **Empty**: "is this broken? where do I start?"
- **Error**: "what just went wrong? what now?"
- **Success**: "did it actually work?"
- **Confirmation**: "what am I about to do?"

Specs that omit these states ship with placeholder behaviour or none. The implementation feels rough; users hit dead-ends.

## Loading states

Three patterns by complexity:

### 1. Skeleton screens (preferred for content)

Placeholder shapes matching the eventual content. The page feels like it's filling in.

```
┌───────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓                  │  ← skeleton title
│                                   │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓     │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓             │  ← skeleton body
│                                   │
└───────────────────────────────────┘
```

Style:
- Subtle background tint (`--bg-secondary` or `--neutral-200`)
- Optional gentle pulse animation (1.5s ease-in-out alternate)
- Match the eventual content's shape (don't show 3 lines if content is 1 line)

Use for: page loads, list/table loads, card grid loads, image areas (before image arrives).

### 2. Spinner (for short / inline actions)

A circular spinner indicating "something is happening". Universal but generic.

Use for:
- Form submission loading state (replace button text with spinner)
- Inline "fetching more data" indicators
- Brief operations < 2 seconds where skeleton is overkill

Don't use for: page-level loads where skeletons are clearer.

### 3. Progress bar (for known-duration tasks)

A determinate or indeterminate bar.

- Determinate (showing % complete): for uploads, downloads, multi-step operations with measurable progress
- Indeterminate (animated, no specific %): for known-long operations without progress data

Don't use indeterminate for short operations — it implies "this might take a while".

### Avoiding spinner anxiety

A spinner that lives more than 5-10 seconds creates user anxiety. Mitigations:

- **Set expectations** — text alongside spinner: "Fetching your invoices…" or "This may take up to 30 seconds"
- **Show progress** — convert to progress bar if you have measurable progress
- **Optimistic UI** — assume the action will succeed; show success immediately; reconcile if it fails
- **Skeleton instead** — if showing layout helps the user understand "yes, content is coming"

## Empty states

When the data set is empty. Categories:

### True empty (new user / first use)

The user just signed up; they have no items.

Tell them:
- What this would normally show
- Why it's empty (it's because they're new)
- What to do next (CTA to create the first item)

```
[Friendly illustration]
You don't have any invoices yet
Create your first invoice to start getting paid.
[Create invoice]
```

### Filtered empty (some content exists, but filter excludes all)

The user applied a filter; results are empty.

Tell them:
- The filter is what's hiding content
- How to remove the filter

```
No invoices match "paid in last 7 days"
Try expanding the date range or clearing filters.
[Clear filters]
```

### Search empty

The user searched; nothing matched.

Tell them:
- Their search returned nothing
- Suggest variations (similar terms, broader search)

```
No results for "Acme Inc"
Try a shorter or different search term.
```

### Permanent empty (nothing should ever be here)

A view that's intentionally empty in this state (e.g., archived items, when nothing is archived).

Tell them:
- This area is meant to be empty in this state

```
You don't have any archived items.
```

Empty states are NOT failure states. Tone should be informational / encouraging, not apologetic.

### Common empty-state mistakes

- "No data" with nothing else — what is this view? what should I do?
- Generic image of a sad robot for everything — feels condescending
- Too verbose — paragraph of explanation; user just wants to act
- No CTA — even the most basic empty state benefits from a "Create item" button

## Error states

Two scopes: page-level errors and inline errors.

### Page-level errors

The page itself can't render. Examples: API failed, user lacks permission, resource doesn't exist.

Always include:
- **Brief explanation** — what went wrong, in user terms (no stack traces)
- **What to do** — retry, go back, contact support
- **Permission errors** are special — explain why they don't have access

```
[Error icon, restrained color]
We couldn't load your invoices.
This usually resolves itself in a moment.
[Try again]   [Contact support]
```

### Inline errors

Errors within a still-functioning page. Examples: form validation, partial fetch failures, action failed but other things work.

- Display in context (next to the failed thing)
- Don't take over the entire page
- Color: `--danger-500` for indicator (with icon and text — never color alone)

### 404 / not-found

A specific kind of error: the URL doesn't match anything.

- Friendly tone (not "ERROR 404")
- Useful navigation (link home, link to popular pages, search)
- Don't blame the user

```
This page can't be found
Maybe try the homepage or use search to find what you need.
[Go home]   [Search]
```

### Common error mistakes

- Showing technical error to users ("ECONNREFUSED 127.0.0.1:5432")
- Blaming the user ("You did something wrong")
- No retry option (errors usually deserve a retry button)
- No way to escape (no link home, no contact support)
- Same error treatment for transient and permanent errors

## Success states

After a user completes an action.

### Toast notifications

Most common pattern: a small message that appears, confirms, and dismisses.

```
┌───────────────────────────────┐
│ ✓ Invoice saved               │  ← appears for 3-4 seconds, fades
└───────────────────────────────┘
```

- Position: top-right or bottom-center (consistent across product)
- Duration: 3-4 seconds (longer for important messages; "Undo" toasts often 5-7 seconds)
- Auto-dismiss with optional manual dismiss (X button)
- Color: `--success-500` border or fill; never red/yellow for success

Toasts are appropriate for low-stakes successes (saved, copied, sent). Don't use for high-stakes (just deleted 1000 items — needs more substance).

### Inline success

For form-like operations: success message replaces the form briefly, or the form clears with a success indicator.

```
✓ Settings saved.
```

### Full-page success

For multi-step operations or important milestones: dedicated success page.

```
[Checkmark illustration]
Order placed!
We'll send a confirmation to your email.
Order #ABC-123-456
[Track your order]   [Continue shopping]
```

Use when: the action is significant; the user should pause and acknowledge.

### Common success mistakes

- Toast for everything (including significant actions that warrant more)
- No confirmation at all ("did it work? I clicked, the screen changed, but…")
- Success message that disappears too quickly to read
- Success state that doesn't differ visually from default ("Save" button still says "Save")

## Confirmation states

Before a destructive or significant action: ask the user to confirm.

### When to confirm

- Deletion (especially bulk or irreversible)
- Sending / publishing (irreversible visibility)
- Large transactions (high-cost, large quantities)
- Major state changes (cancel subscription, archive project)

### When NOT to confirm

- Reversible actions (undo via Cmd+Z or "Undo" toast is better than a confirm dialog)
- Frequent actions (saving) — friction outweighs benefit
- Actions where the consequence is contained (closing a modal that you can re-open)

### Format

Modal dialog typically:

```
[!] Delete invoice ABC-123-456?

This will permanently delete the invoice. This can't be undone.

[Cancel]                     [Delete]
       (default focus)        (destructive style)
```

Key elements:
- Specific about what's being acted on (invoice ABC-123-456, not just "this item")
- Honest about consequences ("can't be undone" if true)
- Button labels match the action ("Delete" not "OK" or "Confirm")
- Default focus on the safe option (Cancel)
- Destructive button styled distinctly (`--danger-500`)

### "Type to confirm"

For really destructive actions (deleting an account, dropping a database):

```
Type "delete production database" to confirm:
[                                    ]
```

The friction is the point.

### Common confirmation mistakes

- Confirming everything (button-press fatigue; people stop reading)
- Vague confirmation ("Are you sure?" — sure of what?)
- Buttons labeled OK / Cancel (what does OK do? confirm what?)
- No keyboard support (Escape doesn't cancel; Enter doesn't confirm)
- Default focus on the destructive button (one Enter press = data lost)

## Spec must include

For any UI that fetches or modifies data:

- [ ] Loading state (skeleton / spinner / progress)
- [ ] Empty state (with appropriate sub-categorization for the use case)
- [ ] Error state (page-level or inline)
- [ ] Success state (toast / inline / full-page)
- [ ] Confirmation (for destructive / significant actions)

For each state:
- Visual treatment
- Copy / messaging
- Available actions / CTAs
- Transitions in/out
- Accessibility (announcements, focus management)

## Quick checklist

- [ ] Skeleton screens for content fetches (not spinners)
- [ ] Empty states have CTA / next step
- [ ] Errors offer retry / recovery path
- [ ] Success acknowledged appropriately (toast vs inline vs page)
- [ ] Confirmations for destructive actions only; specific copy
- [ ] State transitions specified (how does one state become another)
- [ ] Screen reader announcements for state changes (aria-live)
