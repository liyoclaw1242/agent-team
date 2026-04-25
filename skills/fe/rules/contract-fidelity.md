# Rule — Contract Fidelity

When consuming a contract authored by another role (BE API, Design spec), implement it exactly as written. Deviations require Mode C, not silent improvisation.

## Two kinds of contracts FE consumes

### BE API contract

When a sibling task is `agent:be` and your task has `<!-- deps: #BE_TASK -->`, the BE task body contains the API contract:

```markdown
## Contract (defined by BE, consumed by FE)

POST /billing/subscriptions/{id}/cancel
- Auth: required (subscription must belong to authenticated user)
- Request body: empty
- Success: 200 {effectiveDate: ISO8601}
- Errors: 404 if not found, 409 if already cancelled
```

Your fetch / mutation / hook implements **exactly** this:

- Path matches: `/billing/subscriptions/${id}/cancel`
- Method matches: POST
- Request body matches: empty (don't send `{ confirm: true }` "to be safe")
- Response field name matches: `effectiveDate` (not `effectiveAt`, `cancelDate`, `at`)
- Error handling matches: 404 and 409 are distinct cases with distinct UX

### Design spec

When a sibling task is `agent:design` and the task delivered specs (Figma, Storybook, or markdown spec), implement those specs **pixel-and-pattern faithful**:

- Spacing values from the spec, not "looks about right"
- Colour tokens from the spec, not "approximately the same"
- States listed in the spec are all implemented (default, hover, focus, disabled, error, loading)
- Copy from the spec, character-for-character (including punctuation)

If a spec is ambiguous, **ask in Mode C**, don't guess.

## When the contract is wrong

You may discover a contract issue during implementation:

- BE contract field name conflicts with a reserved word
- Design spec doesn't account for a state that exists (e.g., spec shows happy path only, but the API returns a 409 case the spec doesn't show)
- Two contracts conflict with each other

**Do not work around it silently.** Switch to feedback path:

```markdown
## Technical Feedback from fe

### Concern category
contract-conflict

### What the contract says
BE contract from #143 specifies field `effectiveDate` but Design spec for
the modal references `cancellationDate`. They're the same concept; FE
needs them to align.

### What I see in code
Currently no client implementation of either; this is the first consumer.

### Options I see
1. Use BE's `effectiveDate` everywhere; update Design spec
2. Use Design's `cancellationDate` everywhere; update BE contract
3. Map them in FE (NOT recommended; introduces FE-specific translation)

### My preference
Option 1. BE is the contract owner per arch-shape's spec discipline; Design
should match BE field name in display/copy.
```

Route back to arch. arch-feedback decides which contract changes.

## Drift discipline

If you notice the BE PR (when it eventually lands) doesn't match the contract its task body documented, that's also Mode C territory: comment on the BE issue or its PR. Don't quietly patch your client to match the actual deployed shape.

## Why this rule exists

The system's correctness depends on contracts being honoured. If FE silently adapts to BE deviations:

- The contract document (in the BE issue body) becomes a lie
- Future readers won't know what the actual contract is
- The next FE consumer of the same endpoint will repeat the analysis from scratch
- BE may "fix" their endpoint to match the original contract someday, breaking the FE that adapted

Treating contracts as authoritative — even when they're inconvenient — is what keeps the system honest.

## Anti-patterns

- **"BE returns ID, but I'll call it cancelId in our code for clarity"** — adapter logic fragments knowledge. Use BE's name.
- **"Design said modal but I'll use a sheet because it's better mobile UX"** — file Mode C. If Design agrees, they update the spec; if not, you implement modal.
- **"The contract didn't say what to do on 500, so I'll show generic toast"** — flag the missing case in Mode C; don't invent UX.

## Subtle case: progressive enhancement

Sometimes you implement to spec exactly, but notice you can add UX value beyond the spec (subtle micro-interactions, improved loading state, etc.). This is OK if:

- The spec doesn't explicitly forbid it
- The enhancement doesn't change observable behaviour for the AC
- You note it in the PR description

Anything that changes contract-visible behaviour (timing, errors, states) is NOT progressive enhancement — it's deviation, route via Mode C.
