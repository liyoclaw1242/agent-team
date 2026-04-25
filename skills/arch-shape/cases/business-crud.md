# Case — Decomposing a CRUD-shaped business request

Common, and easy to do badly. The trap is over-decomposition (every CRUD operation becomes a separate task) or under-decomposition (one task that says "implement CRUD for X").

## Example input

> **Outcome**: Admins can create, edit, archive, and view audit log entries for promotional codes.
> **Motivation**: Marketing currently relies on engineers; we want to delegate.
> **Success signal**: Marketing creates ≥10 codes in first month without engineering help.

## Anti-decomposition (don't)

```
[FE] Create promo-code page
[FE] Edit promo-code page
[FE] Archive promo-code page
[FE] Promo-code list page
[BE] Create promo-code endpoint
[BE] Edit promo-code endpoint
[BE] Archive promo-code endpoint
[BE] List endpoint
[QA] Test all the above
```

Why this is bad:
- 9 tasks for a flat CRUD = ceremony overhead exceeds work
- FE/BE pages are coupled; splitting them is artificial
- QA at the end is shift-right, not shift-left

## Better decomposition

```
[Design] Promo-code admin UI specs (list, create/edit modal, archive confirm)
[BE] Promo-code resource: schema + endpoints (list, create, edit, archive)
[FE] Promo-code admin pages, consuming BE contract
[QA] E2E test: create, edit, archive code; verify audit log entries
```

Why this is better:
- 4 tasks; each is a meaningful unit of work
- BE delivers a contract; FE depends on it (deps marker)
- QA's E2E covers the whole user-facing flow
- Audit log was mentioned in the request — explicit AC on the QA task picks that up

## Decomposition discipline shown here

- **One BE task for all CRUD operations** because they share a single resource model
- **One FE task** because the pages share components and routing — splitting forces premature abstraction decisions
- **Design comes first** — without specs, FE will guess, then redo
- **QA comes last in deps order** — but the E2E test is shift-left in that QA is a real task with explicit AC, not an afterthought

## Acceptance criteria pattern

Each task's AC stays at the **outcome** level, not implementation:

```markdown
## Acceptance criteria

- [ ] Marketing user can list all promo codes ordered by creation time desc
- [ ] List shows: code, discount, valid-from / valid-to, redemption count, status
- [ ] "Create" opens a modal; required fields validated client-side and server-side
- [ ] Successful create returns to list with new code highlighted briefly
- [ ] "Edit" allows changing all fields except the code itself (immutable)
- [ ] "Archive" requires confirmation; archived codes don't appear in list (toggle to view)
- [ ] All actions create audit log entries: actor, action, timestamp, before/after diff
```

Note: the AC say nothing about React Query, no specific HTTP status codes, no internal naming.

## When to add a deps marker

The FE task body contains:

```markdown
<!-- deps: #143 -->

Implements the admin UI per Design's specs (#142). Consumes the BE contract from #143.
```

Setting the deps marker means the FE task starts as `status:blocked` and `scan-unblock.sh` will release it once #143 is closed. FE doesn't poll an unimplementable spec.
