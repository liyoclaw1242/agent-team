# Rule — Spec Discipline

Tasks describe **what** to achieve, not **how** to implement. The implementing role is the local expert on "how"; over-prescribing implementation steals their judgment and produces worse outcomes.

## Allowed in a task spec

- Outcome: "Users can cancel a subscription with one click on the /billing page"
- Acceptance criteria: testable bullets
- Constraints: "Must not require a page reload" / "Cancel takes effect at end of current billing cycle"
- References to bounded context docs that govern the surface
- Explicit non-goals: "Refund handling is out of scope"
- API shape **only when it's a contract between two roles** (e.g. FE depends on BE delivering an endpoint with a specific shape — both tasks reference the same shape)

## Forbidden in a task spec

- File-level instructions ("modify `src/components/Cancel.tsx`")
- Library choices ("use React Query for the request")
- Algorithm choices ("debounce by 300ms")
- Internal naming ("call the function `handleCancel`")
- Test framework choices ("write a Jest test")

## Why this rule exists

When arch-shape over-specifies:
- **Implementer's local knowledge is wasted.** FE knows the codebase already has a similar pattern in `useStripeAction`; the spec said "use React Query" so they ignore that.
- **Mode C feedback rises.** Over-specified tasks are more likely to conflict with codebase reality, triggering pushback.
- **Spec drifts from code.** Implementation details written into specs become outdated the moment refactoring happens; the spec lies forever.

## When uncertainty creeps in

If you find yourself wanting to write "use approach X" because you're worried the implementer will pick wrong, that's a signal:

- Either ask via brainstorm (advisor consultation) before decomposing
- Or write the constraint as an outcome-level guard: "Must complete in ≤200ms p99" (the implementer can pick the implementation)
- Or explicitly ask in the AC ("Verify the interaction does not block the main UI thread")

## Inter-role contracts

Sometimes a task must specify shape because two roles depend on it. In this case:

1. Write the contract once
2. Reference it from both task bodies
3. Mark which role owns the contract definition (usually BE owns API shapes, Design owns UI specs)

Example:

```markdown
## Contract (defined by BE, consumed by FE)

POST /billing/subscriptions/{id}/cancel
- Auth: required (subscription must belong to authenticated user)
- Request body: empty
- Success: 200 {effectiveDate: ISO8601}
- Errors: 404 if not found, 409 if already cancelled
```

Both `agent:be` (#143) and `agent:fe` (#144) tasks reference this contract block. Changes to the contract are an arch-shape decision, not a unilateral one by either role.

## Self-check

Before each task is opened, scan the body for:
- File paths → remove unless an inter-role contract references them
- Function/class names → remove
- Library names → remove unless they're a constraint from above
- Implementation verbs ("debounce", "memoise", "polyfill") → reword as outcomes

If you removed >2 implementation details, the original spec was probably overstuffed. Re-read with fresh eyes.
