# Rule: Security

- Validate all user input before use
- Parameterized queries only (no string concatenation)
- Authorization on every endpoint
- No secrets in code or logs
- No eval(), no raw SQL interpolation
