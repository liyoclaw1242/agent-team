# Security — Baseline

OWASP-aligned baseline. Every role that writes code or config extends this.

## Secrets

- Never commit credentials, API keys, tokens, private keys, certificates.
- `.env`, `.env.local` etc. are in `.gitignore`. Verify before any commit that touches config.
- If a secret has been committed (even in a previous commit), it is **leaked** — rotate immediately, don't just remove from history.
- Secrets in code are loaded from environment or a secrets manager. Never hardcoded, never default-valued (`token = process.env.TOKEN || 'fallback'` is forbidden — fail fast instead).

## Logging

- Never log secrets, full credit card numbers, full tokens.
- Personally identifiable information (PII) requires explicit handling per the project's privacy policy. When unsure, redact or hash.
- Stack traces in production logs: yes for errors, but ensure they don't include request bodies that contain credentials.

## Input validation

- Trust no input. Validate at every boundary: HTTP, message queue, file upload, CLI args.
- Validate type, length, format, range. Reject early with a clear error.
- Output encoding matches output context: HTML escaping for HTML, SQL parameter binding for SQL, shell escaping for shell. Never concat.

## Dependencies

- Periodic vulnerability scanning is OPS's responsibility, but every role checks at PR time:
  - `npm audit` / `pnpm audit` / `yarn audit` for JS
  - `govulncheck` for Go
  - `pip-audit` for Python
- Critical / High vulnerabilities block merge unless explicitly waived in PR description with rationale and tracking issue.

## Cryptography

- Use the language's standard library or well-vetted crypto libraries. Don't roll your own.
- Random for security purposes uses cryptographic RNG (`crypto/rand`, `crypto.randomBytes`), not `Math.random()`.
- Hash passwords with bcrypt/argon2/scrypt. Never SHA-* a password.
- TLS 1.2 minimum; prefer 1.3.

## See also

- `web.md` — XSS, CSRF, CORS (FE)
- `api.md` — authn/authz, injection, rate limiting (BE)
- `infra.md` — secrets management, container hardening (OPS)
