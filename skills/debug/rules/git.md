# Rule: Git Hygiene

- Branch: `agent/{AGENT_ID}/issue-{N}`
- Commit prefix: `diag:` | `debug:` | `investigate:` | `chore:`
- Commit format: `{prefix}: {description} (closes #{N})`
- One logical change per commit
- No large files, no secrets, no .env
- DEBUG agents commit reports only — never source code changes
