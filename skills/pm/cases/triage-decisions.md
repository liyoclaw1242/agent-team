# Case: Triage Decisions

When PM encounters an issue that needs judgment, use these patterns.

---

## Decision: Which agent_type?

| Signal in spec | Assign to |
|---------------|-----------|
| UI, component, page, layout, styling, responsive | **fe** |
| API, endpoint, database, migration, business logic | **be** |
| CI/CD, deploy, Docker, infra, monitoring | **ops** |
| System design, ADR, API contract, decompose | **arch** |
| Design audit, mockup, a11y review, visual | **design** |
| Test, review PR, verify, e2e | **qa** |
| Bug, investigate, root cause, "why does X" | **debug** |
| Decompose, triage, prioritize, unblock | **pm** |

**When ambiguous**: assign to `arch` with a comment explaining the ambiguity. ARCH will re-assign after analysis.

---

## Decision: Priority

| Condition | Priority |
|-----------|----------|
| Blocking 2+ other issues | **high** |
| On critical path (auth, payment, data integrity) | **high** |
| Normal feature work | **medium** |
| Nice-to-have, polish, docs | **low** |
| Stale for 24h+ with no claim | Escalate to **high** |

---

## Decision: Clarify vs. Execute

| Situation | Action |
|-----------|--------|
| Spec says "add button to do X" | Execute — clear enough |
| Spec says "improve the dashboard" | Clarify — what specifically? |
| Spec contradicts existing code | Clarify + comment with conflict |
| Spec references non-existent API | Clarify + check if BE issue exists |
| Spec has acceptance criteria | Execute — criteria = contract |

---

## Decision: Merge vs. Split

| Situation | Action |
|-----------|--------|
| Two issues touch the same component, same agent_type | Consider merging |
| One issue requires 2 different agent_types | Split |
| Issue description has "and" connecting unrelated things | Split |
| Issue is > 200 lines of changes (estimate) | Split |

---

## Decision: Re-assign to ARCH

Send back to ARCH when:
- The spec needs architectural decisions (new data model, new API pattern)
- Multiple agents gave conflicting feedback on the same spec
- The request is too large to decompose without understanding the system
- You don't have enough context about the codebase to make the right call

```bash
curl -s -X PATCH "${API_URL}/bounties/${REPO_SLUG}/issues/{N}" \
  -H "Content-Type: application/json" \
  -d '{"status": "ready", "agent_type": "arch"}'
```

Always comment with your reasoning before re-assigning.
