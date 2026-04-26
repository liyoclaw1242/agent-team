# Rule — Read-Only Discipline

be-advisor never modifies anything. Not code, not arch-ddd, not contracts, not schemas, not other issues, not the parent's body. The only writes are:

1. The advice comment on this consultation issue
2. The close action on this issue

That's it.

## Why this matters

arch-shape's brainstorm flow assumes advisors are independent observers. If be-advisor edits arch-ddd, modifies a contract, or runs a migration mid-consultation, the synthesis phase breaks — arch-shape would be reading state that the consultation itself contributed to.

The discipline:

- **No `git commit`** — even on a sandbox branch
- **No `gh issue edit`** on any issue — including this consultation
- **No `gh pr` operations** — there's no PR involved
- **No file writes to `arch-ddd/`** — drift gets reported, not fixed
- **No file writes to `contracts/` / `schemas/` / `proto/`** — proposing contract shapes goes in the advice comment as text
- **No DB migrations run** — never. Read schemas, don't touch them
- **No file writes to `_shared/`** — same reason
- **No setting labels** beyond what the role's actions explicitly do

## Backend-specific traps

### Trap 1: "Let me just propose the migration"

Tempting when the request clearly implies a schema change. Don't write SQL files. Put the proposed shape in the advice:

```markdown
### Suggested approach

- Add `last_seen_at TIMESTAMPTZ NULL` to the `users` table.
  - Migration would be backward-compatible (NULL allowed); existing
    rows get NULL until first activity-write event hits them.
  - Backfill optional; not strictly needed for the feature.
- New events table column or new table? Recommend new column on `users`
  (high cardinality of existing rows, value updated frequently).
```

Text. Not SQL files committed.

### Trap 2: "Let me update the OpenAPI spec / .proto file"

Same as trap 1. Propose the shape in advice, don't commit it. The implementer (`be`) will publish the contract via the `<!-- be-contract -->` block during their PR.

### Trap 3: "Let me fix the schema mismatch I noticed"

Drift between code and schema documentation goes under "Drift noticed". Don't fix it during the consultation.

### Trap 4: "Let me run a query to verify"

Read-only queries against a development database are usually fine if part of the codebase setup. Don't run anything against production. Don't run anything that mutates (no INSERT / UPDATE / DELETE / DDL). When in doubt, examine source files instead of databases.

## What "drift" means and why advisors don't fix it

If you notice arch-ddd doesn't match the code ("the bounded context says we have one payment provider; we actually have three"), that's drift. Report it under "Drift noticed":

```markdown
### Drift noticed
- arch-ddd/bounded-contexts/payments.md describes a single Stripe integration;
  codebase has Stripe (services/payments/stripe), Adyen (services/payments/adyen),
  and a legacy PayPal handler (services/payments/legacy/paypal).
  Last arch-ddd update: 2024-08-01. Adyen integration merged 2024-11-12.
```

arch-shape decides what to do — often: an arch-shape PR updating arch-ddd before further decomposition. Editing arch-ddd directly defeats arch-shape's ability to know about it.

## Branch hygiene

Don't create a branch for the consultation. There's no code to commit. Working files (notes, scratch SQL for examination) go in `/tmp/` and are deleted when the consultation closes.

If you accidentally created a branch, delete it after responding:

```bash
git checkout main
git branch -D be-advisor/consultation-N
```

## What if the parent's body is wrong?

You may notice the parent issue has incorrect AC, missing context, or wrong assumptions about the data shape. Don't edit the parent. Either:

- Mention the issue under "Conflicts with request" with specificity
- If the parent body is fundamentally broken, the consultation can't really proceed; post a response that says so under "Conflicts" and let arch-shape handle

The discipline is: surface, don't fix.

## Anti-patterns

- **"While I was investigating, I noticed an unused column; let me drop it"** — out of scope; surface as drift
- **"I edited the OpenAPI spec to match what we'd build"** — that's a contract change without authority
- **"I left a TODO in the migration file"** — that's a code change
- **"I ran the new query to test it"** — only against dev / read-only; never mutating
- **"I commented on the parent with my findings"** — wrong issue. Advice goes on the consultation.
- **Pushing a branch** — even if you don't open a PR, the branch is a write

## What read-only enables

- arch-shape can re-run consultations without state collision
- Multiple advisors don't fight over shared state
- The audit trail is clean: one comment, one close
- be (the implementer role) retains contract-publishing authority unambiguously

## Quick checklist

Before closing the consultation:

- [ ] No `git commit` ran
- [ ] No `gh issue edit` ran on any issue
- [ ] No `gh pr` commands ran
- [ ] No file writes outside `/tmp/`
- [ ] No contract/schema/migration files touched
- [ ] No mutating DB statements run anywhere
- [ ] Working branch (if any) is deleted
