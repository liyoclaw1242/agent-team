# Rule: Observability Query Discipline

## Signal Priority

Always start broad, narrow down:

1. **Metrics first** — is there a visible anomaly? (PromQL)
2. **Logs second** — what error messages appear? (LogQL)
3. **Traces third** — what's the full request path? (TraceQL)
4. **Code last** — only read code after you have evidence

Never skip to code without checking signals. "I looked at the code and found a bug" is not investigation — it's guessing.

## Query Rules

- **Always scope by time** — use the bug report timestamp +/- 1 hour as starting window
- **Always scope by service** — never query all services at once
- **Include trace_id in log queries** — enables log → trace jump in Grafana
- **Save useful queries** — if a query helped diagnose, include it in the report
- **Don't modify production data** — read-only queries only. No `EXPLAIN ANALYZE`, no write operations

## Endpoint Reference

| Signal | Endpoint | Query Language |
|--------|----------|---------------|
| Metrics | Prometheus `localhost:9099` | PromQL |
| Logs | Loki `localhost:3101` | LogQL |
| Traces | Tempo `localhost:3200` | TraceQL |
| Frontend | Faro via Alloy `localhost:12347` | Faro → Loki/Tempo |
| Dashboard | Grafana `localhost:3002` | All of the above |

## PII Awareness

- OTel Collector redacts `Authorization` headers and hashes `db.statement` by default
- If you see PII in traces/logs, report it as a separate security issue
- Never paste raw PII values in bug reports — use redacted references
