# Rule — Evidence Over Opinion

Every claim cites concrete evidence: file path, contract version, table name, endpoint path, commit, grep result, count. Opinions without evidence dilute the consultation's value.

## The contrast

**Opinion** (low value):
```
- The payment service is messy and would be hard to refactor
- We have some database schema issues
- Adding an endpoint is probably easy
```

**Evidence** (high value):
```
- Payment service handler.go is 1,400 lines with 40+ exported functions;
  splitting it would touch 4 client services that currently import the
  helper functions directly (orders, billing, refunds, admin)
- charges table schema has 3 nullable columns added across 5 migrations
  (db/migrations/2024-{03,04,06,08,11}); accumulated drift between schema
  and the application's payments.proto Charge message
- New endpoints in services/payments/ follow a consistent pattern (handler
  function + proto RPC + test); 5 examples as templates; copying that
  pattern adds ~4 files (handler, test, contract update, client regen)
```

The evidence answers "how do you know?" before arch-shape has to ask.

## How to gather evidence (backend tools)

```bash
# Find services / endpoints
git grep -l "rpc.*returns\|router\.\(GET\|POST\|PUT\|DELETE\)" services/

# Count endpoint definitions
grep -c '^[[:space:]]*rpc ' contracts/payments.proto

# Find consumers of a contract
git grep -l "import.*payments_pb\|payments\." services/ | grep -v payments/

# Recent contract evolution
git log --oneline -- contracts/payments.proto

# Migration history for a table
ls db/migrations/ | grep -i charges

# Schema columns
grep -A20 "CREATE TABLE charges" db/migrations/*.sql | head -30

# Find table consumers (queries / models)
git grep -l "FROM charges\|charges\\.\|\"charges\"" services/

# Recent activity in an area
git log --oneline -30 -- services/payments/
```

The investigation is most of the work.

## Citation conventions

In the advice:

- **file:line** — `services/payments/handler.go:42`
- **contract reference** — `contracts/payments.proto Charge RPC`
- **table reference** — `payments.charges (db/migrations/2024-03-15-charges.sql)`
- **endpoint path** — `POST /v1/charges` or `payments.PaymentService/Charge`
- **commit / PR** — `(commit a1b2c3d)` or `(PR #145)`
- **arch-ddd reference** — `(arch-ddd/bounded-contexts/payments.md)`
- **migration reference** — `db/migrations/2024-11-12-add-currency.sql`

## When evidence is unavailable

Sometimes you can't gather evidence in 2 hours — codebase unfamiliar, area undocumented, etc. Two options:

### Option 1: Acknowledge limit explicitly

```markdown
### Existing constraints

- Payments service: confident from handler.go inspection that current
  shape is request-response RPC with synchronous DB writes
- Webhook handling: I traced services/payments/webhook.go but did not
  exhaustively trace all webhook event paths
- Cross-service contracts: I verified payments.proto consumers via
  grep; did not verify SDK regeneration is automatic in CI (unconfirmed)
```

### Option 2: Defer with a follow-up

```markdown
### Conflicts with request

- Request implies real-time refund status. Current architecture sends
  webhook then polling. I can describe the patterns FE-side and the
  webhook payload, but I haven't traced ops-side queue infrastructure.
  If real-time push is critical, recommend ops-advisor consultation
  on queue / pub-sub options.
```

## Counts vs estimates

When possible, count:

- "many endpoints" — opinion
- "~40 endpoints" — estimate
- "23 endpoints (verified: `grep -c '^[[:space:]]*rpc' contracts/*.proto`)" — measured
- "uses gRPC extensively" — opinion
- "8 services expose gRPC; 4 services HTTP-only; mixed via gateway" — measured

## Backend-specific evidence priorities

For backend, certain evidence types matter more:

### Contract fingerprints

When a request would alter a contract, cite:
- Current contract location (`contracts/payments.proto`)
- Current consumer count (`grep -l ... | wc -l`)
- Last contract change (`git log -1 --format=%h --` on contract file)
- Whether deprecation pattern exists in the codebase (`grep deprecated contracts/*.proto`)

### Schema fingerprints

When a request would alter a schema, cite:
- Current schema location (the migration that created the relevant table)
- Recent column additions (last few migrations)
- Approximate row count if known (`SELECT count(*)` is OK on dev; cite as approx)
- Indexes that would be affected

### Service boundary fingerprints

When a request crosses service boundaries:
- Which services are involved (path enumeration)
- How they currently communicate (sync RPC, async queue, shared DB)
- What latency / consistency assumptions exist (eventual? immediate? cached?)

## Anti-patterns

- **"Database changes would be hard"** without naming the tables or migrations
- **"This service is fragile"** without anchor
- **"Easy to add an endpoint"** without counting the propagation cost
- **Citing memory instead of `git grep`** — schemas evolve; verify
- **Reporting the implementation you'd want, not what's there** — bias
- **Inferring contracts from variable names** — always check the actual contract file
- **Confusing "we have X table" with "X is well-modeled"** — schema existence ≠ schema correctness

## Why this matters most for advisors

For implementer roles (be), opinion shows up in code — review catches it. For advisor roles, opinion shows up in the advice arch-shape uses to decide. Bad advice → bad decomposition → wasted implementation rounds. The error compounds.

The rule isn't "be exhaustive". It's "every assertion should be one a reader can verify in 30 seconds". If that's possible, the assertion is sound.

## Quick checklist

- [ ] Every constraint bullet has a file / contract / table reference
- [ ] Suggested approach cites which existing pattern it extends
- [ ] Conflicts give specific reasons (not vague concerns)
- [ ] Scope estimate has counts (files, contracts, migrations)
- [ ] Risks describe failure modes (not just "risky")
- [ ] Drift includes both arch-ddd reference and codebase reality
