# Rule — Read-Only Discipline

fe-advisor never modifies anything. Not code, not arch-ddd, not other issues, not the parent's body. The only writes are:

1. The advice comment on this consultation issue
2. The close action on this issue

That's it.

## Why this matters

arch-shape's brainstorm flow assumes advisors are independent observers. If fe-advisor edits arch-ddd or modifies the parent issue mid-consultation, the synthesis phase breaks — arch-shape would be reading state that two consultations contributed to without coordination.

The discipline:

- **No `git commit`** — even on a sandbox branch
- **No `gh issue edit`** on any issue — including this consultation
- **No `gh pr` operations** — there's no PR involved
- **No file writes to `arch-ddd/`** — drift gets reported, not fixed
- **No file writes to `_shared/`** — same reason
- **No setting labels** beyond what the role's actions explicitly do

## What "drift" means and why advisors don't fix it

If you notice arch-ddd doesn't match the codebase ("the bounded context says we have one auth provider; we actually have three"), that's drift. Report it under "Drift noticed":

```markdown
### Drift noticed
- arch-ddd/bounded-contexts/auth.md says "single OAuth provider"; codebase has
  three: lib/auth/google.ts, lib/auth/github.ts, lib/auth/saml.ts. Last
  updated to ddd file: 2024-08-12; auth/saml.ts merged 2024-11-03.
```

arch-shape will decide what to do about it (often: an arch-shape PR updating arch-ddd before decomposing further). If fe-advisor edits arch-ddd directly, arch-shape never knows the drift was there.

## Branch hygiene

Don't create a branch for the consultation. There's no code to commit. Working files (notes, scratch) go in `/tmp/` and are deleted when the consultation closes.

If you accidentally created a branch (e.g., setup.sh did so), delete it after responding:

```bash
git checkout main
git branch -D fe-advisor/consultation-N
```

## What if the parent's body is wrong?

You may notice the parent issue has incorrect AC, missing context, or wrong assumptions. Don't edit the parent. Either:

- Mention the issue under "Conflicts with request" with specificity
- If the parent body is fundamentally broken (not just imperfect), the consultation can't really proceed; post a response that says so under "Conflicts" and let arch-shape handle

The discipline is: surface, don't fix.

## What about `_shared/` rules or the role's own SKILL?

If you read `skills/fe-advisor/rules/read-only.md` (this file) and notice an error in it, don't edit it. Note it in your closing journal entry. Skill maintenance is its own task category (likely arch-shape territory).

## Anti-patterns

- **"While I was investigating, I noticed X was broken; let me just fix it"** — that's scope expansion via stealth
- **"I edited arch-ddd to fix the drift"** — defeats arch-shape's ability to know about it
- **"I left a note in CONTRIBUTING.md"** — that's a code change
- **"I commented on the parent issue with my findings"** — wrong issue. The advice goes on the consultation issue.
- **"I closed an unrelated stale issue while I was here"** — out of scope
- **Pushing a branch** — even if you don't open a PR, the branch is a write

## What read-only enables

By staying read-only:

- arch-shape can re-run the consultation if needed (no state change)
- Multiple advisors don't collide in shared state
- The audit trail is clean: one comment, one close, nothing else
- Trust between roles is preserved — arch-shape can rely on fe-advisor not surprising it

## Quick checklist

Before closing the consultation issue:

- [ ] No `git commit` ran
- [ ] No `gh issue edit` ran on any issue
- [ ] No `gh pr` commands ran
- [ ] No file writes outside `/tmp/`
- [ ] No labels modified except the close action
- [ ] Working branch (if any) is deleted
