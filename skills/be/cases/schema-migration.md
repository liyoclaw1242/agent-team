# Case — Schema Migration

Any schema change. Read `rules/migration-discipline.md` first; this case shows the pattern in action.

## Worked example: additive (the easy case)

Task spec implies adding a `cancellation_reason` column to subscriptions.

### Phase 1 — Read

The spec needs cancellation reason captured at cancellation time. New column needed.

### Phase 2 — Plan migration

```sql
-- migrations/20260425_add_cancellation_reason.sql
ALTER TABLE subscriptions
  ADD COLUMN cancellation_reason TEXT NULL;

-- Backfill not needed (column is NULL for existing rows; that's correct semantically)

-- migrations/20260425_add_cancellation_reason.down.sql
ALTER TABLE subscriptions DROP COLUMN cancellation_reason;
```

The migration:
- Additive only
- NULLABLE (no default needed; existing rows have NULL which is fine — they were cancelled without recording a reason)
- Reversible (down migration drops the column)
- Lock duration: metadata-only on Postgres 11+; ~5ms

### Phase 3 — TDD

```go
func TestCancel_PersistsReason(t *testing.T) {
    // ... setup ...
    resp := callCancel(req{ID: id, Reason: "moving abroad"})
    assert.Equal(t, 200, resp.Code)

    // Verify DB state
    var stored string
    err := db.QueryRow("SELECT cancellation_reason FROM subscriptions WHERE id = $1", id).Scan(&stored)
    assert.NoError(t, err)
    assert.Equal(t, "moving abroad", stored)
}
```

Test currently fails: column doesn't exist, the SELECT returns an error.

### Phase 4 — Apply migration in test setup

The integration test framework runs all migrations before tests. After committing the migration file, the test setup creates the new column. Test now fails for a different reason: handler doesn't write the column.

### Phase 5 — Implement

Update the cancellation handler to persist the reason. Test goes green.

### Phase 6 — Self-test

```markdown
## Migration safety
- Operation: ADD COLUMN ... NULL
- Lock duration: estimated 5ms (PG11+ metadata-only)
- Backfill: not needed (NULL is correct for historical rows)
- Reversibility: down migration exists; tested locally
- Production sim: ran against staging-restored DB (200K rows); 4ms; no replication impact
```

## Worked example: destructive (the hard case)

Task spec implies removing the legacy `payment_method_legacy_id` column from subscriptions.

### Phase 1 reading reveals issues

```bash
grep -rn "payment_method_legacy_id" .
# 6 places in code reference this column
# 1 place is a scheduled report run by external job (not in this repo)
```

The legacy column is read by 6 places in the codebase plus an external job. A single PR with a DROP COLUMN would break the reads at the moment the migration applies.

### Phase 2 — Mode C

This is migration-impossibility territory. Write feedback:

```markdown
## Technical Feedback from be

### Concern category
migration-impossibility

### What the spec says
"Drop the payment_method_legacy_id column from subscriptions"

### What the codebase shows
- 6 internal references query this column
- An external scheduled job reads this column for compliance reports
- 2.3M production rows; ALTER TABLE DROP COLUMN locks for ~5min on this scale
- We don't have an expand-contract framework yet

### Options I see
1. Multi-step migration: stop-using-internal → coordinate-with-external → drop. Three or more tasks.
2. Soft-drop: rename to legacy_payment_method_legacy_id (sic) for 2 weeks; observe; then drop. Same number of tasks effectively.
3. Stay-with: ship a no-op; column stays; mark for cleanup later. Lowest risk, accepts deferred work.

### My preference
Option 1. The internal references can be updated this sprint; coordination with the external job owner is a known cost.

### Drift noticed
None.
```

Route to arch-feedback. arch-feedback should accept and re-shape into multiple tasks.

### Phase 3 — After re-shape: implement the first sub-task

You now have multiple tasks under the parent:

```
#143 [BE] Remove internal references to payment_method_legacy_id
#144 [OPS] Coordinate with external job owner to migrate off the legacy column
#145 [BE] Drop payment_method_legacy_id column (deps: #143, #144)
```

You pick up #143. It's a pure code change — find the 6 references, update them to use the new column. No migration in this task.

When #143 ships and #144 confirms external migration is done, #145 unblocks. That task does the DROP COLUMN.

## Worked example: in-place type change (often the trickiest)

Spec implies changing a `varchar(20)` column to `uuid`.

This is destructive (not all varchar(20) values are valid UUIDs). Pattern:

1. Add a new `id_uuid` column
2. Backfill: for rows where the old column is parseable as UUID, copy; for others, generate a fresh UUID and update
3. Code reads from `id_uuid` (with fallback to old if needed)
4. Update foreign keys to point at `id_uuid`
5. Drop the old column

That's a 5-task decomposition typically. Each step is its own PR; each is reversible until the final step.

## Migration ordering and rollback

Within a PR, migrations apply in their filename's timestamp order. Within an environment, migrations are applied at deploy time (as part of the rollout, before the new binary takes traffic).

Rollback considerations:

- **Pre-deploy**: if the migration fails, the old binary still works; no rollback needed
- **Mid-deploy**: if the migration succeeded but the binary deploy failed, can the old binary cope with the new schema? Additive yes; destructive no.
- **Post-deploy**: if a bug surfaces after deploy, reverting the binary doesn't undo the migration. Either the migration was reversible (down migration exists and is safe) or it isn't.

Never ship a destructive migration in the same PR as a deploy that depends on it. Separate them.

## Common migration mistakes

- **NOT NULL DEFAULT on huge table** — full table rewrite, multi-second locks. PG 11+ allows this for non-volatile defaults but verify.
- **CREATE INDEX without CONCURRENTLY** — blocks writes during creation; on a 1M row table, multi-minute outage
- **Forgetting to commit the migration file before running tests** — local DB has the change; CI doesn't
- **Down migration that's just `-- TODO`** — not a down migration. Either write it or accept that the change is one-way.
- **Backfill in a single transaction** — for large tables, this holds locks for too long. Batch by primary key range with checkpoints.

## Self-test for migrations

Every migration's self-test record includes the `Migration safety` section:

```markdown
## Migration safety

| Item | Detail |
|------|--------|
| Operation | ALTER TABLE subscriptions ADD COLUMN cancellation_reason TEXT NULL |
| Lock class | ACCESS EXCLUSIVE (briefly; metadata-only on PG 11+) |
| Estimated duration | 5ms |
| Reversible | Yes (down migration drops the column) |
| Backfill | Not needed |
| Tested at scale | Ran against staging-restored prod copy; 4ms |
| Replication impact | None observed |
```

Without this section in the self-test, QA returns FAIL.
