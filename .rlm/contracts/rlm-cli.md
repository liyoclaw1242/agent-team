---
type: contract
name: rlm-cli
contract_kind: integration
status: active
versioning: semver
producer: the rlm CLI (tools/rlm/, Python via uv)
consumers:
  - Hermes (all skills via Bash tool)
  - Worker (via Bash tool, web-stack skill profile)
  - Dispatch (DeliveryOrchestrator script)
  - WhiteBoxValidator (read-only subcommands)
  - BlackBoxValidator (read-only subcommands)
  - Arbiter (label-only subcommands)
  - Supervision (read + enqueue-message only)
  - CI (fact-commit check verifies via git log; doesn't invoke CLI itself)
created: 2026-05-12
---

# rlm-cli

The unified CLI through which **all RLM writes** flow. Producers: every agent in the system + Dispatch. Consumers (of the CLI output): same set (they read each other's writes), plus CI checks, plus humans via `gh` / `git log`. The CLI is the single source of truth for *how* to write to RLM; agents call it, they don't bypass it.

This contract documents the **invocation surface, schemas, error model, and per-subcommand behaviour**. It is the source of truth that the Python implementation in `tools/rlm/` must match. When the implementation and this contract disagree, **the contract wins** — fix the implementation, or open a PR to amend the contract.

---

## Architecture

```
agent (Hermes / Worker / Dispatch / Validator / Arbiter / Supervision)
   │
   │ runs: rlm <subcommand> [flags]
   ▼
rlm CLI (Python, uv-managed, installed at tools/rlm/)
   │
   ├─ Authz: env-var RLM_AGENT_ROLE × subcommand permission table
   ├─ Locate: walk up from CWD until `.rlm/` (or --rlm-root override)
   ├─ Validate: required-field check on body (frontmatter / Issue body / labels)
   ├─ Route: PR / direct-commit / Issue create / Issue relabel / Issue comment
   │  ├─ PR-routed     → git branch + commit + gh pr create (uses CLI's GitHub token)
   │  ├─ direct-commit → git add + git commit + git push to main
   │  └─ Issue-routed  → gh issue create / gh issue edit --add-label
   ├─ Emit triple: ADR-0011 6-field JSON line → Redis stream `rlm:events` + JSONL `.local/events.jsonl`
   └─ Output: stdout JSON if --json, else human-readable; exit code per error model
```

The CLI **holds the GitHub token**; agents do not. The CLI **holds Redis credentials**; agents do not. This is what "PR-routed" / "direct-commit" / "Issue-routed" means in practice — agents pass intent, the CLI executes against external systems on their behalf with the right creds.

---

## Invocation conventions

### Shape

```sh
rlm <subcommand> [global-flags] [subcommand-flags]
```

Long-form flags only. No `-x` short options. (Rationale: skills generate CLI invocations from prompts; long forms are unambiguous and grep-friendly. Short forms invite typos that pass type-check.)

### Body input

Subcommands that need a markdown body (e.g., `commit-spec`, `propose-adr`, `add-contract`) accept it via **one of**:

- **stdin** — `cat foo.md | rlm <cmd> ...` — preferred for piping
- **`--body-file <path>`** — file path, relative or absolute
- **`--body <inline-string>`** — for short bodies only (≤500 chars); CLI emits a deprecation hint at >200 chars

Subcommands that take frontmatter-only data (e.g., labels, slugs) use named flags:

- `--issue <number>`
- `--title <string>`
- `--slug <kebab-case>`
- `--signal-ref <issue-number>`
- `--adr-refs <comma-separated>` (e.g., `--adr-refs 0001,0002`)

### `.rlm/` discovery

The CLI must locate `.rlm/` before any write. Order:

1. `--rlm-root <path>` if explicitly set (must exist; absolute or relative)
2. Walk up from `$PWD` until a directory contains `.rlm/`; that directory is the **repo root**
3. If still not found, exit with code 4 (no-rlm-root) — see error model

The repo root is also `git rev-parse --show-toplevel` for commit operations.

### Global flags

Available on every subcommand:

| Flag | Purpose |
|---|---|
| `--json` | machine-readable output to stdout (single JSON object, one line); errors still go to stderr |
| `--rlm-root <path>` | override walk-up discovery |
| `--dry-run` | log what would happen + emit a *dry-run triple*, but make no external changes (no git commit, no gh call, no Redis write). Useful for skill testing. |
| `--quiet` | suppress human-readable progress lines (still emit final result + errors) |
| `--verbose` | extra diagnostic to stderr (NOT stdout — keeps `--json` clean) |

Subcommand-specific flags listed in the [Subcommand reference](#subcommand-reference) section.

### Output

**Human-readable (default)**:
```
✓ Issue #143 created (type:spec status:draft)
  body bytes: 1247
  triple_id: ev_2026-05-12T09:53:12Z_abc123
```

**`--json` mode**: single JSON object on one line to stdout (no surrounding whitespace). Schema differs per subcommand; see each subcommand's spec.

**On error**: nothing on stdout. Error JSON to stderr (one line) + non-zero exit code:
```json
{"error":"missing_required_field","field":"acceptance_criteria","exit_code":2}
```

---

## Caller identity

### Mechanism (v1)

Env var **`RLM_AGENT_ROLE`** is required on every write subcommand. Read subcommands tolerate it being absent (default: anonymous-reader).

Valid values:

- `hermes` (intake-domain skill running)
- `hermes-design` (design-domain skill running — same agent, different access)
- `worker`
- `dispatch`
- `whitebox-validator`
- `blackbox-validator`
- `arbiter`
- `supervision`

Missing or invalid → exit code 3 (permission-error).

Additional optional env vars:

- `RLM_AGENT_INVOCATION` — UUID for the current LLM `claude -p` invocation; used to build `parent_triple_id` chains for triples emitted during this invocation. Skills should generate at start of invocation (e.g., `uuidgen`) and export before any `rlm` call.
- `RLM_SKILL_NAME` — name of the skill currently active (e.g., `business-model-probe`). Used in triple emission for richer audit.

### Why env var, not signed token

v1 threat model: agents run in sandboxed `claude -p` invocations supervised by Dispatch / hermes-agent. Spoofing the env var requires breaking out of the sandbox, in which case the system has bigger problems. v2 may add HMAC-signed tokens if the threat model expands (e.g., agents running on different hosts).

### Permission table

Per [ADR-0009](../adr/0009-resource-access-boundaries.md). Subcommands a role may call:

| Role | Allowed subcommands |
|---|---|
| `hermes` | `propose-context-change`, `append-business-model`, `append-deployment-constraints`, `commit-spec`, `confirm-spec`, `commit-workpackage`, `approve-workpackage`, `record-signal`, `mark-superseded`, `enqueue-message` + all read subcommands |
| `hermes-design` | above + `propose-adr`, `add-contract` (design-domain skills only); excludes intake-only writes |
| `worker` | `append-fact`, `supersede-fact`, `open-pr`, comment-on-own-issue (planned subcommand TBD), `enqueue-message` (only `kind=worker-self-decline` per Arbiter contract) + all reads |
| `dispatch` | `mark-in-progress`, `mark-delivered`, label flips on assigned WP, `enqueue-message` + all reads |
| `whitebox-validator` | reads + comment-on-own-issue (no writes to RLM markdown) |
| `blackbox-validator` | reads (Spec only; CLI enforces) + comment-on-own-issue |
| `arbiter` | label flips on assigned WP, comment-on-own-issue, `enqueue-message` (no markdown writes) |
| `supervision` | reads + `enqueue-message --kind=supervision-alert` |

Calling a forbidden subcommand → exit code 3 (permission-error).

The CLI enforces this in code, not by convention. The mapping is hard-coded; changes require a CLI release.

---

## Triple emission (ADR-0011)

### When

- **Once per subcommand invocation** — summary triple at exit time
- **Per discrete external action** within an invocation (file write, git commit, gh call, Issue label flip) — sub-triples chained off the summary via `parent_triple_id`

A `--dry-run` invocation emits a triple with `dry_run: true` field and skips all external actions.

### Format

Single JSON object per line, no surrounding whitespace. Six required fields per ADR-0011 plus operational metadata:

```json
{
  "triple_id": "ev_2026-05-12T10:23:45.123Z_abc123",
  "timestamp": "2026-05-12T10:23:45.123Z",
  "action": "rlm.commit-spec",
  "reasoning": "Confirmed Signal #142 → drafting Spec per signal-to-spec skill",
  "basis": [
    {"kind": "issue", "ref": "#142"},
    {"kind": "rlm", "ref": ".rlm/business/business-model-2026-05-12.md"},
    {"kind": "discord-thread", "ref": "thread-id-abc"}
  ],
  "agent_id": "hermes",
  "parent_triple_id": "ev_2026-05-12T10:22:01.456Z_parent",
  "affected_resources": [
    {"kind": "issue", "ref": "#143", "verb": "created"}
  ],
  "skill_name": "signal-to-spec",
  "invocation_id": "inv_abc-def-ghi",
  "exit_code": 0,
  "dry_run": false
}
```

### Sinks

The CLI writes each triple to BOTH:

1. **Redis stream `rlm:events`** — `XADD rlm:events * <json>`. Consumers: Supervision (reads for basis verification + anomaly detection), Arbiter (reads the previous agent's triples on post-condition failure), Dispatch (reads to recover state if it crashes mid-cycle).
2. **JSONL `.local/events.jsonl`** — append-only, single file. Durable archive (Redis may evict old stream entries; JSONL is forever). Used for post-hoc audit + replay.

If Redis is unreachable: write JSONL only, emit a stderr warning, increment a `triple_emission_failures` counter (visible via `--verbose`). Don't fail the subcommand — the work happened; the triple log degraded.

If JSONL is unwritable (disk full / permissions): exit code 5 (state-write-error). The action did not happen; rollback any partial external changes.

### `basis` references

Each basis is `{kind, ref}`:

| `kind` | `ref` format | Example |
|---|---|---|
| `issue` | `#<number>` | `#143` |
| `pr` | `#<number>` | `#146` |
| `rlm` | `.rlm/<path>` (no leading `./`) | `.rlm/adr/0008-hermes-scope-lifecycle-governance.md` |
| `code` | `<file>:<line>` or `<file>:<range>` | `src/calendar-widget/index.tsx:42` |
| `discord-thread` | `thread-id-<id>` | `thread-id-abc123` |
| `discord-message` | `<thread-id>/<msg-id>` | `thread-abc/msg-xyz` |
| `triple` | `<triple_id>` | `ev_2026-...` |
| `fact` | `.rlm/facts/<filename>` | `.rlm/facts/2026-05-12-scaffold.md` |
| `commit` | git sha (short or long) | `abc123de` |

Supervision's mechanical basis verifier (per ADR-0012) checks that cited refs exist. Missing refs trigger alerts (don't fail the subcommand — observability is non-blocking).

---

## Error model

### Exit codes

| Code | Name | Meaning | When |
|---|---|---|---|
| `0` | ok | Success | All good |
| `1` | usage-error | Bad CLI invocation (unknown flag, conflicting flags) | Wrong args |
| `2` | validation-error | Body / frontmatter / labels failed schema check | Required field missing, wrong type, malformed YAML |
| `3` | permission-error | Caller role not allowed for this subcommand | Per ADR-0009 |
| `4` | no-rlm-root | Couldn't locate `.rlm/` | Walk-up failed and no `--rlm-root` |
| `5` | state-write-error | External write failed (git, gh, redis, JSONL) | Network issue, auth issue, disk full |
| `6` | precondition-failed | Subcommand-specific gate failed | e.g., `approve-workpackage` found unmerged ADR ref; `commit-spec` found duplicate `signal_ref` |
| `7` | conflict | Concurrent-write conflict (rare; CLI tries to handle internally) | Two agents wrote same Issue label simultaneously |
| `8` | external-service-down | GitHub / Redis / git remote unreachable; transient | Network timeout |
| `99` | internal-error | Unexpected CLI bug | Bug — open Issue with stderr trace |

### Error output

Always single-line JSON on **stderr**, even when `--json` is not set. Schema:

```json
{
  "error": "<error-name>",
  "exit_code": <int>,
  "message": "<human-readable>",
  "field": "<optional, for validation errors>",
  "subcommand": "<name>",
  "details": { /* optional extra context */ }
}
```

Example:
```json
{"error":"precondition-failed","exit_code":6,"message":"adr_refs contains unmerged ADRs","subcommand":"approve-workpackage","field":"adr_refs","details":{"unmerged":[2,3]}}
```

Exit codes are **stable** — agents pattern-match on them. The `message` field is human-readable and may change.

### Retries

Exit code 8 (external-service-down) is the only one agents should retry. All others are deterministic — retrying won't help. CLI itself retries internally for transient git/network issues (3 attempts with exponential backoff) before surfacing 8.

---

## Frontmatter schemas (markdown files written by CLI)

All written markdown files have YAML frontmatter delimited by `---` lines. The CLI generates frontmatter; agents do not hand-author it. The body (below frontmatter) is the agent's content.

### `.rlm/adr/NNNN-slug.md` (written by `propose-adr`)

```yaml
---
type: adr
adr_number: 18
slug: rlm-cli-spec
status: proposed
created: 2026-05-12
deciders: [liyo]
supersedes: null
superseded_by: null
related_adrs: [0004, 0011]
---

# <body — H1 title + sections per .rlm/adr/* convention>
```

**Note**: existing 17 ADRs were authored manually before this spec and have **no frontmatter**. The CLI does **not** retroactively add frontmatter to them. The CLI adds frontmatter to *new* ADRs only. Existing ADRs are referenced by `adr_number` derived from filename prefix.

### `.rlm/contracts/<slug>.md` (written by `add-contract`)

```yaml
---
type: contract
name: <slug>
contract_kind: api | event | schema | integration
status: active | superseded
versioning: semver | additive-only | breaking-allowed
producer: <module name>
consumers: [<list>]
created: 2026-05-12
supersedes: null
superseded_by: null
---

# <body per draft-contract skill template>
```

### `.rlm/facts/YYYY-MM-DD-slug.md` (written by `append-fact` / `supersede-fact`)

```yaml
---
type: fact
fact_id: 2026-05-12-scaffold
last_verified: 2026-05-12T10:23:45Z
verified_by_commit: abc123de
about:
  - kind: code
    ref: package.json:1-50
  - kind: code
    ref: app/layout.tsx
supersedes: null      # or `2026-04-12-old-scaffold` if this fact replaces a prior one
superseded_by: null   # populated by supersede-fact in the new fact
status: active | superseded
---

# <body — describes the fact in prose; e.g., "Next.js 14 App Router project structure">
```

Facts are **append-only**. `supersede-fact` writes a *new* file with `supersedes` set, AND updates the old file's `superseded_by` field in place (the only frontmatter field that can change post-write).

### `.rlm/business/business-model-YYYY-MM-DD.md` (written by `append-business-model`)

```yaml
---
type: business-model
snapshot_date: 2026-05-12
signal_ref: 142
author_invocation: inv_abc-def
supersedes_dim:  # optional — names dimensions this snapshot updates vs prior
  - wedge
  - target
---

# <body — wedge / target / status quo / demand reality / future fit narrative>
```

### `.rlm/business/deployment-constraints-YYYY-MM-DD.md` (written by `append-deployment-constraints`)

```yaml
---
type: deployment-constraints
snapshot_date: 2026-05-12
signal_ref: 142
budget:
  monthly_cap_usd: 10
  free_tier_required: true
region: Taiwan
compliance: []        # empty list = none
vendor_preferences: open
operations: managed_only
notes: ""
---

# <optional prose body for context>
```

### `.rlm/bc/<bc>/CONTEXT.md` and `.rlm/CONTEXT-MAP.md` (edited by `propose-context-change`)

These files are edited, not written from scratch. The CLI takes a unified diff via stdin / `--diff-file` and produces a PR. Frontmatter (if any) is preserved as-is.

---

## Issue body schemas (GitHub workflow items)

Workflow items live as GitHub Issues. The CLI generates the Issue body (markdown + frontmatter). Once created, the body is mutable until the gate fires; after that it is immutable (enforcement is convention + Supervision alerting; not CLI-enforced because GitHub doesn't support body-locking).

### `type:signal` Issue (written by `record-signal`)

```markdown
---
type: signal
status: draft
source: human | production-monitor | hermes
created: 2026-05-12T10:23:45Z
related_threads: ["thread-id-abc"]
---

# <title>

<body — what the signal is; raw input>

## Refs

- Discord thread: <permalink>
- (for production-monitor signals) Provider dashboard: <link>
```

Labels at create: `type:signal`, `status:draft`.

### `type:spec` Issue (written by `commit-spec`)

```markdown
---
type: spec
status: draft     # CLI sets; confirm-spec flips to confirmed
signal_ref: 142
business_model_ref: .rlm/business/business-model-2026-05-12.md
deployment_constraints_ref: .rlm/business/deployment-constraints-2026-05-12.md  # optional
acceptance_criteria_count: 3
auto_confirmed: false   # set true if confirm-spec fired via timeout, not explicit yes
---

# <imperative title>

<one-sentence outcome statement>

## AcceptanceCriteria

- [ ] <ac 1 with measurement + window>
- [ ] <ac 2>
- [ ] <ac 3>

## Business context

<2-3 sentences>

## Refs

- Originating Signal: #<signal-number>
- Discord thread: <permalink>
```

Labels at create: `type:spec`, `status:draft`. After `confirm-spec`: `status:confirmed` (replacing `draft`).

### `type:workpackage` Issue (written by `commit-workpackage`)

```markdown
---
type: workpackage
status: draft
parent_spec: 143
worker_class: web-stack
adr_refs: [1, 2]
depends_on: [4]      # other WorkPackage Issue numbers; resolved at commit time
impact_scope:
  files: [src/calendar-widget/*]
  modules: ["the Calendar widget (Design BC)"]
  seams: ["calendar-widget ↔ checkout-flow (real seam)"]
  contracts: []
  external_systems: []
  estimated_complexity: small
  notes: ""
acceptance_criteria_count: 3
slice_type: AFK     # or HITL
---

# <imperative title>

## What to build

<concise end-to-end behaviour; no file paths in body, those live in impact_scope frontmatter>

## AcceptanceCriteria

- [ ] <ac 1>
- [ ] <ac 2>

## Refs

- Parent Spec: #<spec-number>
- Blocked by: #<wp-number> (if any; else "None - can start immediately")
- ADRs: <list>
```

Labels at create: `type:workpackage`, `status:draft`. After `approve-workpackage`: `status:approved`. After Dispatch's `mark-in-progress`: `status:in_progress` + `agent:worker`. Lifecycle continues per ADR-0013.

### `type:supervision-alert` Issue (written by `enqueue-message --kind=supervision-alert`)

```markdown
---
type: supervision-alert
status: open
severity: low | mid | high
detected_at: 2026-05-12T10:23:45Z
detector: supervision | hermes-stale-fact | dispatch-arbiter-failure
related_triple_ids: [ev_..., ev_...]
related_refs:
  - kind: fact
    ref: .rlm/facts/2026-04-12-scaffold.md
---

# <title>

<body — what was detected, evidence>

## Recommended action

<one-line for human reader>
```

Labels at create: `type:supervision-alert`, `status:open`, plus `severity:low|mid|high`.

---

## Subcommand reference

### Summary table

| Subcommand | Caller(s) | Routing | Body input | Idempotent |
|---|---|---|---|---|
| `propose-adr` | hermes-design | PR | stdin / `--body-file` | by `(slug)` |
| `propose-context-change` | hermes-design | PR | `--diff-file` | by `(target, content-hash)` |
| `add-contract` | hermes-design | PR | stdin / `--body-file` | by `(slug)` |
| `append-fact` | worker | direct-commit | stdin / `--body-file` | by `(date+slug)` |
| `supersede-fact` | worker | direct-commit | stdin / `--body-file` + `--supersedes <id>` | by `(date+slug)` |
| `append-business-model` | hermes | direct-commit | stdin / `--body-file` | by `(snapshot_date)` |
| `append-deployment-constraints` | hermes | direct-commit | stdin / `--body-file` | by `(snapshot_date)` |
| `commit-spec` | hermes | Issue create | stdin / `--body-file` + flags | by `(signal_ref)` |
| `confirm-spec` | hermes | Issue relabel | `--issue` flag | by `(issue, target-status)` |
| `commit-workpackage` | hermes-design | Issue create | stdin / `--body-file` + flags | by `(parent_spec, slug)` |
| `approve-workpackage` | hermes-design | Issue relabel + verify | `--issue` flag | by `(issue, target-status)` |
| `record-signal` | hermes | Issue create | stdin / `--body-file` + flags | by `(source, dedup-key)` |
| `mark-superseded` | hermes | Issue relabel | `--issue` + `--by <issue>` | by `(issue, target-status)` |
| `mark-in-progress` | dispatch | Issue relabel | `--issue` flag | by `(issue, target-status)` |
| `mark-delivered` | dispatch | Issue relabel | `--issue` flag | by `(issue, target-status)` |
| `open-pr` | worker | PR create | `--issue` + `--branch` flags | by `(branch)` |
| `enqueue-message` | hermes, dispatch, supervision | Issue create OR comment+label | `--kind` + flags | by `(kind, parent, content-hash)` within 60s window |

### Read subcommands (planned, deferred)

Pure-read commands like `rlm get-spec --issue=N` are deferred to v1.1; v1.0 agents use `gh issue view N` directly for reads. Justification: GitHub already provides good read tooling; building a parallel CLI layer for reads inflates surface without value.

### Detailed: `propose-adr`

**Purpose**: Open a PR adding a new ADR file.

**Caller**: hermes-design only.

**Flags**:
- `--slug <NNNN-kebab-slug>` — e.g., `0018-rlm-cli-spec`. CLI verifies the NNNN prefix is monotonically next available.
- `--title <string>` — H1 title (extracted from body if absent, but explicit preferred)
- `--related-adrs <comma-separated>` — list of ADR numbers cited in body
- `--body` / `--body-file` / stdin — markdown content (frontmatter is generated by CLI, NOT included in body)

**Side effects**:
1. Create branch `adr/<NNNN>-<slug>` from current HEAD of `main`
2. Write `.rlm/adr/<NNNN>-<slug>.md` with CLI-generated frontmatter + agent body
3. `git commit` with message: `adr: NNNN-<slug>`
4. `git push origin <branch>`
5. `gh pr create --title "ADR-<NNNN>: <title>" --body <auto-generated PR body with frontmatter summary + body preview>`

**Output (stdout, `--json`)**:
```json
{"ok":true,"adr_number":18,"slug":"rlm-cli-spec","branch":"adr/0018-rlm-cli-spec","pr_url":"https://github.com/.../pull/42","triple_id":"ev_..."}
```

**Failure modes**:
- `validation-error` (2): body missing H1 title; slug NNNN prefix not next monotonic
- `precondition-failed` (6): branch already exists (likely concurrent invocation — read PR # and return as if idempotent)
- `external-service-down` (8): git push or gh failure

**Idempotency**: keyed by `slug`. Second call with same slug after success → returns existing PR ref without re-creating.

### Detailed: `propose-context-change`

**Purpose**: Open a PR editing `.rlm/CONTEXT-MAP.md` or `.rlm/bc/<bc>/CONTEXT.md`.

**Caller**: hermes-design only.

**Flags**:
- `--target <path>` — relative to `.rlm/`, e.g., `bc/intake/CONTEXT.md` or `CONTEXT-MAP.md`
- `--diff-file <path>` — unified diff (single file) — OR
- `--new-content` / `--new-content-file` — complete replacement content
- `--reason <string>` — short summary for PR title (e.g., "add 'Household' term")

**Side effects**:
1. Create branch `context-change/<short-slug-from-reason>` (with disambiguation if collision)
2. Apply diff or write new content to the target file
3. Commit + push + open PR

**Output (`--json`)**:
```json
{"ok":true,"target":"bc/intake/CONTEXT.md","branch":"context-change/add-household-term","pr_url":"...","triple_id":"ev_..."}
```

**Failure modes**:
- `validation-error` (2): target file doesn't exist; diff fails to apply
- All other PR-routed failures

**Idempotency**: by `(target, content-hash-of-result)`. Re-running with identical resulting content returns existing PR.

### Detailed: `add-contract`

**Purpose**: Open a PR adding a new contract file.

**Caller**: hermes-design only.

**Flags**:
- `--slug <kebab-case>` — e.g., `household-api`
- `--contract-kind <api|event|schema|integration>`
- `--title <string>` — used in PR title
- `--body` / `--body-file` / stdin — markdown content

**Side effects**: same PR-routed shape as `propose-adr`. Writes to `.rlm/contracts/<slug>.md` with CLI-generated frontmatter.

**Failure modes**:
- `validation-error` (2): body missing required sections (Shape / Invariants / Error modes / Versioning)
- `precondition-failed` (6): slug already exists in main or in another open PR

**Idempotency**: by `slug`.

### Detailed: `append-fact`

**Purpose**: Write a new fact file via direct commit (not PR — facts record reality, not decisions).

**Caller**: worker only.

**Flags**:
- `--slug <YYYY-MM-DD-kebab>` — CLI validates date prefix is today
- `--about <comma-separated-refs>` — references covered (`code:src/foo.ts:1-50`, etc.)
- `--body` / `--body-file` / stdin — markdown content

**Side effects**:
1. Write `.rlm/facts/<slug>.md` with CLI-generated frontmatter (incl. `verified_by_commit`, `last_verified`, `about`)
2. `git add` + `git commit` on **current branch** (NOT main directly — Worker is on `wp/<num>-<slug>`)
3. The commit becomes part of the PR Worker opens later via `open-pr`
4. The CI fact-commit check (per ADR-0013) verifies at PR-merge time that the PR contains ≥1 fact commit

**No push** — Worker's `open-pr` pushes the branch including this commit.

**Output (`--json`)**:
```json
{"ok":true,"fact_id":"2026-05-12-scaffold","file":".rlm/facts/2026-05-12-scaffold.md","commit":"abc123","triple_id":"ev_..."}
```

**Failure modes**:
- `validation-error` (2): date in slug isn't today (catches Worker reusing old facts)
- `precondition-failed` (6): not on a `wp/*` branch (Worker should be); slug collision in same date

**Idempotency**: by `slug`. Re-call → no new file; existing returned. (Discourages "I'll just rewrite it" — use `supersede-fact`.)

### Detailed: `supersede-fact`

**Purpose**: Write a new fact file that supersedes an older one.

**Caller**: worker only.

**Flags**:
- `--slug <YYYY-MM-DD-kebab>` — same as `append-fact`
- `--supersedes <old-fact-id>` — required; CLI validates the old fact exists and is `status:active`
- `--body` / `--body-file` / stdin

**Side effects**:
1. Write new fact file (same as `append-fact`)
2. **Edit** the old fact's frontmatter in place: set `superseded_by: <new-id>` and `status: superseded`
3. `git add` both files + commit on current branch
4. The two-file commit becomes part of the PR

**Failure modes**:
- Same as `append-fact` plus:
- `precondition-failed` (6): `--supersedes` ref doesn't exist or already superseded

**Idempotency**: by `(slug, supersedes)`. Re-call with same values returns existing.

### Detailed: `append-business-model` / `append-deployment-constraints`

**Purpose**: Write a snapshot file (business-model or deployment-constraints) via direct commit.

**Caller**: hermes only.

**Flags**:
- `--snapshot-date <YYYY-MM-DD>` — defaults to today; CLI validates ≤ today
- `--signal-ref <issue-number>` — originating signal
- For `append-deployment-constraints` only: `--budget-monthly-cap <usd>`, `--region <string>`, `--compliance <comma-separated>`, `--vendor-preferences <string>`, `--operations <managed_only|self_hosted|hybrid>` (these populate frontmatter; can also be in body)
- `--body` / `--body-file` / stdin — narrative body

**Side effects**:
1. Write `.rlm/business/business-model-<date>.md` (or `deployment-constraints-<date>.md`)
2. `git add` + `git commit` on `main` directly (CLI knows: direct-commit route)
3. `git push origin main`

**Failure modes**: same as PR-routed, plus `state-write-error` (5) for git push conflicts on main.

**Idempotency**: by `(type, snapshot-date)`. Re-call with same date → returns existing path; agents must use a new date to update.

### Detailed: `commit-spec`

**Purpose**: Create a `type:spec` Issue at `status:draft`.

**Caller**: hermes only.

**Flags**:
- `--signal-ref <issue-number>` — required
- `--title <string>` — Issue title (imperative)
- `--business-model-ref <path>` — `.rlm/business/business-model-<date>.md`
- `--deployment-constraints-ref <path>` — optional
- `--body` / `--body-file` / stdin — Issue body (must contain `## AcceptanceCriteria` section with ≥1 checkbox item)

**Side effects**:
1. `gh issue create` with body, title, and labels `type:spec`, `status:draft`
2. CLI parses body to extract `acceptance_criteria_count` and adds it to frontmatter

**Validation**:
- Body must contain `## AcceptanceCriteria` H2 followed by at least one `- [ ]` checkbox
- Signal `--signal-ref` must exist + be `type:signal` (CLI calls `gh issue view --json labels`)

**Output (`--json`)**:
```json
{"ok":true,"issue_number":143,"status":"draft","triple_id":"ev_..."}
```

**Failure modes**:
- `validation-error` (2): missing AcceptanceCriteria; signal_ref not a signal
- `precondition-failed` (6): a Spec with same `signal_ref` already exists at `status:draft` or `status:confirmed` (suggests calling `mark-superseded` first)

**Idempotency**: by `signal_ref`. Second call returns existing Issue (does NOT update body — Spec body is content-addressable to the signal).

### Detailed: `confirm-spec`

**Purpose**: Flip `status:draft → status:confirmed` on a Spec Issue.

**Caller**: hermes only.

**Flags**:
- `--issue <number>` — the Spec to confirm
- `--auto-confirmed` — boolean flag; if set, marks the confirmation as having fired via timeout rather than explicit human yes (per ADR-0005)

**Side effects**:
1. `gh issue edit --remove-label status:draft --add-label status:confirmed`
2. If `--auto-confirmed`: also edit Issue body to set `auto_confirmed: true` in frontmatter

**Validation**:
- Issue must be `type:spec` AND currently `status:draft` (CLI reads labels)

**Idempotency**: by `(issue, target-status)`. Re-call when already `status:confirmed` → no-op success.

### Detailed: `commit-workpackage`

**Purpose**: Create a `type:workpackage` Issue at `status:draft`.

**Caller**: hermes-design only.

**Flags**:
- `--parent-spec <issue-number>` — required; must be `type:spec status:confirmed`
- `--title <string>`
- `--worker-class <web-stack|...>` — v1 only `web-stack` is valid
- `--adr-refs <comma-separated>` — e.g., `1,2`
- `--depends-on <comma-separated>` — Issue numbers; CLI verifies each is a WorkPackage Issue (not necessarily approved yet)
- `--impact-scope-file <path>` — YAML file containing the `impact_scope:` field (output from `compute-impact-scope` skill)
- `--slice-type <AFK|HITL>` — default AFK
- `--body` / `--body-file` / stdin — Issue body

**Side effects**:
1. CLI assembles full frontmatter (parses `--impact-scope-file`, adds `acceptance_criteria_count`)
2. `gh issue create` with body, title, labels `type:workpackage status:draft`

**Validation**:
- Parent spec must exist + be `status:confirmed`
- Each `--depends-on` ref must be a WorkPackage Issue
- Body must contain `## AcceptanceCriteria` with checkboxes
- `impact_scope` YAML must parse + have required keys (files, modules, seams, contracts, external_systems, estimated_complexity)

**Idempotency**: by `(parent_spec, slug-derived-from-title)`. Re-call returns existing.

### Detailed: `approve-workpackage`

**Purpose**: Flip `status:draft → status:approved` on a WorkPackage Issue. **Mechanically verifies all `adr_refs` are merged to main**.

**Caller**: hermes-design only.

**Flags**:
- `--issue <number>`
- `--auto-approved` — same semantics as `--auto-confirmed`

**Side effects**:
1. Read Issue body, parse frontmatter, extract `adr_refs: [1, 2, ...]`
2. For each ADR ref: check `.rlm/adr/<NNNN>-*.md` exists in `git ls-tree main` — i.e., the ADR file is on `main`, meaning its PR merged. **If ANY is missing → exit 6 (precondition-failed) with `details.unmerged: [...]`**
3. If all merged: `gh issue edit --remove-label status:draft --add-label status:approved`
4. Optionally set `auto_approved: true` in frontmatter

**Failure modes**:
- `precondition-failed` (6): one or more `adr_refs` not yet merged on main; CLI returns the list

**Idempotency**: by `(issue, target-status)`.

### Detailed: `record-signal`

**Purpose**: Create a `type:signal` Issue.

**Caller**: hermes only.

**Flags**:
- `--source <human|production-monitor|hermes>`
- `--title <string>`
- `--related-thread <discord-thread-id>` — optional
- `--dedup-key <string>` — optional; CLI uses to skip if recent Issue (< 24h) with same key exists
- `--body` / `--body-file` / stdin

**Side effects**:
1. If `--dedup-key`: `gh issue list --label type:signal --search "<dedup-key>"` — skip if recent match
2. `gh issue create` with labels `type:signal status:draft`

**Output**:
```json
{"ok":true,"issue_number":142,"deduplicated":false,"triple_id":"ev_..."}
```
If deduplicated:
```json
{"ok":true,"issue_number":141,"deduplicated":true,"reason":"open signal with same dedup_key < 24h ago","triple_id":"ev_..."}
```

**Idempotency**: by `dedup-key`.

### Detailed: `mark-superseded`

**Purpose**: Flip an Issue to `status:superseded` (terminal).

**Caller**: hermes (Spec / WP / Signal).

**Flags**:
- `--issue <number>` — to be superseded
- `--by <issue-number>` — superseding Issue (must exist; same `type:*`)

**Side effects**:
1. `gh issue edit --remove-label status:* --add-label status:superseded`
2. Add comment to old Issue: `Superseded by #<by>`
3. Add comment to new Issue: `Supersedes #<issue>`

**Idempotency**: by `(issue, target-status)`.

### Detailed: `mark-in-progress`

**Purpose**: Flip WP from `status:approved → status:in_progress` + assign `agent:worker`.

**Caller**: dispatch only.

**Flags**:
- `--issue <number>`

**Side effects**:
1. Validate Issue is `type:workpackage status:approved`
2. `gh issue edit --remove-label status:approved --add-label status:in_progress --add-label agent:worker`

**Idempotency**: by `(issue, target-status)`.

### Detailed: `mark-delivered`

**Purpose**: Flip WP from `status:in_progress → status:delivered`. **Requires CI fact-commit check passed** on the closing PR.

**Caller**: dispatch only.

**Flags**:
- `--issue <number>`

**Side effects**:
1. Find the closing PR via `gh issue view --json closedByPullRequestsReferences`
2. Verify PR is merged AND CI fact-commit check passed (CLI looks for a specific check name TBD — e.g., `rlm/fact-commit-required`)
3. If both: `gh issue edit --remove-label status:in_progress agent:* --add-label status:delivered`

**Failure modes**:
- `precondition-failed` (6): PR not merged, or CI fact-commit check missing/failed

**Idempotency**: by `(issue, target-status)`.

### Detailed: `open-pr`

**Purpose**: Worker opens the PR for its WorkPackage branch.

**Caller**: worker only.

**Flags**:
- `--issue <wp-number>`
- `--branch <branch-name>` — must match `wp/<wp-number>-<slug>` pattern
- `--title <string>` — PR title (Worker's choice)
- `--body` / `--body-file` / stdin — PR body (Worker's summary)

**Side effects**:
1. Validate branch exists locally + contains ≥1 fact commit (verified by inspecting git log for commit messages or modified files under `.rlm/facts/`)
2. `git push origin <branch>`
3. `gh pr create --base main --head <branch> --title "<title>" --body "<body>\n\ncloses #<issue>"` — CLI ensures `closes #<wp-issue>` is in the body
4. Add comment on the WP Issue: "PR #<pr-number> opened by Worker"

**Output**:
```json
{"ok":true,"pr_number":146,"pr_url":"...","branch":"wp/144-revert-calendar","triple_id":"ev_..."}
```

**Failure modes**:
- `validation-error` (2): branch name doesn't match pattern; no fact commit on branch
- `state-write-error` (5): push fails

**Idempotency**: by `branch`. Re-call returns existing PR.

### Detailed: `enqueue-message`

**Purpose**: Queue an outbound message for Hermes to route to Discord (per ADR-0015).

**Caller**: hermes (self-routing), dispatch, supervision, occasionally worker (self-decline).

**Flags**:
- `--kind <kind-string>` — see ADR-0015 for valid kinds (`retry-exhausted`, `ac-ambiguity`, `supervision-alert`, `intake-confirmation`, `design-approval`, `worker-self-decline`, `production-anomaly`)
- `--parent-issue <number>` — for kinds with parent Issue (everything except `supervision-alert`)
- `--body` / `--body-file` / stdin — payload markdown (what Hermes will format for Discord)

**Side effects**:
Depends on kind:

- Kinds with parent Issue: `gh issue comment --body <body>` + `gh issue edit --add-label outbound:<kind>`
- `supervision-alert`: create a new `type:supervision-alert` Issue (uses the supervision-alert frontmatter schema)

**Idempotency**: by `(kind, parent-issue or kind+content-hash, within 60s)`. Avoids duplicate routing if CLI is invoked twice rapidly.

---

## Routing modes (detail)

### PR-routed

Subcommands: `propose-adr`, `propose-context-change`, `add-contract`

Pattern:
1. Branch off `main`: `<kind>/<slug>`
2. Make file changes
3. `git commit` + `git push origin <branch>`
4. `gh pr create`

Branch name conventions:
- `adr/<NNNN>-<slug>` for ADRs
- `context-change/<reason-slug>` for CONTEXT changes
- `contract/<slug>` for new contracts

These branches are owned by the CLI; agents do not interact with them directly. After PR merge, the branch is auto-deleted (`gh pr merge --delete-branch` if user enables, else stays).

### Direct-commit

Subcommands: `append-fact`, `supersede-fact`, `append-business-model`, `append-deployment-constraints`

Pattern depends on which branch is active:
- **Worker is on `wp/*`**: commit goes on the `wp/*` branch; eventually included in Worker's PR. No push from the CLI (Worker's `open-pr` pushes the whole branch).
- **Hermes is on no specific branch (typically `main`)**: commit goes on `main`; CLI pushes immediately.

The CLI inspects `git branch --show-current` to decide.

### Issue create / relabel

Subcommands: `commit-spec`, `commit-workpackage`, `record-signal`, `confirm-spec`, `approve-workpackage`, `mark-*`, `enqueue-message`

Pattern:
- Create: `gh issue create --title ... --body ... --label ...`
- Relabel: `gh issue edit <num> --remove-label ... --add-label ...`
- Comment: `gh issue comment <num> --body ...`

The CLI uses `gh`'s built-in auth (CLI must have `gh` configured at install time or via env var `GH_TOKEN`).

---

## Idempotency contracts

The CLI strives for **safe-to-retry** semantics. Same logical operation called twice should not produce two writes.

### Idempotency keys per subcommand

Listed in the [Summary table](#summary-table). Implementation: the CLI maintains a small SQLite cache at `.local/rlm-idempotency.db` mapping `(subcommand, key-tuple, content-hash) → (result, timestamp)`. TTL: 24h (configurable).

When a duplicate call arrives:
- If `result` is `ok`: return the cached result with `idempotent: true` field in output.
- If `result` was an error: re-run (errors may be transient).

### Exclusions

- `--dry-run` calls never write to the cache (so re-running real after dry doesn't fool the cache).
- Errors of kind `external-service-down` (8) never cache (transient).

---

## Concurrency

Multiple agents may call the CLI concurrently. The CLI's threat model assumes:
- Workflow item Issue writes are serialized by GitHub's API (gh handles retries internally for `409 Conflict`).
- File writes to `.rlm/{adr,contracts}/<slug>.md` are serialized by git push to the PR branch (the second push fails with `non-fast-forward`; CLI retries by rebasing or returns `conflict` exit code 7).
- Concurrent direct-commit writes to `.rlm/{facts,business}/<date>-*.md` use date+slug uniqueness; collisions yield `precondition-failed`.
- Global Worker lock (per ADR-0007) is held by Dispatch, not by individual `rlm` calls. The CLI does **not** acquire/release the worker lock — that's a separate concern.

---

## Versioning policy

semver. The contract version is tracked in the package manifest at `tools/rlm/pyproject.toml` (`[project] version`).

### Breaking changes (major bump)

- Removing a subcommand
- Renaming or removing a flag
- Changing an exit code's meaning
- Changing a frontmatter schema's required fields
- Changing the triple JSON shape

### Additive (minor bump)

- New subcommand
- New optional flag
- New optional frontmatter field
- New triple field

### Patch (patch bump)

- Bug fixes
- Error message wording
- Performance improvements

Agents in v1 pin to `rlm-cli ~= 1.0`. v2 will be a separate `tools/rlm-v2/` directory and agents migrate explicitly.

---

## Examples

### Worker writing a fact + opening a PR

```sh
# Worker is on branch wp/144-revert-calendar
RLM_AGENT_ROLE=worker
RLM_AGENT_INVOCATION=inv_abc123
RLM_SKILL_NAME=web-stack-scaffold

# Write the fact
cat <<MD | rlm append-fact --slug 2026-05-12-calendar-revert --about "code:src/calendar-widget/index.tsx:1-50"
Calendar widget reverted to v1.2 server-rendered snapshot. Mobile users see
the v1.2 booking flow. Tags `widget-v1.2` exists for re-verification.
MD
# → {"ok":true,"fact_id":"2026-05-12-calendar-revert","file":".rlm/facts/2026-05-12-calendar-revert.md","commit":"abc1234","triple_id":"ev_..."}

# Open the PR
cat <<MD | rlm open-pr --issue 144 --branch wp/144-revert-calendar --title "Revert calendar widget to v1.2"
Reverts the v2.0 calendar widget to v1.2 server-rendered snapshot.

Tests pass; mobile regression confirmed fixed.

closes #144
MD
# → {"ok":true,"pr_number":146,"pr_url":"...","triple_id":"ev_..."}
```

### Hermes proposing a Spec (Phase B of signal-to-spec)

```sh
RLM_AGENT_ROLE=hermes
RLM_AGENT_INVOCATION=inv_def456
RLM_SKILL_NAME=signal-to-spec

# Persist business model snapshot
rlm append-business-model \
  --signal-ref 142 \
  --snapshot-date 2026-05-12 \
  --body-file /tmp/bm-draft.md

# Create the Spec Issue
rlm commit-spec \
  --signal-ref 142 \
  --title "Recover mobile booking conversion to ≥ 8.2%" \
  --business-model-ref .rlm/business/business-model-2026-05-12.md \
  --body-file /tmp/spec-draft.md
# → {"ok":true,"issue_number":143,"status":"draft","triple_id":"ev_..."}

# Confirm
rlm confirm-spec --issue 143
# → {"ok":true,"issue":143,"status":"confirmed","triple_id":"ev_..."}
```

### Dispatch marking a WP delivered after PR merge

```sh
RLM_AGENT_ROLE=dispatch
RLM_AGENT_INVOCATION=inv_dispatch_12

rlm mark-delivered --issue 144
# CLI:
#   1. gh issue view 144 --json closedByPullRequestsReferences → PR #146
#   2. gh pr view 146 --json mergedAt,statusCheckRollup → merged, all checks passed
#   3. Confirm check name `rlm/fact-commit-required` is success
#   4. gh issue edit 144 --remove-label status:in_progress agent:* --add-label status:delivered
# → {"ok":true,"issue":144,"status":"delivered","triple_id":"ev_..."}
```

---

## Open questions (v2 / not yet decided)

1. **Read subcommands** (`rlm get-spec`, etc.) — deferred. Agents use `gh` for now.
2. **HMAC-signed caller identity** — deferred until v2 threat model expands.
3. **`rlm validate`-style cross-reference linter** — interesting from old version's design, but unclear what it would check given our architecture. Defer until pattern emerges.
4. **CI fact-commit check exact name** — TBD (`rlm/fact-commit-required` proposed). Lands when CI workflow is authored.
5. **Worker lock interaction** — `rlm` calls do not touch the global worker lock. Should `rlm` calls during a Dispatch cycle assert that lock-holder env var matches `RLM_AGENT_INVOCATION`? Considered defensive; deferred.
6. **Schema migration tooling** — when this contract bumps major, what happens to existing data? `rlm migrate <from-major> <to-major>` deferred.

These belong in `.rlm/v2-todo.md` once locked.

---

## Cross-references

- [ADR-0004](../adr/0004-rlm-knowledge-base.md) — RLM storage + write-interface scope (this contract is its concrete implementation)
- [ADR-0009](../adr/0009-resource-access-boundaries.md) — agent access matrix (this contract's permission table mirrors it)
- [ADR-0011](../adr/0011-structured-agent-self-narration.md) — triple emission contract
- [ADR-0012](../adr/0012-supervision-pure-observability.md) — event log consumer
- [ADR-0013](../adr/0013-spec-workpackage-lifecycle.md) — lifecycle labels this CLI mutates
- [ADR-0015](../adr/0015-message-router-contract.md) — `enqueue-message` consumers
- [ADR-0016](../adr/0016-worker-contract.md) — Worker's 5-output invariant; `open-pr` enforces fact-commit precondition
- [ADR-0017](../adr/0017-delivery-arbiter.md) — Arbiter's label flips use `mark-superseded` / relabel-to `agent:human-help`

When this contract changes, evaluate whether any of the above ADRs need amendment (usually yes if a major-version bump).
