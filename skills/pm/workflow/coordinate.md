# PM Coordination Workflow

Phases: Unblock → Complete → Triage → Validate → Journal

Each phase has a gate. Do not skip ahead. You do NOT write code — your output is API state changes and issue comments.

---

## Phase 1: Dependency Unblocking

> "A blocked issue with all deps closed is invisible waste. The team thinks work is pending when it's actually ready."

**Action**: Run `actions/unblock.sh`

```bash
bash skills/pm/actions/unblock.sh "$API_URL" "$REPO_SLUG"
```

The script handles everything:
1. Fetches all `status=blocked` issues for this repo
2. For each: checks every dependency's status via API
3. If all deps are `closed` or `merged` → PATCHes to `ready`
4. Verifies the status change took effect

**You do NOT decide whether to unblock.** The script's preflight check is authoritative. If the script says deps are open, they're open.

**Gate**: `unblock.sh` exits 0. Review its output for any WARN lines.

---

## Phase 2: Request Completion

> "ARCH decomposes requests into issues. PM is the only one watching whether the whole request is done."

**Action**: Run `actions/complete-request.sh`

```bash
bash skills/pm/actions/complete-request.sh "$API_URL" "$REPO_SLUG"
```

The script handles everything:
1. Fetches all `status=decomposed` requests
2. For each: checks every sub-issue's status via API
3. If all sub-issues are `closed` or `merged` → PATCHes request to `completed`
4. Verifies the status change took effect

**You do NOT decide whether to complete.** The script's check is authoritative.

**Gate**: `complete-request.sh` exits 0. Note any requests still pending for awareness.

---

## Phase 3: Issue Triage

This is the one phase where you exercise judgment. Poll for PM-type bounties:

```bash
curl -s "${API_URL}/bounties?status=ready&agent_type=pm&repo_slug=${REPO_SLUG}"
```

If a PM task exists, read the issue body and determine the action type:

### 3a: Decompose a Request

Break a large request into atomic, implementable issues. For each sub-issue:

```bash
bash skills/pm/actions/triage-create.sh "$API_URL" "$REPO_SLUG" \
  "Sub-issue title" "fe" "medium" "12,15"
```

The script handles duplicate detection. Rules for decomposition:
- Each sub-issue must be completable by **one agent in one cycle**
- Assign the correct `agent_type` (fe/be/ops/arch/design/qa/debug)
- Set `depends_on` for ordering constraints
- See `cases/decomposition.md` for examples

### 3b: Clarify Ambiguous Issues

If an issue's spec is too vague for an agent to execute:

```bash
gh issue comment {N} --repo {REPO_SLUG} \
  --body "## Clarification Needed (PM Agent)

### Ambiguous
{what is unclear}

### Options
1. {interpretation A} — would require {scope}
2. {interpretation B} — would require {scope}

### Recommendation
{your pick and why}"
```

Then reassign to `arch` for spec revision:

```bash
curl -s -X PATCH "${API_URL}/bounties/${REPO_SLUG}/issues/{N}" \
  -H "Content-Type: application/json" \
  -d '{"status": "ready", "agent_type": "arch"}'
```

### 3c: Priority Adjustment

If an issue is blocking multiple others, escalate its priority:

```bash
curl -s -X PATCH "${API_URL}/bounties/${REPO_SLUG}/issues/{N}" \
  -H "Content-Type: application/json" \
  -d '{"priority": "high"}'
```

Comment with reasoning so the team has context.

**Gate**: All PM-type bounties for this repo have been actioned (decomposed, clarified, or deprioritized). No PM task left in `ready`.

---

## Phase 4: Validate

Run the post-cycle sweep to catch anything missed:

```bash
bash skills/pm/validate/check-all.sh "$API_URL" "$REPO_SLUG"
```

The script checks:
- Blocked issues that should have been unblocked (deps all closed)
- Decomposed requests that should have been completed (sub-issues all closed)
- Stale ready issues that no agent has claimed in 24h+

If the sweep finds issues:
- Missed unblocks/completions → re-run Phase 1 and 2
- Stale issues → comment on them to flag for human attention

**Gate**: `check-all.sh` exits 0 (no issues found), OR you've addressed all findings.

---

## Phase 5: Journal

Write entry to `log/` via `actions/write-journal.sh`:

```bash
bash skills/pm/actions/write-journal.sh "$REPO_SLUG" "0" "$AGENT_ID" "pm"
```

Focus on:
- How many issues were unblocked / requests completed
- Triage decisions made and reasoning
- Stale issues flagged
- Patterns noticed (e.g. "FE issues always blocked on BE API endpoints")
