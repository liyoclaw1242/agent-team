# Case — Architecture decision touching multiple contexts

The hard case. Almost always fails Gate 3. Brainstorm is mandatory.

## Example input

> **Problem**: Our session-based auth is causing pain — mobile apps can't easily refresh tokens, and we want to support API tokens for partners.
> **Alternatives considered**: stay with sessions + add API key system; migrate to JWT; OAuth2 with our own server.
> **Reversibility**: One-way (migrating users back from JWT is painful).

## What changes

Bounded contexts likely affected: **Identity**, **API Gateway**, every consumer context that reads identity.

Service chain likely affected: how the auth check happens for every inbound request.

Domain artefacts likely affected: glossary entries for "session", "token", "api key", "identity"; service-chain.mermaid auth-flow section.

## Brainstorm consultations to open

| Advisor | Ask about |
|---------|-----------|
| `be-advisor` (each affected service) | Where each service currently checks auth; what changing the check would touch |
| `fe-advisor` | Web-side: how cookies/tokens are currently stored and refreshed; mobile if applicable |
| `ops-advisor` | Token signing infra, key rotation, blue-green rollout strategy |
| `design-advisor` | Login UX changes (probably none for back-end auth swap, but ask) |

## Synthesise into ADR

After advisors return, the ADR captures:

- The decision: e.g., "Migrate to JWT issued by an in-house auth service; keep sessions for the legacy admin tool"
- Why this beats "stay with sessions": advisor input on partner API key UX
- Why this beats OAuth2: advisor input on cost of running our own OAuth2 server
- Reversibility: one-way for the JWT path, but with a co-existence period of N months where both work
- Implementation tasks (8–12 typical for an auth migration)

## Decomposition shape

Auth migrations typically look like:

```
[Design] (skip — no UX change for users, but verify with design-advisor)
[BE] Auth service: JWT issuance + verification
[BE] (per service) Switch verification middleware to call new auth service
[FE] Switch token storage from cookie to memory + refresh token
[OPS] Deploy auth service, key rotation runbook
[OPS] Co-existence period config: both paths active
[OPS] Cutover plan: deprecate session path
[QA] Migration verification test plan
[QA] Rollback verification (re-enable session path during co-existence)
```

Note the **co-existence period** — this is what makes a one-way decision reversible-ish for some time. Architecture mode should always ask: "if this is one-way, is there a window where both work?"

## Deps and ordering

```
auth-svc-impl (#201)
  ↓ deps
service-A-migrate (#202)  ← parallel
service-B-migrate (#203)  ← parallel
service-C-migrate (#204)  ← parallel
  ↓ deps (all of A, B, C)
fe-token-rotation (#205)
  ↓ deps
ops-cutover-plan (#206)
qa-migration-test (#207)
qa-rollback-test (#208)
```

`scan-unblock.sh` handles the cascade as merges happen.

## Anti-pattern: forgetting co-existence

An ADR that says "switch to JWT" without specifying co-existence forces a big-bang deploy. Big-bang auth migrations break partners.

The architecture mode workflow's Phase 4 (Reversibility) is where this gets caught — write the section explicitly.
