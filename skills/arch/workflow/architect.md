# Architecture Workflow

Five modes:
- **Mode 0: Bootstrap** — if `arch.md` doesn't exist, reverse-engineer it from the project
- **Mode A: Request Decomposition** — break requirements into atomic bounty tasks
- **Mode B: Architecture Design** — produce design artifacts (ADR, API contracts, diagrams)
- **Mode C: Re-evaluation** — handle feedback from FE/BE who found spec conflicts
- **Mode D: Triage** — receive completed work from agents, decide: merge / route / decompose

## Mode Routing

After pre-flight, classify the task to choose the correct mode:

| How you got this task | Mode |
|----------------------|------|
| Issue is a new requirement / feature request (no prior agent work) | **A** (Decomposition) |
| Issue body requests architecture design / ADR | **B** (Design) |
| Issue comments contain "Technical Feedback from" by FE/BE | **C** (Re-evaluation) |
| Issue comments contain QA/Design verdict, or PR exists with no review | **D** (Triage) |
| Issue was previously assigned to another agent (routed back) | **D** (Triage) |

**Mode D is the most common mode** — every completed task from every agent flows through here.

---

## Pre-flight (run before every mode)

```bash
bash skills/arch/actions/preflight.sh {REPO_DIR}
```

| Exit code | Meaning | Action |
|-----------|---------|--------|
| 0 — READY | arch.md exists, complete | Proceed to requested mode |
| 1 — BOOTSTRAP_REQUIRED | arch.md missing | Run Mode 0 first |
| 2 — INCOMPLETE | arch.md has missing sections | Re-run Mode 0 to fill gaps |

---

## Mode 0: Bootstrap (when pre-flight says BOOTSTRAP_REQUIRED or INCOMPLETE)

**Trigger**: `arch.md` does not exist or is incomplete.

This runs ONCE before any other mode. You cannot decompose or design without a map.

### Step 1: Read the README

```bash
cd {REPO_DIR}
cat README.md
```

Understand: what is this project? Who uses it? What problem does it solve?

### Step 2: Detect Tech Stack

```bash
cat package.json 2>/dev/null || cat Cargo.toml 2>/dev/null || cat go.mod 2>/dev/null
ls -la
```

Record: framework, language, styling, database, auth, test tools.

### Step 3: Map the Structure

```bash
find . -maxdepth 3 -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" \) | head -50
find . -maxdepth 2 -type d | grep -v node_modules | grep -v .git
```

Identify: where do pages live, where do components live, where does business logic live, where do API routes live.

### Step 4: Discover API Contracts

```bash
# Next.js API routes
find . -path "*/api/*" -name "route.ts" -o -name "route.js" | head -20
# Or Express/Fastify routes
grep -rn "app.get\|app.post\|router." --include="*.ts" --include="*.js" src/ | head -20
```

Read each route file to understand: method, path, request/response shape, auth.

### Step 5: Discover Domain Model

Read the key files:
- Database schema (Prisma schema, migrations, models)
- Type definitions (`types/`, interfaces)
- State management (stores, context providers)

Identify: what are the core entities? How do they relate? What are the invariants?

### Step 6: Trace User Journeys

Read the page/route structure to map user flows:
```bash
find . -path "*/app/*" -name "page.tsx" -o -name "page.ts" | sort
```

For each page: what can the user do here? Where do they go next?

### Step 7: Check for Existing Docs

```bash
find . -maxdepth 2 -name "*.md" | grep -v node_modules | grep -v CHANGELOG
ls docs/ 2>/dev/null
```

Read any existing ADRs, architecture docs, or design docs.

### Step 8: Write arch.md

Using everything you gathered, create `arch.md` at repo root following the template in `cases/arch-md-template.md`.

Fill in every section you can. Mark sections you're uncertain about with `<!-- TODO: verify -->`.

```bash
# Write arch.md
git add arch.md
git commit -m "docs: bootstrap arch.md from project analysis"
git push origin main
```

### Step 9: Announce

```
[{AGENT_ID}] Bootstrapped arch.md for {REPO_SLUG}
  Domains: {N} identified
  APIs: {N} endpoints documented
  Pages: {N} user-facing routes
  Tech debt: {N} items noted
```

Now proceed to the requested mode (A, B, or C).

---

## Mode A: Request Decomposition

### Phase 1: Intake

The request is a GitHub issue with `agent:arch` + `status:ready`. You already picked it up during polling.

1. Read the issue title + body carefully
2. Claim it: `bash scripts/claims.sh "{REPO_SLUG}" {N} "{AGENT_ID}"`

### Phase 2: Context

1. List existing open issues:
   ```bash
   gh issue list --repo {REPO_SLUG} --state open --json number,title,labels --jq '.[]'
   ```
2. **Read arch.md first** — if `arch.md` exists at repo root, read it. This is your persistent map:
   - Domain model, bounded contexts, aggregate roots
   - System architecture, tech stack, data flow
   - API contracts
   - User journey map
   - Product roadmap context, known tech debt
   - If `arch.md` doesn't exist → you must create it as part of this task (see `cases/arch-md-template.md`)
3. Read `README.md`, `package.json`, folder structure
4. Read past journal entries

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
  "title": "{Role}: {what changes}",
  "labels": ["agent:{role}", "status:ready"],
  "body": "## Task\n...\n## Acceptance Criteria\n- [ ] ...\n## Technical Notes\n...\n\n<!-- deps: {N} -->"
}
```

**Decomposition rules:**
- BE before FE (APIs before UI that consumes them)
- Schema/migration before business logic
- Include QA verification task for testable deliverables
- If FE needs specific component patterns, note it in Technical Notes (but don't dictate implementation)
- **Don't over-specify how** — specify **what** and **done when**. Let the specialist decide how.

### Phase 5: Create

Create each task as a GitHub issue in dependency order:

```bash
gh issue create --repo {REPO_SLUG} \
  --title "{Role}: {title}" \
  --label "agent:{role}" --label "status:ready" \
  --body "{spec with acceptance criteria and <!-- deps: N --> if needed}"
```

For issues with unmet dependencies, use `status:blocked` instead of `status:ready`.

Collect issue numbers for the report.

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

Close the original request issue and comment with the decomposition:

```bash
gh issue comment {N} --repo {REPO_SLUG} \
  --body "Decomposed into: #A, #B, #C, ..."
bash scripts/route.sh "{REPO_SLUG}" {N} done "{AGENT_ID}"
```

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

## Mode D: Triage (completed work routed back from other agents)

ARCH is the sole merge authority and dispatcher. When any agent (FE, BE, QA, Design, OPS, DEBUG) completes work, they set `agent_type: arch` + `status: ready`. ARCH picks it up here.

### Phase 0: Pre-triage (MANDATORY — run before ANY judgment)

**Run these scripts first. They handle all deterministic cases automatically. Do NOT skip this step. Do NOT manually handle cases that the scripts already cover.**

```bash
# 1. Unblock issues whose deps are all resolved
bash actions/scan-unblock.sh "{REPO_SLUG}"

# 2. Check for completed requests (all sub-issues done)
bash actions/scan-complete-requests.sh "{REPO_SLUG}"

# 3. Auto-handle deterministic triage cases
bash scripts/pre-triage.sh "{REPO_SLUG}"
```

`pre-triage.sh` automatically handles:
- **QA PASS + PR open → merge + close** (no judgment needed)
- **QA PASS + PR merged → close** (no judgment needed)
- **Design APPROVED + QA PASS → merge + close** (no judgment needed)
- **PR delivered + no verdict → route to QA** (no judgment needed)

It prints which issues remain for your judgment. **Only process those remaining issues in Phase 1.**

### Phase 1: Classify the Remaining Issues

Read the issue and all comments:

```bash
gh issue view {N} --repo {REPO_SLUG} --comments
```

**Classify by scanning comments in reverse order (newest first).** Check these signals in this exact priority:

```bash
# 1. Check for QA verdict (highest priority)
QA_VERDICT=$(gh issue view {N} --repo {REPO_SLUG} --json comments \
  --jq '[.comments[].body | select(test("Verdict:.*PASS|Verdict:.*FAIL"))] | last // empty')

# 2. Check for Design verdict
DESIGN_VERDICT=$(gh issue view {N} --repo {REPO_SLUG} --json comments \
  --jq '[.comments[].body | select(test("Verdict:.*APPROVED|Verdict:.*NEEDS CHANGES"))] | last // empty')

# 3. Check if a PR exists
PR_EXISTS=$(gh pr list --repo {REPO_SLUG} --search "closes #{N}" --json number --jq '.[0].number // empty')
```

**Classification rules (check in this order — first match wins):**

| Priority | Signal | Classification |
|----------|--------|---------------|
| 1 | QA_VERDICT contains "PASS" | **QA PASS → decide merge or route to Design** |
| 2 | QA_VERDICT contains "FAIL" | **QA FAIL → route to implementer** |
| 3 | DESIGN_VERDICT contains "APPROVED" | **Design APPROVED → merge** |
| 4 | DESIGN_VERDICT contains "NEEDS CHANGES" | **Design rejected → route to implementer** |
| 5 | PR exists + no verdict comments | **Implementation delivered → route to QA** |
| 6 | No PR + report in comments | **Audit report → decompose into tasks** |
| 7 | Issue has `<!-- deps: N -->` | **Check if unblockable** |

**CRITICAL: All routing MUST go through `scripts/route.sh`. Do NOT use raw `gh issue edit` for label changes. The script enforces validation rules that prevent re-routing loops.**

### Phase 2: Act on Remaining Issues

> **QA PASS → merge** and **PR delivered → route to QA** are already handled by `pre-triage.sh`. You should NOT see these cases here. If you do, run `pre-triage.sh` again.

> **Design superseding PRs**: If Design opened a NEW PR (instead of just reviewing the existing one), close the older FE PR before merging the Design PR. Check: `gh pr list --repo {REPO_SLUG} --search "closes #{N}"` — if multiple PRs target the same issue, merge the newest, close the rest.

#### QA Verdict: FAIL

Read QA's triage assessment. Route to the appropriate role:

```bash
bash scripts/route.sh "{REPO_SLUG}" {N} {fe|be|ops|debug} "{AGENT_ID}"
```

Choose the role based on QA's triage: UI/component → `fe`, API/DB → `be`, CI/infra → `ops`, unclear → `debug`.

#### Design Verdict: NEEDS CHANGES

Route back to the implementing role with Design's feedback:

```bash
bash scripts/route.sh "{REPO_SLUG}" {N} {fe|be|ops} "{AGENT_ID}"
```

#### Implementation Delivered (no review yet)

```bash
bash scripts/route.sh "{REPO_SLUG}" {N} qa "{AGENT_ID}"
```

#### Audit Report (no PR, findings in comments)

QA or Design completed an audit task. Read the report and decompose findings into actionable fix tasks:

1. Read the report comment carefully — note severity (Critical/P0 > Major/P1 > Minor/P2)
2. Group related findings into coherent fix tasks (e.g. "all Header dark mode issues" = 1 task)
3. Create new issues via `gh issue create`:
   ```bash
   gh issue create --repo {REPO_SLUG} \
     --title "{role}: {title}" \
     --label "agent:{role}" --label "status:ready" \
     --body "{spec with acceptance criteria}"
   ```
4. Each new issue must have: clear spec, acceptance criteria, correct `agent:*` label
5. Close the audit issue:
   ```bash
   bash scripts/route.sh "{REPO_SLUG}" {N} done "{AGENT_ID}"
   ```

**Prioritization rule**: Create tasks in severity order. Critical/P0 tasks get `status:ready` immediately. P2/nice-to-have can be batched or deferred.

#### Blocked Task Unblocking

Check if the dependency is now resolved:

```bash
# Parse <!-- deps: M --> from issue body, check if #M is done
gh issue view {M} --repo {REPO_SLUG} --json state,labels
```

If the dependency is complete, unblock and set ready:

```bash
gh issue edit {N} --repo {REPO_SLUG} \
  --remove-label "status:blocked" --add-label "status:ready"
```

### Phase 3: Update arch.md

If triage revealed new domain knowledge, architectural concerns, or tech debt → update `arch.md`.

### Phase 4: Journal

Record: what came back, what decision you made and why, any patterns across reports.

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
bash scripts/route.sh "{REPO_SLUG}" {N} {original_type} "{AGENT_ID}"
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
