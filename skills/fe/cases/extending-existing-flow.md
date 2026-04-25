# Case — Extending an Existing Flow

The spec asks for a feature on a page or component that already exists. Most FE tasks are this shape — pure greenfield is rare in mature codebases.

## Example

Task #144:

```markdown
[FE] Add "Cancel subscription" capability to /billing page

## Acceptance criteria
- Existing subscription card on /billing gets a new "Cancel" button
- Clicking opens the cancellation modal (#142 has design)
- Modal flows: confirmation, API call, success/failure UX
```

## Phase 1: read the existing surface

Before adding anything, fully understand what's there:

```bash
# Find the page
ls src/pages/billing/
# Read the main page
cat src/pages/billing/index.tsx

# Find the subscription card
grep -r "subscription card\|<SubscriptionCard" src/
```

Note:
- Where is this rendered? Top of page, in a list, conditional?
- What state does it depend on? Subscription status, plan tier, role?
- What other actions does it currently support? Upgrade, change plan?
- How are existing actions wired? Click handler, hook, modal portal?

## Phase 2: plan additions, not replacements

The temptation: "I'll refactor the card while I'm in here." Resist. Your task is "add cancel"; refactoring is a separate intake.

Plan the minimum viable addition:

- A new button next to (or below) existing actions
- New click handler that opens the cancellation modal
- The modal is its own component (per Design spec from #142)
- Existing card props don't change unless necessary

Rough plan:

```
src/pages/billing/index.tsx                     no changes (card composes itself)
src/components/SubscriptionCard.tsx             add a "Cancel" button + click handler
src/components/CancelConfirmationModal.tsx      NEW
src/lib/api/billing.ts                          add cancelSubscription()
```

## Phase 3: implement minimally

The pattern is: change as little as possible to existing code, add new code where needed.

```tsx
// src/components/SubscriptionCard.tsx — small addition
export function SubscriptionCard({ subscription }: Props) {
  const [showCancelModal, setShowCancelModal] = useState(false);

  return (
    <Card>
      {/* existing content unchanged */}
      <ActionRow>
        {/* existing action buttons unchanged */}
        <Button variant="secondary" onClick={() => setShowCancelModal(true)}>
          Cancel subscription
        </Button>
      </ActionRow>

      {showCancelModal && (
        <CancelConfirmationModal
          subscription={subscription}
          onClose={() => setShowCancelModal(false)}
          onSuccess={() => {
            setShowCancelModal(false);
            // existing parent refresh hook
          }}
        />
      )}
    </Card>
  );
}
```

The diff in `SubscriptionCard.tsx` is small: one button, one state hook, one conditional render. Everything else of the card is untouched.

## Phase 4: notice when "minimal" isn't possible

Sometimes the existing surface needs adjustment to accommodate the addition. Common cases:

### Case: ActionRow doesn't have room

The button row already has 4 buttons; adding a 5th breaks layout. Two options:

1. **Adjust the layout to fit** — small CSS tweak, fine if it doesn't affect the visual hierarchy
2. **Mode C if it requires bigger changes** — "Design spec doesn't account for layout overflow when 5+ actions exist"

### Case: existing component doesn't expose hooks you need

`SubscriptionCard` doesn't accept an `onCancel` prop and inverts control of all actions. Modifying it has wide blast radius.

This is genuine **scope expansion** — you can't add cancellation cleanly without refactoring the card's prop API.

```markdown
## Technical Feedback from fe

### Concern category
spec-scope

### What the spec says
"Add Cancel button to existing SubscriptionCard"

### What the codebase shows
SubscriptionCard owns all its action handlers internally; it doesn't
accept action callbacks via props. Adding cancellation as the spec asks
requires either:
- Refactoring SubscriptionCard to accept an onCancel prop (touches 6 call sites)
- Hardcoding the cancellation logic inside SubscriptionCard (cancels separation of concerns)

### Options I see
1. Refactor SubscriptionCard prop API (separate task; this task waits)
2. Inline the cancellation handling inside SubscriptionCard (scope creep)
3. Wrap SubscriptionCard with a higher-order component

### My preference
Option 1. The refactor is small (6 call sites) and isolated; better
done as its own task than mixed into a feature task.
```

This is the "implement first, scope-creep later" anti-pattern in action — flagging it is the right call.

## Phase 5: self-test calls out non-regression

When you extend an existing flow, the self-test must verify you didn't break anything that already worked:

```markdown
- [x] AC: Cancel button appears in SubscriptionCard
  - Verified: subscription card now shows Cancel below existing actions
- [x] AC: existing Upgrade button still functional
  - Verified: clicked Upgrade flow end-to-end; no regression
- [x] AC: existing Change Plan button still functional
  - Verified: clicked Change Plan flow; no regression
- [x] AC: card layout unchanged for plans without cancellation
  - Verified: viewed a free-plan card; no Cancel button shown (per spec; cancellation only applies to paid)
- [x] AC: a11y not regressed
  - Verified: tab order through card includes Cancel correctly; axe scan still 0 issues
```

The non-regression checks are crucial because you've modified an existing component. New isolated components are easier to verify; mods to shared components require explicit non-regression.

## Anti-patterns

- **Refactoring while you're in there** — separate intake. Even a 10-line cleanup belongs in its own PR for reviewability.
- **Skipping non-regression self-tests** — "the existing buttons probably still work" — usually true, occasionally not. Verify.
- **Modifying styles globally to fix layout** — global style changes need separate review; don't bury them in a feature PR.
- **Making the addition the new dominant action** — Design spec usually preserves visual hierarchy; if your addition becomes the most prominent button, double-check spec.
