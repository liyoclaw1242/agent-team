# Rule: DB Validation (Multi-DB)

## Supported Databases

| DB | CLI | Connection |
|----|-----|------------|
| PostgreSQL | `psql` | `psql "$DATABASE_URL" -c "{SQL}"` |
| MySQL | `mysql` | `mysql -h {host} -u {user} -p{pass} {db} -e "{SQL}"` |
| SQLite | `sqlite3` | `sqlite3 {file} "{SQL}"` |
| MongoDB | `mongosh` | `mongosh "{URI}" --eval "{JS}"` |

## DB Detection

Before running queries, detect the DB type:

1. Check env files: `grep -r "DATABASE_URL\|DB_HOST\|MONGO_URI" .env* 2>/dev/null`
2. Check ORM config:
   - Prisma: `cat prisma/schema.prisma | grep provider`
   - Drizzle: `cat drizzle.config.*`
   - Knex: `cat knexfile.*`
   - TypeORM: `cat ormconfig.*`
3. Check docker-compose: `grep -A3 "image:.*postgres\|mysql\|mongo" docker-compose.yml`

## What to Verify

| Check | When |
|-------|------|
| Row created/updated/deleted | After any write API call |
| Field values correct | After create/update operations |
| Constraints hold | After edge case inputs (nulls, duplicates, FK) |
| Indexes exist | After migration specs |
| No orphaned records | After delete operations |
| Timestamps reasonable | After any write (not null, not epoch, correct timezone) |

## Query Patterns

```sql
-- Row count after operation
SELECT count(*) FROM {table} WHERE {condition};

-- Verify specific fields
SELECT id, name, status, created_at FROM {table} WHERE id = {id};

-- Check for orphans after delete
SELECT c.id FROM {child_table} c
LEFT JOIN {parent_table} p ON c.parent_id = p.id
WHERE p.id IS NULL;

-- Verify unique constraint
SELECT {column}, count(*) FROM {table}
GROUP BY {column} HAVING count(*) > 1;
```

```javascript
// MongoDB equivalents
db.collection.countDocuments({ status: "active" })
db.collection.findOne({ _id: ObjectId("...") })
```

## Safety

- **Read-only queries** during verification — never INSERT/UPDATE/DELETE directly
- If the test plan requires seed data, document it in prerequisites
- Use transactions or a test database when possible
