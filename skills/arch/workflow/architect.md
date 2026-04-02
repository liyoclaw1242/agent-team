# Architecture Workflow

Three modes:
- **Mode A: Request Decomposition** — break requirements into atomic bounty tasks
- **Mode B: Architecture Design** — produce design artifacts (ADR, API contracts, diagrams)
- **Mode C: Re-evaluation** — handle feedback from FE/BE who found spec conflicts

---

## Mode A: Request Decomposition

### Phase 1: Intake

1. Poll for pending requests: `GET /requests?status=pending`
2. Claim the oldest: `POST /requests/{ID}/claim`
3. Read `summary` + `body` carefully

### Phase 2: Context

1. List repos: `GET /repos`
2. List existing bounties: `GET /bounties` — what's already in progress?
3. **Read arch.md first** — if `arch.md` exists at repo root, read it. This is your persistent map:
   - Domain model, bounded contexts, aggregate roots
   - System architecture, tech stack, data flow
   - API contracts
   - User journey map
   - Product roadmap context, known tech debt
   - If `arch.md` doesn't exist → you must create it as part of this task (see `cases/arch-md-template.md`)
4. Read `README.md`, `package.json`, folder structure
5. Read past journal entries

### Phase 3: Domain Analysis

Before splitting into tasks, understand the domain (reference arch.md):

1. **Identify the domain concepts** — what entities/aggregates does this requirement touch?
2. **Map the data flow** — where does data enter, how does it transform, where does it output?
3. **Find the boundaries** — what's frontend-only, backend-only, cross-cutting?
4. **Check what exists** — is there existing code that partially solves this? Can we extend?

### Phase 4: Decompose

Break into 1-6 atomic tasks. Each task must be:

- **Independent** — implementable without waiting for other tasks (or explicit deps)
- **Testable** — has clear acceptance criteria that QA can verify
- **Single-role** — assigned to one agent_type (be/fe/ops/qa/design)
- **Right-sized** — 1 task = 1 PR. If it needs > 10 files, split further.

For each task, define:
```json
{
  "title": "Verb: what changes",
  "body": "## Task\n...\n## Acceptance Criteria\n- [ ] ...\n## Technical Notes\n...",
  "agent_type": "fe",
  "deps": []
}
```

**Decomposition rules:**
- BE before FE (APIs before UI that consumes them)
- Schema/migration before business logic
- Include QA verification task for testable deliverables
- If FE needs specific component patterns, note it in Technical Notes (but don't dictate implementation)
- **Don't over-specify how** — specify **what** and **done when**. Let the specialist decide how.

### Phase 5: Create

POST each task to `/bounties` in dependency order. Collect issue numbers.

### Phase 6: Update arch.md

If the decomposition introduced new domains, APIs, data flows, or architectural decisions:

```bash
cd {REPO_DIR}
# Edit arch.md with new information
# Commit separately
git add arch.md && git commit -m "docs: update arch.md — {what changed}"
git push origin main
```

### Phase 7: Report

Mark request as decomposed: `PATCH /requests/{ID}` with status + issue list.

### Phase 8: Journal

---

## Mode B: Architecture Design

### Phase 1: Scope Challenge (mandatory)

Before any design work:

1. **What already exists?** Read the codebase. Can we extend instead of create?
2. **What is the minimal design?** What's the smallest thing that solves the problem?
3. **Lake or ocean?**
   - Lake = scoped, finite, clear boundaries → proceed
   - Ocean = unbounded, touches everything → decompose into lakes first (go to Mode A)

**Gate**: Can you draw the boundary of this design on a napkin? If not, it's an ocean.

### Phase 2: Analyze

1. Read `overview.md` / `README.md` (create one if missing)
2. Read existing ADRs in `docs/adr/`
3. Explore codebase: modules, patterns, data flow, integration points
4. Identify constraints: tech stack, infra, existing patterns, team conventions

### Phase 3: Design

Produce artifacts:

**ADR** (Architecture Decision Record) → `docs/adr/NNNN-{slug}.md`:
```markdown
# NNNN: {Title}

## Status
Proposed

## Context
{Why are we making this decision? What forces are at play?}

## Decision
{What we decided and why}

## Consequences
### Positive
- ...
### Negative
- ...
### Risks
- ...
```

**API Contract** → OpenAPI spec or markdown with:
- Endpoints with request/response examples
- Error responses for each endpoint
- Auth requirements

**System Diagram** → Mermaid:
- Component diagram (what talks to what)
- Data flow (where data enters, transforms, outputs)
- Sequence diagram (for complex interactions)

**Failure Modes Registry** → for every service boundary:

| Failure | Detection | Recovery | User Impact |
|---------|-----------|----------|-------------|
| DB connection lost | health check | retry + circuit breaker | 503 with message |
| External API timeout | 10s timeout | fallback to cache | degraded data |

### Phase 4: Validate

- Every new service boundary has a Failure Modes entry
- Every API has request/response examples
- Diagrams are consistent with actual code
- ADR consequences include both positive and negative

### Phase 5: Update arch.md

If the design introduced new domains, service boundaries, APIs, or decisions → update arch.md.

### Phase 6: Deliver

```bash
git add -A && git commit -m "docs: {title} (closes #{N})"
```

### Phase 7: Journal

---

## Mode C: Re-evaluation (feedback from FE/BE)

ARCH polls for `agent_type=arch` — this includes tasks that **FE/BE handed back** because the spec had problems.

### Phase 1: Read Feedback

When you pick up a task, **always check the issue comments first**:

```bash
gh issue view {N} --repo {REPO_SLUG} --comments
```

Look for "Technical Feedback from" comments. These contain:
- **Conflict**: what the spec asks vs what the codebase actually needs
- **Suggestion**: the specialist's recommended approach
- **Affected**: which parts of the spec need revision

### Phase 2: Evaluate

The specialist knows the codebase deeper than you. Their feedback is likely correct. Evaluate:

1. **Does their suggestion align with the domain model?** If yes → accept
2. **Does their suggestion introduce architectural debt?** If yes → propose alternative
3. **Is this a local optimization vs global concern?** Sometimes a suboptimal local choice is the right global choice (e.g., consistency across services)

### Phase 3: Respond

**Accept feedback** (most common):
```bash
# Update the issue spec
gh issue edit {N} --repo {REPO_SLUG} \
  --body "{revised spec incorporating the feedback}"

# Comment acknowledging
gh issue comment {N} --repo {REPO_SLUG} \
  --body "## Re-evaluation by \`{AGENT_ID}\`

Accepted feedback from {FE/BE agent}. Spec updated:
- {what changed and why}

Handing back to \`agent:{original_type}\`."

# Hand back
curl -s -X PATCH "{api_url}/bounties/{REPO_SLUG}/issues/{N}" \
  -H "Content-Type: application/json" \
  -d '{"status": "ready", "agent_type": "{original_type}"}'
```

**Counter-propose** (when global concerns override local optimization):
```bash
gh issue comment {N} --repo {REPO_SLUG} \
  --body "## Re-evaluation by \`{AGENT_ID}\`

I see the local concern, but the current spec is intentional because {global reason}.
Suggested approach: {alternative that satisfies both concerns}.

Spec updated with clarification."
```

### Phase 4: Journal

Record: what feedback came in, why you accepted/rejected, what you learned about this codebase's constraints. This is how ARCH gets smarter about this repo over time.
