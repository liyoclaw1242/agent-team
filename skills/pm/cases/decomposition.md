# Case: Request Decomposition

How to break a request into agent-executable issues.

---

## Principle

Each issue must be:
- **Atomic**: one agent, one cycle, one PR
- **Typed**: clear `agent_type` — don't make a BE agent write CSS
- **Ordered**: `depends_on` reflects real data/API dependencies, not preferences

---

## Example 1: "Add user settings page"

Original request from product:
> Users should be able to change their display name, email, and notification preferences.

### Decomposition

| # | Title | agent_type | priority | depends_on |
|---|-------|-----------|----------|------------|
| 1 | Design settings page layout and states | design | high | — |
| 2 | Add PATCH /users/:id/settings API endpoint | be | high | — |
| 3 | Add settings form component with validation | fe | high | 1, 2 |
| 4 | Add notification preferences toggle to settings | fe | medium | 3 |
| 5 | Write e2e test for settings page | qa | medium | 3 |

### Why this order
- Design (#1) and API (#2) can run in parallel — no dependency
- FE (#3) needs both: the design for layout, the API for data shape
- Notification toggle (#4) is a sub-feature of the form, depends on #3 existing
- QA (#5) can't test what doesn't exist yet

### Anti-patterns avoided
- NOT: "Build settings page" (too big for one agent)
- NOT: "BE + FE settings" (mixed agent_type)
- NOT: FE depends on QA (wrong direction)

---

## Example 2: "Fix checkout flow dropping items"

Bug report:
> Users report cart items disappearing after payment redirect. Happens on mobile Safari.

### Decomposition

| # | Title | agent_type | priority | depends_on |
|---|-------|-----------|----------|------------|
| 1 | Investigate cart state loss on payment redirect | debug | high | — |
| 2 | Fix: persist cart to session storage before redirect | be or fe | high | 1 |
| 3 | Add regression test for cart persistence across redirect | qa | medium | 2 |

### Why this order
- DEBUG first to find root cause — don't guess the fix
- Fix depends on diagnosis (agent_type TBD until #1 completes)
- QA locks in the fix

---

## Example 3: "Set up CI/CD pipeline"

Request:
> We need automated testing and deployment for the repo.

### Decomposition

| # | Title | agent_type | priority | depends_on |
|---|-------|-----------|----------|------------|
| 1 | Add GitHub Actions workflow for lint + test on PR | ops | high | — |
| 2 | Add Docker build stage to CI workflow | ops | medium | 1 |
| 3 | Add deploy-to-staging job on merge to main | ops | medium | 2 |
| 4 | Document CI/CD setup in README | ops | low | 3 |

### Why sequential
- Each step builds on the previous CI config file
- Parallel OPS issues on the same workflow file = merge conflicts

---

## Sizing Heuristic

| Size | Fits one cycle? | Action |
|------|----------------|--------|
| "Add a button" | Yes | Single FE issue |
| "Add a CRUD feature" | No | Decompose into 3-5 issues |
| "Rebuild the auth system" | No | Send back to ARCH for architecture decision first |
| "Fix typo" | Yes | Single issue, low priority |

If you're unsure whether something fits one cycle, err on the side of splitting. Two small issues are better than one that times out.
