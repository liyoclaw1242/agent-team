# Rule — Schema Migration Discipline

Schema changes touch production data. The cost of a bad migration is high (data loss, downtime, manual recovery). This rule keeps migrations safe by default.

## Default: additive-only

The safe migration is **purely additive**:

- Add a new column (NOT NULL with DEFAULT, or NULLABLE; never NOT NULL without DEFAULT on a non-empty table)
- Add a new table
- Add a new index (CONCURRENTLY for Postgres; check your DB's online-index pattern)
- Add a new constraint with `NOT VALID` first, then validate later

Additive migrations are safe to ship in a single PR with no coordination. The old code and new code both work against the additive schema.

## When destructive changes are required

Sometimes you really do need to:

- Remove a column / table / index
- Change a column type incompatibly
- Tighten a constraint that existing data violates
- Rename something

These cannot ship in a single PR. They follow the **expand-contract pattern**:

### Phase 1 — Expand

Add the new shape alongside the old:

- New column added; old column kept
- New table created; old table kept
- Code reads from old, writes to BOTH

This phase is safe to ship. Old consumers keep working.

### Phase 2 — Migrate consumers

Update each consumer to read from the new shape:

- Code reads from new (with fallback to old if new is empty)
- Backfill old data into new shape via a migration script
- Verify: every read should now find data in the new shape

This phase is also safe. Roll out gradually if your platform supports it.

### Phase 3 — Contract

Once Phase 2 is live and verified, remove the old shape:

- Drop column / table / index
- Code only reads + writes new

This is the destructive step. By now, no consumer depends on the old shape.

Each phase is its own PR (in fact, often its own arch-shape decomposition — multiple tasks under one parent).

## What this means for arch-shape collaboration

If a Hermes business request implies a destructive change ("rename `status` to `state`"), arch-shape's first decomposition often misses the multi-phase nature. BE catches this at Phase 1 reading and writes Mode C feedback:

```markdown
## Technical Feedback from be

### Concern category
migration-impossibility (in single task)

### What the spec says
"Rename `subscriptions.status` to `subscriptions.state`"

### What the codebase shows
- 14 places query subscriptions.status
- Production has 2.3M subscription rows
- Postgres ALTER TABLE RENAME COLUMN is metadata-only and fast, but...
- ...code referring to .status would 500 immediately on any read

### Options I see
1. Multi-phase: add `state` column, dual-write, migrate readers, drop `status` (3 tasks)
2. Coordinated: schedule downtime, rename + deploy in lockstep (operationally expensive)

### My preference
Option 1. The team's standard for renames.
```

arch-feedback will accept and re-shape into 3 tasks.

## Migration safety checklist

For every migration, verify:

- [ ] **Reversibility**: a `down` migration exists OR the change is documented as one-way with rationale
- [ ] **Locks**: estimated lock duration on the affected tables. Anything >100ms on a hot table needs `CONCURRENTLY` or batched migration
- [ ] **Backfill plan**: if data needs filling in, the backfill is in the migration or in a separate job (not in handler hot paths)
- [ ] **Rollback plan**: if the migration succeeds but the deploy fails, can we roll back the deploy without rolling back the migration? (Almost always yes for additive; sometimes no for destructive)
- [ ] **Data validation**: after migration, run a sanity query (`SELECT COUNT(*) FROM ... WHERE new_column IS NULL` etc.) to confirm
- [ ] **Test**: integration test runs the migration as part of test setup; tests pass against the migrated schema

The integration test running the migration is what catches "the migration is structurally wrong" (syntax error, missing index, etc.) before it ships.

## Postgres-specific patterns

Some Postgres operations have non-obvious lock implications:

- `ALTER TABLE ... ADD COLUMN NOT NULL DEFAULT x` was historically a full-table rewrite; in PG 11+ it's metadata-only IF the default is non-volatile
- `CREATE INDEX` blocks writes; use `CREATE INDEX CONCURRENTLY` for hot tables
- `ADD CONSTRAINT ... NOT VALID` adds without validating existing data; then `ALTER TABLE ... VALIDATE CONSTRAINT` validates concurrently

When in doubt, look up the operation's lock class in the Postgres docs.

## Other-DB patterns

- **MySQL**: many DDL operations are blocking; use pt-online-schema-change or gh-ost for hot tables
- **MongoDB**: schema is implicit, but indexes still block writes by default; use `background: true` (or `createIndexes` with `commitQuorum`)
- **DynamoDB**: schema changes are GSI-add (cheap) or GSI-drop (cheap); the issue is usually with downstream code expecting a GSI that hasn't been provisioned yet

## Migrations and self-test

The self-test record for any migration includes:

```markdown
## Migration safety
- Lock duration: estimated 5-10ms (additive column, no constraint)
- Backfill: not needed (NULLABLE column)
- Reversibility: down migration drops the column
- Tested: integration test boots schema with migration; all subsequent tests pass
- Production simulation: ran migration against staging-restored prod copy; took 8ms; no replication lag impact
```

For larger migrations, a dedicated runbook may be required; that's an OPS concern that gets a sibling task.

## Anti-patterns

- **"This is just a small column rename, no need for expand-contract"** — same risk shape; same discipline. Renames have wrecked production.
- **Adding NOT NULL with no DEFAULT on a non-empty table** — straight rewrite; multi-second locks; outages
- **Running data backfill in handler hot path** — distributes load to every request; degrades user-visible latency
- **Migrating data and changing read code in the same PR without dual-read** — if the migrate fails partway, the new read code can't handle the partial state
- **No down migration for an additive change** — additive changes are easy to roll back; not having a down is laziness
