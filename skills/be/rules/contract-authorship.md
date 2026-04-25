# Rule — Contract Authorship

BE owns API contracts. When BE publishes a contract on an issue, it becomes binding for both BE (must implement as written) and FE (must consume as written).

## Why BE owns contracts

Three reasons:

1. **BE has the implementation reality** — BE knows what the database supports, what the existing handlers expose, what shapes are easy or hard
2. **BE controls server-side concerns** — auth, validation, rate limits — that FE needs to know about
3. **One owner is better than two** — distributed contract ownership leads to drift; a single owner produces consistency

This doesn't mean FE is voiceless. FE can request changes via Mode C, propose alternatives, push back. But the act of publishing — making the contract official — is BE's.

## What "publishing" means

The contract goes into the **BE issue body** in a designated block. The block format:

```markdown
## Contract (defined by BE, consumed by FE)

{the contract details}
```

The `actions/publish-contract.sh` script writes this block atomically (idempotent — re-running updates rather than duplicating).

Once the block is in the issue body and FE has the issue as a `<!-- deps: -->`, the contract is **binding**. Changes route through arch-feedback, not unilateral edits.

## When to publish

Publish in `workflow/implement.md` Phase 2 — **before** writing implementation code. Specifically:

- After Phase 1 reading
- After confirming spec aligns with codebase (no need for Mode C)
- Before any `feat(...)` commit

This unblocks FE: they can read your contract and start their work in parallel with yours.

If you wait until after implementation to publish, FE has been blocked the entire time. The system's parallelism is wasted.

## What goes in the contract

Required:

- **Path**: `POST /billing/subscriptions/{id}/cancel` — exact path with parameter conventions
- **Auth**: who can call this; what auth method (cookie, bearer token, mTLS); what authorization (resource ownership, role check)
- **Request body**: shape, required vs optional fields, validation rules
- **Success response**: status code (usually 200 or 201), body shape with field names and types
- **Error responses**: status codes the client should distinguish; error body shape; what triggers each
- **Side effects**: events published, async actions taken, downstream effects FE should know about

Optional but often useful:

- **Idempotency**: is this safe to retry? what's the idempotency key?
- **Rate limits**: per-user, per-IP, per-endpoint
- **Versioning**: which API version this contract is for

The structure should look like the example in `cases/authoring-api-contract.md`.

## What does NOT go in the contract

- **Implementation details**: handler file path, library used, etc. Those live in the code, not the contract.
- **FE consumption details**: how FE will display or handle the response. That's FE's concern.
- **Internal-service contracts**: this block is for FE-facing endpoints. Internal service-to-service calls have their own documentation (often in service-chain or per-context docs).

## Modifying a published contract

Once published and FE has the dep, the contract is no longer freely mutable. Modifications go through one of:

### Path 1: BE realised the contract was wrong before FE started

If FE hasn't claimed their dep task yet, you can revise the contract by re-running `publish-contract.sh` with the corrected file. Add a comment on the issue explaining the change.

### Path 2: FE has started; modifications are proposed

Post a comment proposing the change. If FE agrees, both update. If FE disagrees, that's a contract conflict — route via Mode C; arch-feedback decides.

### Path 3: BE realised after FE has shipped against the old contract

Then the contract is ALREADY in production and FE is running on it. Changes here are migrations:

- Additive (new optional field, new endpoint version): safe to ship; FE adopts at leisure
- Breaking (removed field, changed semantics): requires coordinated deprecation cycle; this is an architecture-mode intake

Don't unilaterally break a shipped contract.

## Auth + authorization in the contract

These are often the part where contracts go wrong. Be specific:

❌ vague:
> Auth: required

✅ specific:
> Auth: required (Bearer JWT). Authz: subscription must belong to the authenticated user — return 404 if not (do NOT return 403; we don't reveal whether other users' subscriptions exist).

The 404-vs-403 detail matters. Without it, an FE could surface "you don't have permission" UX, leaking that the resource exists. The contract codifies the correct semantics.

## Domain alignment in field names

Field names follow `arch-ddd/glossary.md`. If glossary says `effectiveDate`, your contract uses `effectiveDate`, not `effective_at` or `effectiveAt`.

Spec says one thing, glossary says another → use glossary, flag drift via Mode C.

## Self-test must verify contract conformance

Per `workflow/implement.md` Phase 6, the self-test record explicitly checks the contract:

```markdown
## Contract conformance
The published contract on this issue body matches:
- Path: POST /billing/subscriptions/{id}/cancel ✓
- Auth: Bearer JWT, validated in middleware ✓
- 200 + {effectiveDate: ISO8601} ✓
- 404 / 409 cases per spec ✓
```

Each line maps a contract item to evidence. The contract validator (`validate/contract.sh`) does an automated cross-check between the contract block and the actual handler.

## Anti-patterns

- **Publishing after implementation** — defeats parallelism; FE was blocked unnecessarily
- **Publishing a vague contract** — "returns the cancellation result" is not a contract; FE will ask 5 follow-up questions
- **Modifying the contract silently mid-implementation** — drift between BE PR and FE PR; review will catch but late
- **"I'll publish a draft contract and refine as I go"** — drafts vs final contracts must be marked. If the contract is in flux, FE shouldn't depend yet.
- **Treating internal service interfaces like FE-facing contracts** — internal interfaces are documented in service-chain.mermaid + bounded-context docs, not in this block.
