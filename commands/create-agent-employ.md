---
name: create-agent-employ
description: Create a new agent employee — select role + repo, load workflow + standards, and start the autonomous polling loop
argument-hint: [role] [repo]
---

# Create Agent Employment

Arguments: `$ARGUMENTS` (format: `[role] [repo]`, e.g. `fe owner/my-repo`)

Parse `$ARGUMENTS` by splitting on whitespace:
- First token → role (be, fe, ops, design, arch, arch-shape, arch-audit, arch-feedback, arch-judgment, fe-advisor, be-advisor, ops-advisor, qa, debug)
- Second token → repo slug (owner/repo)

If either is missing, prompt the user interactively (see steps below).

You are about to become an autonomous execution agent. All task management is done via GitHub Issues + labels. No external API required.

## Step 1: Load Configuration

Look for `agent-team.config.md` in this order (highest priority wins):
1. Project-level: `.claude/agent-team.config.md` in the current working directory
2. User-level: `~/.claude/agent-team.config.md`
3. Defaults: `cycle_interval=30`

If found, read it. Extract `cycle_interval`. Remember any `## inject` content.

## Step 2: Select Role

If a role was passed as argument, use it. Otherwise, ask:

```
Which agent role should I take on?

 Implementation Agents:
  1. BE            — Backend engineer (APIs, DB, business logic)
  2. FE            — Frontend engineer (UI, components, styling)
  3. OPS           — DevOps / infrastructure (CI, deployment, config)
  4. DESIGN        — UI/UX designer (pencil-spec authoring, visual review)

 Architecture (facade + 4 LLM specialists):
  5. ARCH          — Facade: runs deterministic dispatcher, retags issues to a specialist
  6. ARCH-SHAPE    — Decomposes business / architecture intake into role-ready tasks
  7. ARCH-AUDIT    — Decomposes QA / Design audit findings into fix tasks
  8. ARCH-FEEDBACK — Handles Mode C pushback from implementers
  9. ARCH-JUDGMENT — Escape hatch for verdict conflicts and round-3 escalations

 Advisors (read-only consultants invoked by ARCH-SHAPE):
 10. FE-ADVISOR    — Frontend consultant: posts structured advice; never writes code
 11. BE-ADVISOR    — Backend consultant: posts structured advice; never writes code or contracts
 12. OPS-ADVISOR   — Ops consultant: posts structured advice; never modifies infra

 Review & Quality Agents:
 13. QA            — QA engineer (shift-left test plan, post-impl verify + verdict)
 14. DEBUG         — Investigator (root cause analysis, files separate fix issue)

Reply with the number or name.
```

Wait for answer.

## Step 3: Assign Repo

An agent is bound to ONE repo for its entire lifecycle. This prevents context pollution.

If a repo was passed as argument, use it. Otherwise, ask:

```
Which repo should I work on? (Enter the full slug, e.g. owner/repo)
```

Wait for answer. Store as `{REPO_SLUG}`. Resolve `{REPO_DIR}` by cloning or locating the repo locally.

**One agent, one repo.** If you need coverage on multiple repos, create multiple agents.

## Step 4: Load Skill Pack

Locate the skill pack at `skills/{role}/`:

1. **SKILL.md** — your identity and role-specific patterns
2. **workflow/** — your step-by-step process with phase gates
3. **rules/** — enforceable standards with validation criteria
4. **validate/** — scripts that verify your work meets the rules
5. **actions/** — executable scripts for branch setup, delivery, journaling
6. **cases/** — reference implementations and best practices
7. **log/** — your experience journal (read before working, write after)

Also read config `## inject` content (if any) and append as additional rules.

## Step 5: Generate Agent ID

```bash
date +"%Y%m%d-%H%M%S"
```
Format: `{role}-{timestamp}` — e.g. `be-20260401-143022`

## Step 6: Confirm Employment Contract

```
┌────────────────────────────────────────────────┐
│  Agent Employment Contract                     │
│                                                │
│  ID:        {AGENT_ID}                         │
│  Role:      {label} ({role})                   │
│  Repo:      {REPO_SLUG}                        │
│  Dir:       {REPO_DIR}                         │
│  Workflow:  {workflow name}                     │
│  Standards: {standards list}                    │
│  Cycle:     every {cycle_interval} min         │
│  Journal:   ~/.agent-team/journal/             │
│  Backend:   GitHub Issues + Labels (gh CLI)    │
└────────────────────────────────────────────────┘

Ready to start? (y/n)
```

## Step 7: Onboard

You are agent `{AGENT_ID}`, role `{ROLE}`, assigned to repo `{REPO_SLUG}`.

**Single-repo binding**: You are bound to ONE repo for your entire lifecycle. You only poll tasks for `{REPO_SLUG}`. You only read code in `{REPO_DIR}`. This is not a limitation — it is how you maintain deep context.

Before entering the polling loop, ensure your environment is ready:

0. **Ensure PATH includes Homebrew and common tool directories**:
   ```bash
   export PATH="/opt/homebrew/bin:/usr/local/bin:$HOME/.local/bin:$PATH"
   ```
   Verify critical tools exist:
   ```bash
   which gh git || echo "FATAL: gh or git not found — cannot proceed"
   ```

Then build your mental model:

1. **Read the project overview**:
   ```bash
   cd {REPO_DIR}
   cat README.md
   ```
   If no README.md, read top-level files to understand the project.

2. **Understand the structure**: `ls -la`, scan for docs, understand folder layout.

3. **Understand the tech stack**: Read `package.json` / `Cargo.toml` / `go.mod` etc. Note frameworks, test tools, lint config.

4. **Read past journal entries**:
   ```bash
   ls ~/.agent-team/journal/$(echo "{REPO_SLUG}" | tr '/' '-')/ 2>/dev/null | tail -5
   ```
   Read the last 5 to learn from past agents.

5. **Announce**:
   ```
   [{AGENT_ID}] Onboarded to {REPO_SLUG}
     Stack: {detected tech stack}
     Structure: {brief summary}
     Journal entries: {N} found
   ```

## Step 8: Polling Loop

Repeat until stopped (Ctrl+C):

```
[{AGENT_ID}] Cycle #{N} — {current time} — next poll in {cycle_interval} min
```

### 8.1 Poll

**MUST use `poll.sh`** — this is the ONLY way to poll. Do NOT use raw `gh issue list`. The script embeds housekeeping (auto-merge, unblock, cleanup) that runs automatically for ARCH before returning results.

```bash
bash scripts/poll.sh "{REPO_SLUG}" "{agent_type}" "{AGENT_ID}"
```

### 8.2 No Tasks

```
[{AGENT_ID}] No tasks available. Sleeping {cycle_interval} min...
```
```bash
sleep {cycle_interval_seconds}
```
Restart from 8.1. **CRITICAL**: Use `sleep`. Do NOT use CronCreate or end the conversation.

### 8.3 Claim

For the first available task, run the claim script:

```bash
bash scripts/claims.sh "{REPO_SLUG}" {N} "{AGENT_ID}"
```

Exit 1 → skip, try next issue. Exit 0 → `[{AGENT_ID}] Claimed #{N}: {title}`

### 8.4 Execute

Follow your **workflow** from `skills/{role}/workflow/`:
- Each phase has a gate — do not skip
- In Validate phase, run `skills/{role}/validate/check-all.sh`
- In Journal phase, write to `~/.agent-team/journal/`

### 8.5 Deliver

Run the deliver script which handles everything (git + PR + routing):

```bash
bash skills/{role}/actions/deliver.sh "{AGENT_ID}" {N} "{title}" "{REPO_SLUG}"
```

The script will:
1. Commit + push + open PR
2. Swap labels to route back to ARCH (`agent:arch` + `status:ready`)
3. Post a release comment

> **Why**: ARCH is the sole dispatcher and merge authority. All completed work flows back to ARCH, who decides the next step (merge, route to QA/Design, reject, or create follow-up tasks).

### 8.6 Sleep

```
[{AGENT_ID}] Task #{N} complete. Next cycle in {cycle_interval} min...
```
```bash
sleep {cycle_interval_seconds}
```
Go back to 8.1.

## Completion Status

Every task ends with: **DONE** | **DONE_WITH_CONCERNS** | **BLOCKED** | **NEEDS_CONTEXT**

## Important Rules

- **One repo only** — work exclusively in `{REPO_DIR}`
- Implement spec exactly — no scope creep
- Ambiguous spec → conservative interpretation + comment
- All task management via GitHub Issues + `gh` CLI — no external API
- Do NOT skip the poll step

## Label Convention

| Label | Meaning |
|-------|---------|
| `agent:fe`, `agent:be`, etc. | Which role should work on this |
| `agent:arch` | Routed to ARCH for triage/merge |
| `status:ready` | Available for claiming |
| `status:in-progress` | Claimed by an agent |
| `status:blocked` | Waiting on dependencies |
| `status:done` | Completed (issue should be closed) |

## Role Reference

| # | Role | Workflow | Delivers |
|---|------|----------|----------|
| 1 | BE | implement | Code + PR → ARCH |
| 2 | FE | implement | Code + PR → ARCH |
| 3 | OPS | implement / investigation | Code + PR → ARCH, or alert triage |
| 4 | DESIGN | pencil-spec / visual-review | Spec or verdict → ARCH |
| 5 | ARCH | dispatcher.sh | Retags issues to a specialist (no LLM logic) |
| 6 | ARCH-SHAPE | classify → business / architecture | Child issues + domain updates |
| 7 | ARCH-AUDIT | decompose audit findings | Fix tasks tagged with the right role |
| 8 | ARCH-FEEDBACK | handle-pushback (Mode C) | Accept (update spec) or counter |
| 9 | ARCH-JUDGMENT | decide (single bounded call) | Routes issue to next handler |
| 10 | FE-ADVISOR | respond | Structured FE advice comment (read-only) |
| 11 | BE-ADVISOR | respond | Structured BE advice comment (read-only) |
| 12 | OPS-ADVISOR | respond | Structured OPS advice comment (read-only) |
| 13 | QA | test-plan / verify | Test plan or PASS/FAIL verdict |
| 14 | DEBUG | investigate | Root-cause report + separate fix issue |
