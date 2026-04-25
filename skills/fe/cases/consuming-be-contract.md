# Case — Consuming a BE Contract

The most common cross-role dependency. Your task has `<!-- deps: #BE -->`, the BE task body has the API contract, and your job is to wire the FE to consume it faithfully.

## Example

Your task #144:

```markdown
[FE] Cancellation confirmation modal

## Acceptance criteria
- Modal opens when user clicks Cancel button
- Modal shows current effective date (from API)
- On confirm: API call, success toast, parent refresh
- On dismiss: nothing happens
- Loading state during request
- Error state on failure

<!-- parent: #142 -->
<!-- deps: #143 -->
<!-- intake-kind: business -->
```

Sibling BE task #143:

```markdown
[BE] Cancellation endpoint

## Contract (defined by BE, consumed by FE)

POST /billing/subscriptions/{id}/cancel
- Auth: required (subscription must belong to authenticated user)
- Request body: empty
- Success: 200 {effectiveDate: ISO8601}
- Errors: 404 if subscription not found
          409 if already cancelled
```

## Phase 1: read carefully

Read both task bodies in full. Note:

- The contract uses `effectiveDate` (camelCase) — that's the field name you'll use everywhere
- Two distinct error cases: 404 vs 409
- Empty request body
- Auth is required (so the user must be logged in for this to work)

## Phase 2: reality check

Before implementing, verify:

- Is `#143` actually merged? If not, you'll be implementing against a contract that doesn't exist yet.
- Does this codebase have a pattern for authenticated mutations? `grep` for similar POST endpoints in `src/lib/api/`.
- Is there an existing modal primitive to reuse? Check `src/components/`.

If `#143` is not merged yet but the contract is documented, you can implement and unit-test against a mock. The PR will land before BE's though, so you'll need a feature flag or a contract test that runs against the deployed BE before merge.

The dep marker (`<!-- deps: #143 -->`) means your task is `status:blocked` until #143 closes. So normally you only pick this up after BE has merged. If you're picking it up earlier (deps was cleared optimistically), proceed but plan for verification on staging.

## Phase 3: implement faithfully

Wire the API call, treating the contract as authoritative:

```typescript
// src/lib/api/billing.ts
export async function cancelSubscription(id: string): Promise<{ effectiveDate: string }> {
  const res = await fetch(`/billing/subscriptions/${id}/cancel`, {
    method: 'POST',
    // Empty body per contract
    credentials: 'include', // auth via cookie
  });

  if (res.status === 404) {
    throw new SubscriptionNotFound(id);
  }
  if (res.status === 409) {
    throw new SubscriptionAlreadyCancelled(id);
  }
  if (!res.ok) {
    throw new ApiError(res.status, 'Cancellation failed');
  }

  return res.json(); // { effectiveDate: string }
}
```

Notes:
- Field name `effectiveDate` matches contract
- Error classes for 404 / 409 are distinct (UI can branch)
- Generic `ApiError` for unexpected statuses (network, 5xx)

The modal component consumes this:

```tsx
function CancelConfirmationModal({ subscriptionId, onSuccess, onClose }) {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const handleConfirm = async () => {
    setPending(true);
    setError(null);
    try {
      const { effectiveDate } = await cancelSubscription(subscriptionId);
      toast.success(`Cancelled. Effective ${formatDate(effectiveDate)}.`);
      onSuccess();
    } catch (e) {
      if (e instanceof SubscriptionAlreadyCancelled) {
        setError('This subscription is already cancelled.');
      } else if (e instanceof SubscriptionNotFound) {
        setError('Subscription not found.');
      } else {
        setError('Something went wrong. Please try again.');
      }
    } finally {
      setPending(false);
    }
  };

  // ...
}
```

## Phase 4: self-test against the contract

The self-test record specifically calls out contract conformance:

```markdown
- [x] AC: API call uses POST /billing/subscriptions/{id}/cancel
  - Verified: network tab confirms exact path; method=POST; body=empty
- [x] AC: success returns {effectiveDate: ISO8601}
  - Verified: with mock returning 200 + iso date, modal shows formatted date in toast
- [x] AC: 404 shows "not found" UI
  - Verified: mocked 404; observed error message
- [x] AC: 409 shows "already cancelled" UI
  - Verified: mocked 409; observed distinct error message
- [x] AC: loading state visible
  - Verified: artificial 1s network delay; spinner shows entire duration
```

## Anti-patterns specific to this case

- **Renaming `effectiveDate` to `effectiveAt` in your code** — domain alignment violation; contract said effectiveDate
- **Treating 404 and 409 as the same error** — contract distinguished them for a reason; UX should reflect
- **Sending a body when contract says empty** — silent contract violation; future BE refactors might tighten and your client breaks
- **Adding optimistic UI without spec saying so** — that's a UX decision; if Design didn't spec it, don't add it; if you think it should, file a separate enhancement issue

## When the contract is missing details

If during implementation you realise the contract didn't specify something you need (e.g., what's the response body shape on 409? Does it have an error message?), this is a `missing-AC` Mode C feedback case. Don't guess. Route back.
