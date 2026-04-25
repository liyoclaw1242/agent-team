# Security — Web (FE)

Extends `base.md`. Front-end / browser-context security.

## XSS

- Never use `dangerouslySetInnerHTML` / `v-html` / `[innerHTML]` with user-derived content.
- If you must render user-supplied HTML, sanitize with DOMPurify or equivalent **at render time**, not at storage time. (Rationale: sanitizer rules evolve; storage-time sanitization can leave stale unsafe content in the DB.)
- Templates with auto-escaping (React JSX, Vue templates, Angular templates) handle most cases. The risk is escape hatches — review them carefully.

## CSRF

- State-changing requests (`POST`, `PUT`, `DELETE`, `PATCH`) include a CSRF token from the server.
- Same-Site cookie attribute is `Lax` minimum; `Strict` for sensitive sessions.
- Don't authenticate state changes via GET. Ever.

## Content Security Policy

- A CSP header is required. Default-deny; explicitly allow what's needed.
- `unsafe-inline` and `unsafe-eval` are forbidden in production CSPs. If you need them for development, gate by environment.
- CSP violations should be reported to a monitored endpoint.

## Local storage

- Never store auth tokens in `localStorage`. They're accessible to any JS, including third-party scripts.
- Use httpOnly + Secure + SameSite cookies for auth.
- `localStorage` is fine for non-sensitive UX preferences (theme, sidebar state).

## Third-party scripts

- Every `<script src="...">` to an external domain is a supply-chain risk. Subresource Integrity (`integrity=` attribute) required when loading from CDNs.
- Tag managers, analytics, ads — review what they can access. They can read forms, cookies, DOM.

## Validation

OPS sets up CSP header tests; FE validates inline:
```bash
# Reject any new occurrence of dangerous patterns
grep -r "dangerouslySetInnerHTML\|v-html" src/ && exit 1 || true
```
