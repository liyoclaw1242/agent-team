# Security — API (BE)

Extends `base.md`. Server-side / API security.

## Authentication

- Auth happens at the framework's middleware/router layer, not in handler code.
- Token validation: signature, expiry, issuer, audience — all four, every request.
- Failed auth returns 401 with no token-validity information leaked. ("invalid token" not "token expired 3 days ago").

## Authorization

- Authorization checks happen **after** loading the resource: load the resource, then check the authenticated user has access. Never assume URL patterns enforce ownership.
- Default deny. Add explicit allow rules; never allow-by-omission.
- Document the authorization model in the bounded context's `_shared/domain/bounded-contexts/{ctx}.md`.

## Input validation

- Every endpoint declares its input schema (JSON schema, Zod, Pydantic, struct tags). Framework rejects malformed input before handler runs.
- IDs from URLs are validated for format; ownership checked on load.
- Numeric inputs check bounds, not just type. ("amount" must be > 0 and < some max).

## Injection

- SQL: parameterised queries / prepared statements always. Concatenation is forbidden.
- ORM raw queries: review carefully, parameterise, comment why raw was needed.
- NoSQL injection still exists — query objects with user input must validate field names against a whitelist.
- Command injection: don't shell out with user input. If you must, use the language's argv-form (no shell parser).

## Rate limiting

- Public endpoints have rate limits. By IP minimum, by authenticated user when available.
- Login/signup/password-reset have stricter limits and a delay-on-failure curve.
- Rate limit headers (`X-RateLimit-*`) returned to legitimate clients.

## CORS

- Allow-list specific origins. `*` is forbidden for endpoints serving authenticated users.
- Don't allow credentials with wildcard origin.

## Validation

```bash
# Look for raw query construction
grep -rE "fmt\.Sprintf.*SELECT|\\\$\\{.*query|\\+ \" SELECT\"" src/ && exit 1 || true
# Auth middleware presence
grep -r "router\.Use(.*Auth" src/ || (echo "no auth middleware found"; exit 1)
```
