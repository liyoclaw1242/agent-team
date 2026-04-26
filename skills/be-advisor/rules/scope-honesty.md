# Rule — Scope Honesty

The S/M/L estimate is the most consequential part of the advice. arch-shape uses it to decide whether to decompose further. An estimate wrong by 3-5x leads to wrong decompositions and rework cycles.

## The S/M/L scale (backend)

For backend, "scope" is files + contracts + migrations + service-boundary touches:

- **S (Small)**: 1-3 files, 0 contract changes, 0-1 migrations, 1 service. Single PR, comfortable.
- **M (Medium)**: 4-15 files, 0-1 contract changes, 0-2 migrations, 1-2 services. Single PR but substantial; some review iteration expected.
- **L (Large)**: 16+ files, 1-2 contract changes, 2-5 migrations, 2-4 services touched. Single PR borderline; may warrant decomposition.
- **L+ (Beyond Large)**: would touch many services, change critical contracts, require coordinated migrations across multiple tables, or alter consistency / durability semantics. **Should be decomposed at the arch-shape level**.

Backend has higher coordination cost than FE — a single contract change ripples through every consumer. The thresholds reflect that.

If L+, say so explicitly:

```markdown
### Estimated scope

- L+ — request to "add tenant_id to all tables" would:
  - Change 47 tables (verified: count of CREATE TABLE in db/migrations/)
  - Change ~30 contract messages (every message with user-scoped fields)
  - Touch 12 services for migration code
  - Require coordinated migration window (not all migrations are
    independently reversible)
  Strongly suggest decomposing into:
  1. Introduce tenant_id model + auth scoping (M)
  2. Migrate top 3 tables (high-impact, learning by doing) (M)
  3. Migrate remaining tables in batches (M each, ~3-4 batches)
  4. Decommission untenanted code paths (M)
```

## How to estimate

The estimate is grep-driven, not vibe-driven.

### Step 1: Identify touched areas

What services / contracts / tables does the request affect?

```bash
# For "add refund support to payments":
git grep -l "Charge\|charge_id" services/
ls contracts/payments.*
ls db/migrations/ | grep -i charges
```

### Step 2: Count modifications

For each existing file in scope:

```bash
# Files in payments service
find services/payments -type f -name "*.go" | wc -l   # 18

# Likely-modified files (judgment after reading)
# Usually a fraction; in this case maybe 6-8
```

For contracts:

```bash
# Lines per contract message; new RPCs typically don't break consumers
# but new fields require regeneration in all consumers
grep -c "rpc " contracts/payments.proto    # 12 RPCs currently

# Consumers of the contract
git grep -l "import.*payments_pb\|payments\." services/ | wc -l   # 4
```

For migrations:

```bash
# Past schema changes to the affected tables
ls db/migrations/ | grep -E "(charges|payments)"
# Count how many; informs how busy this area has been (proxy for fragility)
```

### Step 3: Count additions

New handlers, new tables, new contract messages, new migrations:

```
- 1 new handler (refund_handler.go)
- 1 new test (refund_test.go)
- 1 new migration (add refunded_at column)
- 1 contract addition (RefundCharge RPC)
- 4 client updates (services consuming the new RPC; thin)
```

### Step 4: Sum + factor

```
Modified: 6 files (handler.go restructure, charge.go integration, etc.)
Added: 4 files (handler, test, migration, contract update)
Contract changes: 1 (additive, non-breaking)
Migrations: 1 (additive column)
Services touched: 1 main + 4 thin client touches
= ~10 files, 1 contract, 1 migration, 5 services → M
```

Round up if uncertain.

## What "files" includes for backend

Count these as files:

- Source code (`.go`, `.py`, `.ts`, `.rb`, `.java` etc.)
- Tests (treat as separate files; they exist and need to change)
- Migrations (schema change files)
- Generated code that consumers will regenerate (count once if all consumers regen automatically; count per-service if manual)
- Configuration / deployment manifests (only if they actually need editing)

Don't count:

- Build artifacts (auto-generated, not authored)
- Lockfiles (auto-managed)
- Documentation as part of the work unless explicitly required (separate concern)

## Backend-specific bias traps

### Underestimating contract ripple

A "1-line proto change" is rarely 1 file:
- The proto change itself
- Regenerated client SDKs (1-N services)
- New field handling in those clients (1-N files)
- Tests that mock the contract (1-N files)
- Documentation if any

A new field adds maybe 0 caller files (callers just ignore unset). A required field or RPC addition affects every caller.

### Underestimating migration coordination

A "single migration" is not always single:
- The migration file
- The deployment timing (can it be applied during normal release?)
- Any related code changes that depend on the migration
- Backfill code if existing rows need population
- Rollback strategy if the migration fails partway

For migrations that aren't strictly additive (column drops, type changes), add 50-100% to the estimate.

### Optimism on cross-service consistency

If the request implies invariants across services (e.g., "every order has a charge"), check: how is that maintained today? If via shared DB transactions, it's "easy". If via async events, it requires idempotency + retry + dead-letter handling — substantially more.

## When the request is vague

If the request says "improve the refund flow" and you can't tell what's meant:

```markdown
### Estimated scope

- Cannot estimate without clarification. Range:
  - "Make refund button refund correctly" (bug fix): S, ~2 files
  - "Add full refund tracking, partial refunds, multi-currency": L+,
    ~30 files, multiple migrations, contract changes
  - Suggest arch-shape narrow the request before scope estimation
```

## Calibration

After several consultations, check estimates against actual implementation PRs. If your M estimates routinely become L PRs, recalibrate. Note in journal:

```
2026-04-26: estimated M for #310, actual was 18 files + 2 migrations (L).
The migration coordination overhead was underestimated. Going forward,
2+ migrations bumps the estimate up one tier.
```

## Anti-patterns

- **"Should be simple"** — not an estimate
- **"Just a contract change"** — contract changes ripple by design
- **Defaulting to M** for everything
- **Ignoring migration coordination cost** — even a single migration has deployment implications
- **Estimating only the modified service** — backend changes often touch contract consumers; count them
- **Hand-waving over breaking changes** — if the contract change is breaking, the cost includes coordinating consumer updates and possibly running parallel versions
- **Conflating "additive" with "free"** — additive changes are cheaper than breaking, but they still need testing across consumers

## Quick checklist

- [ ] Used grep to find consumers / affected services
- [ ] Counted files (modified + added)
- [ ] Counted contract changes (and assessed breaking vs additive)
- [ ] Counted migrations (and assessed reversibility)
- [ ] Counted services touched
- [ ] Marked L+ if applicable, with a decomposition suggestion
- [ ] Gave a range with named scenarios if the request is vague
