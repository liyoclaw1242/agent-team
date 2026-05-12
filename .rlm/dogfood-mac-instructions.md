# Sweet-home Dogfood — Mac instructions

Continue the e2e test from Windows. The test fixture (repo + WP issue) is
already on GitHub and ready to dispatch. Three sweet-home Rust patches
discovered during Windows testing are pushed upstream so a fresh clone
will compile + run with the right behaviors.

**Total wallclock**: ~20-30 min (mostly Rust first-build).
**Total cost**: ~$1-3 of Claude credit (Worker + WhiteBox + BlackBox).

---

## What was learned on Windows (and why we switched)

We hit a series of small bugs that compounded into "Worker spawned, ran
correctly, emitted perfect JSON envelope — and the output was thrown
away":

| Bug | Layer | Status |
|---|---|---|
| `render_template` errors on literal `{` `}` in `repo_source.command` | YAML / runtime | Workaround landed in `agent-team.workflow.yaml` (use `cat .workflow-repos.json` instead of inline `echo`); doc comment in the yaml |
| `issue_source.command` written as multi-line `|` block fails under `sh -c` (newlines treated as statement separators) | YAML / runtime | Same yaml fix — inlined to single line |
| `Command::new("claude")` on Windows can't execute `claude.cmd` npm shim | sweet-home Rust (Windows only) | Patched: `one_shot.rs` reads `CLAUDE_BINARY` env override |
| `strip_json_fence` only matched fences at the very start; Claude writes prose-before-fence | sweet-home Rust | Patched: scan for fence anywhere in the result text + new unit test |
| `quarantine_issue` hardcodes `--remove-label status:ready` — fails atomically when our workflow uses `status:approved` | sweet-home Rust | Patched: only adds `human-review`, doesn't remove anything |
| `on_no_structured_output.remove_labels` tries to remove 5 `agent:*` labels in one atomic gh call → fails if any is missing | YAML | **NOT yet fixed** — defer; only fires on real failures, not the happy path |

Of these, **fix #4 is what unblocks the happy path**. Worker DID emit
correct JSON; sweet-home just failed to find it. Once sweet-home can
parse "prose then fence", `on_result.worker.delivered` fires and the
pipeline advances.

Verified Worker output on Windows (the run that proved the architecture):
- `cost: $0.327`
- `exit_code: 0`
- `18 turns / 101 s`
- Made a real fact commit `b4a56a6` `[ac1] add GET /todos returning {"todos":[]}` on branch `spawn-1-1778575055`
- Emitted exactly the JSON shape our SKILL.md contract specifies

---

## 1. Prerequisites on Mac

Install if missing:

```bash
# Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Node + pnpm (via Homebrew or whichever)
brew install node pnpm

# gh CLI
brew install gh
gh auth login        # login as liyoclaw1242 (or whichever account owns the repos)

# Claude Code CLI
npm install -g @anthropic-ai/claude-code
claude --version     # should print 2.x

# git (usually pre-installed)
git --version
```

Confirm everything:

```bash
which claude && claude --version
which gh && gh auth status
which node && node --version    # >= 20
which pnpm && pnpm --version
which cargo && cargo --version  # >= 1.85
```

---

## 2. Clone the three repos

Pick a parent directory (the instructions below use `~/dev/`).

```bash
mkdir -p ~/dev && cd ~/dev

git clone https://github.com/liyoclaw1242/agent-sweet-home.git
git clone https://github.com/liyoclaw1242/agent-team.git
git clone https://github.com/liyoclaw1242/todo-20260512.git
```

---

## 3. Build sweet-home (first time only — 5-10 min)

```bash
cd ~/dev/agent-sweet-home
pnpm install
cargo build --manifest-path src-tauri/Cargo.toml --no-default-features
```

If this is the first Rust build on the machine, expect ~10 min of
dependency compilation. Subsequent builds are seconds.

---

## 4. Prepare the test fixture repo

```bash
cd ~/dev/todo-20260512
pnpm install         # installs vitest, tsx, @types/node, typescript
pnpm verify          # tsc --noEmit && vitest run — confirm baseline 2/2 green
```

**Edit `.workflow-repos.json` to use the Mac-absolute path.** The file
currently has `D:/todo-20260512` (Windows). Replace with your Mac path:

```bash
# Confirm where the repo lives
pwd
# e.g. /Users/liyo/dev/todo-20260512

# Update the file
cat > .workflow-repos.json <<EOF
[{"repo":"liyoclaw1242/todo-20260512","path":"$(pwd)"}]
EOF

# Also update the workflow yaml's repo_source.command — it currently
# points at the Windows location of the same file. Edit by hand:
#
#   repo_source:
#     command: "cat /d/todo-20260512/.workflow-repos.json"
#
# Change to:
#
#   repo_source:
#     command: "cat /Users/liyo/dev/todo-20260512/.workflow-repos.json"
#
# (or wherever `pwd` reports). The path must be absolute; sh doesn't
# expand `~` or `$HOME` here without help.
```

Suggested one-liner to fix the workflow yaml's command line:

```bash
WF=~/dev/todo-20260512/agent-team.workflow.yaml
sed -i.bak "s|/d/todo-20260512/.workflow-repos.json|$(pwd)/.workflow-repos.json|" "$WF"
rm "$WF.bak"
```

Verify the schema still parses:

```bash
cd ~/dev/agent-sweet-home
cargo run --manifest-path src-tauri/Cargo.toml --example check_yaml -- \
    ~/dev/todo-20260512/agent-team.workflow.yaml
# expect: OK: 6 roles, 12 dispatch rules, 6 on_result handler entries
```

---

## 5. Confirm issue #1 is in the right state

The issue should already be:

```
labels: [kind:workpackage, status:approved, agent:worker]
state: open
```

Check:

```bash
gh issue view 1 --repo liyoclaw1242/todo-20260512 \
    --json labels,state \
    --jq '{state: .state, labels: [.labels[].name]}'
```

If it shows `status:in-progress` (from an aborted previous run), reset:

```bash
gh issue edit 1 --repo liyoclaw1242/todo-20260512 \
    --remove-label status:in-progress --add-label status:approved
```

---

## 6. Launch sweet-home

```bash
cd ~/dev/agent-sweet-home
WORKFLOW_FILE=~/dev/todo-20260512/agent-team.workflow.yaml \
    cargo run --manifest-path src-tauri/Cargo.toml --no-default-features
```

**No `CLAUDE_BINARY` env needed on Mac** — the npm-installed `claude`
shim is a regular sh script that execs the underlying executable, and
`Command::new("claude")` works against it directly.

Within ~3 seconds you should see:

```
agent-sweet-home: HTTP API listening on http://127.0.0.1:<port>
workflow: loaded /Users/<you>/dev/todo-20260512/agent-team.workflow.yaml
```

(The Tauri window may show a "can't reach localhost" error page because
we're bypassing `pnpm tauri dev`'s vite frontend. **Ignore it** — the
Rust backend runs the workflow runtime regardless. If you want the
window's One-Shot dashboard UI, run `pnpm tauri dev` in another
terminal instead — but kill anything on `:1420` first.)

---

## 7. Watch for events

In another terminal:

```bash
# Tail the SQLite event log of the most recent spawn
DB=~/Library/Application\ Support/com.agentsweethome.app/agent-sweet-home.db

# Show the run list
sqlite3 "$DB" "SELECT id, role, status, started_at, ended_at, total_cost_usd FROM one_shot_runs ORDER BY started_at DESC LIMIT 5;"

# Show the latest run's log tail
LATEST=$(sqlite3 "$DB" "SELECT id FROM one_shot_runs ORDER BY started_at DESC LIMIT 1;")
sqlite3 "$DB" "SELECT seq, stream, substr(text,1,200) FROM one_shot_log_lines WHERE run_id='$LATEST' ORDER BY seq DESC LIMIT 20;"
```

Or watch sweet-home's own stderr — every dispatch tick emits:

```
workflow: liyoclaw1242/todo-20260512#1 → Spawned { role: "worker", status: "completed", kind: "delivered" }
```

(or `Aborted` / `NoAction` / `dispatch error: ...`).

---

## 8. Expected sequence

### Tick 1 (t = 0s, first poll)
1. Dispatch matches rule `agent:worker + status:approved + kind:workpackage` → `spawn_fresh role: worker`
2. `pre_spawn` flips `status:approved → status:in-progress` (visible on GH)
3. Sweet-home runs `git worktree add -b spawn-1-<ts> ~/dev/todo-20260512-worktrees/spawn-1-<ts>`
4. Spawns `claude -p` with `tdd-loop` SKILL.md as system prompt, cwd at the new worktree
5. Worker runs RGR (~3-10 min, ~$0.30-1.50):
   - reads WP body and AC
   - writes a failing test for `GET /todos`
   - sees red via `pnpm vitest run`
   - implements handler in `src/server.ts`
   - sees green
   - commits with `[ac1] add GET /todos returning {"todos":[]}` message
   - emits structured JSON envelope (`kind: delivered`)
6. Sweet-home's `extract_structured_output` parses the JSON
7. `on_result.worker.delivered` fires:
   - posts summary comment
   - flips `agent:worker → agent:validator` + `status:in-progress → status:delivered`
   - `push_branch_and_pr` pushes the spawn branch + opens a PR against `main` with the rendered body
   - worktree is torn down

### Tick 2 (t ≈ 5-15min later)
1. Dispatch matches `agent:validator + status:delivered` → `spawn_fresh role: whitebox-validator`
2. Spawns WhiteBox, which reads the PR diff via `gh pr diff <num>` + the SKILL.md instructions
3. Emits `kind: approved` (or `rejected`) JSON
4. `on_result.whitebox-validator.approved` flips `agent:validator → agent:blackbox-validator`

### Tick 3
1. BlackBox spawns, reads ACs + sandbox (in v1, just runs `pnpm verify` and curls localhost)
2. Emits `kind: approved` JSON
3. `on_result.blackbox-validator.approved` flips `status:delivered → status:validated`, posts "ready for human merge"

### Manual step (you)
- Open the PR on GitHub
- Merge it (squash or merge commit — your choice)
- Run `cd ~/dev/todo-20260512 && rlm mark-delivered 1` (if you cloned `rlm` CLI from the agent-team repo)
  - Or just close the issue manually with `gh issue close 1`

---

## 9. Things that might still go wrong (and the fix)

### (a) Worker emits invalid JSON
- Symptom: `dispatch error: result handler: ...` in stderr; issue stuck at `status:in-progress + agent:arbiter`
- The `on_no_structured_output` fallback fires and routes to Arbiter — but the YAML's degrade handler currently tries to `remove_labels` 5 `agent:*` labels in one atomic `gh` call, which fails if any is missing
- **Mitigation**: manually edit `~/dev/todo-20260512/agent-team.workflow.yaml`'s `on_no_structured_output.steps` to only remove `agent:worker` (or whichever label is actually set)
- This is a known v1 simplification — to be fixed in a Phase 2 yaml pass

### (b) `push_branch_and_pr` fails authentication
- Symptom: `dispatch error: ... push failed: ... fatal: could not read Username`
- Cause: `gh auth login` was done with HTTPS but git is using SSH (or vice versa); the worktree dir doesn't have git credentials configured
- **Fix**: `cd ~/dev/todo-20260512 && gh auth setup-git` configures git's credential helper for HTTPS

### (c) WhiteBox / BlackBox times out
- Each role has `budget_usd` cap in the yaml. WhiteBox = 2.0, BlackBox = 2.5. If a role exceeds budget Claude exits early
- **Mitigation**: bump the relevant role's `budget_usd` in the yaml and re-run

### (d) BlackBox can't find the sandbox URL
- v1 BlackBox SKILL.md expects a deployed sandbox URL. For this local-only test we don't have one
- BlackBox should fall back to running `pnpm verify` locally + curl localhost — but this isn't fully exercised yet
- Worst case: BlackBox emits `kind: rejected-implementation-defect` because it can't probe the running app
- **Workaround for the first test**: manually merge the PR after WhiteBox approves (skip BlackBox by closing the issue), then iterate on BlackBox SKILL.md if its behavior surprises us

---

## 10. Cleanup after the test

```bash
# Stop sweet-home — Ctrl-C in the terminal that ran cargo run

# Prune worktrees
cd ~/dev/todo-20260512
git worktree prune
rm -rf ~/dev/todo-20260512-worktrees

# (Optional) reset the test repo to a clean state for another run
gh issue list --repo liyoclaw1242/todo-20260512 --state open --json number --jq '.[].number' | while read N; do
    gh issue edit $N --repo liyoclaw1242/todo-20260512 \
        --remove-label "status:in-progress,status:delivered,status:validated,human-review,agent:validator,agent:blackbox-validator,agent:arbiter,agent:human-help" \
        --add-label "status:approved,agent:worker" 2>/dev/null || true
done

# Close any test PRs
gh pr list --repo liyoclaw1242/todo-20260512 --state open --json number --jq '.[].number' | while read N; do
    gh pr close $N --repo liyoclaw1242/todo-20260512 --delete-branch
done
```

---

## 11. Final-state expectations

After a clean happy-path run you should see, on
<https://github.com/liyoclaw1242/todo-20260512>:

- Issue #1 with labels `[kind:workpackage, status:validated]` and zero `agent:*` labels
- Comments from each stage:
  - Worker "delivered" comment with the PR link
  - WhiteBox "approved" verdict
  - BlackBox "approved" verdict
  - "All validators passed. PR is ready for human merge" closing comment
- One PR open against `main` titled `WP #1: [WP] Add GET /todos endpoint…` containing the +4-line diff from `b4a56a6`
- Sweet-home's SQLite has three `one_shot_runs` rows with `status: completed`, total cost ~$1-3

If you see all that — Path B is confirmed working end-to-end. Mark
ADR-0014 amendment as "validated by dogfood test on YYYY-MM-DD".

---

## Quick reference — commits / state to know

| Repo | Commit | What's in it |
|---|---|---|
| liyoclaw1242/agent-sweet-home @ `dd5407f` | `workflow: three v1 dogfood patches` | one_shot.rs (CLAUDE_BINARY env), spawn.rs (strip_json_fence loosened), poll.rs (quarantine no longer removes status:ready) |
| liyoclaw1242/agent-team @ `fee252b` | `workflow: fix two yaml gotchas` | agent-team.workflow.yaml (repo_source uses .workflow-repos.json), .workflow-repos.json template |
| liyoclaw1242/todo-20260512 @ `02cf4c3` | `workflow: vendor agent-team.workflow.yaml` | The test fixture — scaffold + .claude/skills + workflow yaml + repos.json |
| GitHub Issue liyoclaw1242/todo-20260512 #1 | `[WP] Add GET /todos endpoint returning {todos: []}` | Labels: `kind:workpackage, status:approved, agent:worker`; AC×4 in body |

After Mac retest, save the cost/duration numbers + any new findings as
a follow-up ADR amendment.
