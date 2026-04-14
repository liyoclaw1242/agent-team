# Skill Cross-Interaction Audit

Systematic review of all 7 agent skills for conflicts, inconsistencies, and edge cases.

---

## Iteration 1: ARCH ↔ QA

**Scenario**: ARCH dispatches a task to BE, BE delivers PR, ARCH routes to QA, QA verifies.

### Findings

1. **PASS — QA routing back to ARCH is clean.** QA's verify.md Phase 7 always routes via `route.sh` back to ARCH. ARCH's Mode D handles triage. No conflict.

2. **PASS — Verdict terminology is consistent.** QA uses PASS/FAIL/BLOCKED. ARCH's triage recognizes these. `route.sh` regex matches `Verdict.*PASS`, `Verdict.*FAIL`.

3. **ISSUE — QA re-route guard may be too strict.** `route.sh` Rule 1 blocks re-routing to QA if QA already gave a verdict. But what if ARCH rejects QA's FAIL verdict and asks QA to re-verify after BE fixes? ARCH would need to manually remove the old verdict comment or use a different mechanism.
   - **Severity**: Medium
   - **Fix**: Allow ARCH to override the guard (e.g., `--force` flag or ARCH clears the verdict label before re-routing).

4. **ISSUE — QA Phase 0 checks self-test in PR comments, but BE self-test is in PR body.** QA verify.md Phase 0 searches `gh pr view --comments` for `# Self-Test:`, but BE's deliver workflow puts the self-test in the PR body (not as a comment). These are different fields.
   - **Severity**: High — QA will always report BLOCKED because the search targets comments, not body.
   - **Fix**: QA Phase 0 should check PR body (`--json body`) OR PR comments.

---

## Iteration 2: ARCH ↔ FE

**Scenario**: ARCH decomposes a request into FE tasks, FE implements and delivers.

### Findings

5. **PASS — Spec feasibility feedback loop works.** FE Plan Phase 3 has explicit feedback-to-ARCH flow. ARCH Mode C handles re-evaluation. Both use `route.sh`.

6. **ISSUE — ARCH spec `testing` field not documented in ARCH skill.** FE's workflow references `spec's testing field` (e.g., `unit-required`, `self-test-only`), but ARCH's decomposition standards don't mention this field. ARCH might not include it in issue specs.
   - **Severity**: Medium — FE defaults to `self-test-only` if missing, so not a blocker, but unit tests may never get requested.
   - **Fix**: Add `testing` field to ARCH's decomposition standards.

---

## Iteration 3: ARCH ↔ BE

**Scenario**: ARCH creates BE tasks, BE implements with TDD.

### Findings

7. **PASS — BE feedback loop to ARCH matches the same pattern as FE.** Both use `route.sh`.

8. **ISSUE — BE's TDD workflow doesn't mention ARCH's `testing` field.** Unlike FE which checks for `testing: unit-required`, BE always does TDD regardless. This is fine (TDD is mandatory for BE), but creates an inconsistency: ARCH's spec may say `testing: self-test-only` for a BE task, which conflicts with BE's "TDD is mandatory" rule.
   - **Severity**: Low — BE's stricter rule wins, which is the safe default.
   - **Fix**: ARCH should never set `testing: self-test-only` for BE tasks. Document this.

---

## Iteration 4: ARCH ↔ OPS

**Scenario**: ARCH creates OPS infra tasks (CI, deploy config, preview setup).

### Findings

9. **PASS — OPS Scope Guard is well-defined.** OPS knows it can touch `.github/workflows/`, `Dockerfile`, `vercel.json`, `playwright.config.ts` but not `src/`. This prevents OPS/FE file ownership conflicts.

10. **ISSUE — OPS `playwright.config.ts` shared with QA.** OPS SKILL.md says OPS owns `playwright.config.ts`, but QA's Codify phase also writes to `e2e/` and depends on `playwright.config.ts`. If OPS changes the config while QA has pending E2E changes, merge conflicts.
    - **Severity**: Low — `playwright.config.ts` changes are rare.
    - **Fix**: Document that OPS owns config, QA owns `e2e/*.spec.ts`. Already mostly clear but could be explicit.

---

## Iteration 5: ARCH ↔ DESIGN

**Scenario**: ARCH routes PR to Design for visual review after FE delivers.

### Findings

11. **PASS — Design Mode C (Visual Review) handles this cleanly.** Design receives PR, screenshots, gives APPROVED/NEEDS_CHANGES verdict.

12. **ISSUE — `route.sh` blocks re-routing to Design after first verdict.** Rule 2 blocks if Design already gave a verdict. Same problem as QA (Finding #3) — if FE fixes and needs re-review, ARCH can't re-route.
    - **Severity**: Medium
    - **Fix**: Same as #3 — add override mechanism.

---

## Iteration 6: ARCH ↔ DEBUG

**Scenario**: QA fails a PR, ARCH routes to DEBUG for root cause analysis.

### Findings

13. **PASS — DEBUG's dispatch suggestion table aligns with ARCH's routing options.** DEBUG suggests FE/BE/OPS/ARCH, ARCH makes the final call. Clear separation of diagnosis vs. decision.

14. **ISSUE — DEBUG assumes observability stack exists.** DEBUG SKILL.md references Grafana, Prometheus, Loki, Tempo, Faro. Many projects won't have this. No fallback described.
    - **Severity**: Medium — DEBUG would be blocked on projects without observability.
    - **Fix**: Add fallback investigation methods (console logs, local reproduction, git bisect) for projects without full observability.

---

## Iteration 7: FE ↔ QA

**Scenario**: FE delivers PR with self-test, QA verifies.

### Findings

15. **CRITICAL — Self-test location mismatch (same as #4).** FE's deliver.sh posts self-test as a PR comment (per the updated workflow). QA Phase 0 looks for PR comments with `# Self-Test:` prefix. BUT — the earlier BE workflow puts self-test in PR body. Inconsistency between FE and BE self-test locations.
    - **Severity**: High
    - **Fix**: Standardize: both FE and BE should post self-test as PR comment (FE already does via deliver.sh).

16. **PASS — QA targets preview URL, not localhost.** QA verify.md Phase 1 gets preview URL from PR comments. FE self-tests locally. No environment collision.

---

## Iteration 8: FE ↔ DESIGN

**Scenario**: FE implements a page, Design reviews the visual output.

### Findings

17. **PASS — File ownership is clear.** FE owns `src/`, Design reviews via screenshots. Design Mode C is black-box — doesn't touch FE code.

18. **ISSUE — Design Mode A can create code (implement from sketch).** When Design uses Mode A (design-first), it implements React/Tailwind code. This overlaps with FE's domain. If both Design and FE are assigned to the same feature, who owns what?
    - **Severity**: Medium
    - **Fix**: ARCH should never assign both Design Mode A and FE to the same component. Design Mode A is for when there's no separate FE task.

---

## Iteration 9: FE ↔ OPS

**Scenario**: FE needs preview URL for self-test, OPS manages preview deploys.

### Findings

19. **PASS — Clear boundary.** FE self-tests against localhost (`pnpm start`). OPS provides preview URL for QA. No direct dependency.

20. **ISSUE — FE `validate/check-all.sh` may not support Go projects in monorepo.** If `apps/server` (Go) is added to the monorepo, FE's check-all.sh only looks for `package.json`. Not a problem as long as FE's check-all.sh runs in the right directory.
    - **Severity**: Low — monorepo structure isolates this.

---

## Iteration 10: FE ↔ BE

**Scenario**: FE consumes API built by BE. Parallel development.

### Findings

21. **ISSUE — No API contract handoff mechanism.** ARCH decomposes into FE + BE tasks, but there's no explicit step for BE to publish API contract before FE starts consuming it. FE might build against assumptions that don't match BE's implementation.
    - **Severity**: Medium
    - **Fix**: ARCH's decomposition should enforce order: BE API → FE integration. Or use OpenAPI spec as shared contract (already suggested in issue #100).

---

## Iteration 11: FE ↔ DEBUG

**Scenario**: DEBUG diagnoses a frontend bug, dispatches fix back to FE.

### Findings

22. **PASS — DEBUG's dispatch table correctly identifies frontend symptoms** (TypeScript/React/CSS/browser → FE). Clean handoff.

23. **ISSUE — DEBUG's observability tools don't cover frontend well.** Faro is mentioned but no cases or actions for frontend-specific debugging (React DevTools, bundle analysis, hydration errors).
    - **Severity**: Low — DEBUG identifies the symptoms and dispatches to FE. FE has its own debugging context.

---

## Iteration 12: BE ↔ QA

**Scenario**: BE delivers API endpoint, QA verifies via curl against preview.

### Findings

24. **ISSUE — BE self-test in PR body vs QA expecting PR comment.** Same as #4 and #15. BE's workflow puts self-test in PR body markdown. QA Phase 0 searches comments.
    - **Severity**: High (duplicate of #4)

25. **PASS — QA API verification (curl) targets preview URL.** BE deploys to Fly.io preview (or equivalent). QA curls against it. Architecture is sound.

---

## Iteration 13: BE ↔ OPS, QA ↔ OPS

**Scenario**: BE needs Fly.io + Turso deployed. OPS sets up infra. QA needs preview URL.

### Findings

26. **ISSUE — OPS preflight.sh checks for Vercel but not all projects need it.** A pure Go backend project on Fly.io wouldn't have `.vercel/project.json`. Preflight should be project-type-aware.
    - **Severity**: Low — warnings, not failures.

27. **ISSUE — QA preview URL discovery assumes Vercel.** QA verify.md Phase 1 greps for `vercel.app` in PR comments. For Fly.io backend deployments, the URL pattern would be different (`fly.dev`).
    - **Severity**: Medium — QA can't find BE preview URL.
    - **Fix**: QA preview URL discovery should be platform-agnostic (look for any URL posted by deployment bot, not just `vercel.app`).

---

## Iteration 14: DEBUG ↔ OPS, DESIGN ↔ QA

**Scenario A**: DEBUG finds infra root cause, dispatches to OPS.
**Scenario B**: Design reviews PR, QA also reviews PR.

### Findings

28. **PASS — DEBUG → OPS dispatch is clean.** DEBUG suggests OPS for build/deploy/CI issues. ARCH routes.

29. **ISSUE — Design and QA can both be reviewing the same PR.** If ARCH routes to QA and Design simultaneously (or sequentially), both post verdicts. `route.sh` prevents re-routing to either after first verdict. But what if Design says NEEDS_CHANGES and QA says PASS? ARCH needs to reconcile conflicting verdicts.
    - **Severity**: Medium
    - **Fix**: Document in ARCH Mode D: Design verdict takes priority for visual issues, QA verdict takes priority for functional issues. ARCH should route to Design BEFORE QA when visual review is needed.

---

## Iteration 15: Multi-agent edge cases

### Findings

30. **ISSUE — `route.sh` sets `status:ready` on every route.** When routing from QA back to ARCH, status becomes `ready`. But the issue is actually in-triage, not ready for claiming. Could cause another agent to pick it up prematurely.
    - **Severity**: Medium
    - **Fix**: Add `status:triage` for ARCH-bound routing, or only set `ready` when routing to implementers (FE/BE/OPS/Design/Debug).

31. **ISSUE — No timeout/staleness detection.** If an agent claims an issue but crashes or hangs, the issue stays `status:in-progress` forever. No scan detects stale claims.
    - **Severity**: Medium
    - **Fix**: Add staleness scan to ARCH's housekeeping (issues in `status:in-progress` for >2h with no commit activity → reset to `status:ready`).

32. **PASS — `verify-labels.sh` post-routing check prevents label corruption.** Every `route.sh` call validates labels after routing.

---

## Summary

| Severity | Count | Key Issues |
|----------|-------|------------|
| Critical/High | 2 | #4/#15/#24: Self-test location mismatch (PR body vs comment) |
| Medium | 8 | #3/#12: Re-route guard too strict; #6: ARCH missing `testing` field; #14: DEBUG assumes observability; #18: Design/FE overlap; #21: No API contract handoff; #27: QA assumes Vercel URLs; #29: Conflicting Design/QA verdicts; #30: `status:ready` on ARCH routing; #31: No staleness detection |
| Low | 4 | #8: BE TDD vs ARCH testing field; #10: playwright.config ownership; #20: FE check-all.sh scope; #26: OPS preflight Vercel assumption |

### Top 3 Fixes (highest impact)

1. **Standardize self-test location** — both FE and BE post self-test as PR comment, QA checks comments. (Fixes #4, #15, #24)
2. **Add `--force` to route.sh for ARCH** — allow ARCH to override QA/Design re-route guards for re-verification cycles. (Fixes #3, #12)
3. **Platform-agnostic preview URL discovery** — QA should detect any deployment URL, not just `vercel.app`. (Fixes #27)

### Fixed in `b1dece2`

- #4/#15/#24 — BE self-test → PR comment ✅
- #27 — QA preview URL platform-agnostic ✅
- #3/#12 — route.sh `--force` ✅
- #30 — route to ARCH uses `status:review` ✅
- #6/#29 — ARCH `testing` field + verdict priority ✅
- #14 — DEBUG fallback methods ✅

### Remaining Low Severity (deferred)

- #8 — BE TDD vs ARCH testing field: BE always does TDD regardless of spec. Harmless inconsistency.
- #10 — `playwright.config.ts` shared by OPS/QA: rare conflict, documented ownership is sufficient.
- #20 — FE `check-all.sh` in monorepo with Go: monorepo dir isolation prevents issues.
- #26 — OPS `preflight.sh` checks Vercel even for non-Vercel projects: warnings only, not failures.

---

# Round 2: End-to-End Scenario Simulations

Testing complete lifecycle flows to find deeper integration issues.

---

## Iteration 16: Full lifecycle — New Feature (ARCH → BE → FE → QA → ARCH merge)

**Scenario**: User requests "Add user management API + page". ARCH decomposes into BE task (API) + FE task (page) + QA task (test plan).

### Simulation

1. ARCH creates 3 issues: `agent:be` (API), `agent:fe` (page, depends on BE), `agent:qa` (test plan)
2. BE picks up, implements with TDD, writes self-test to `/tmp/self-test-issue-{N}.md`, runs `deliver.sh`
3. `deliver.sh` commits, pushes, creates PR, posts self-test as PR comment, routes to ARCH
4. ARCH receives (with `status:review`), routes to QA
5. QA Phase 0 checks self-test comment → found → proceeds
6. QA Phase 1 gets preview URL → Fly.io (`fly.dev`) → matched by new regex → proceeds
7. QA verifies, PASS → routes to ARCH
8. ARCH merges

### Findings

33. **ISSUE — FE task blocked until BE merges.** ARCH decomposition says `Order: Data Model → API → UI → QA`, but how does FE know when BE is done? There's no automatic unblocking mechanism when BE's PR is merged.
    - **Severity**: Medium
    - **Status**: Partially covered — ARCH has `scan-unblock.sh` in housekeeping. Need to verify it handles this case.

34. **ISSUE — QA test plan created in parallel but may reference endpoints that don't exist yet.** QA shift-left means test plan is written before BE finishes. If BE changes the API shape during TDD, the test plan is stale.
    - **Severity**: Low — QA should re-read the spec before executing. Plan workflow Phase 1 says "Read the spec" which should include any updated API contract.

---

## Iteration 17: Bug Report Flow (user → ARCH → DEBUG → BE → QA)

**Scenario**: User reports "API returns 500 on user creation". ARCH routes to DEBUG.

### Simulation

1. ARCH creates issue `agent:debug`, `status:ready`
2. DEBUG picks up, tries observability stack → project has none
3. DEBUG uses fallback: application logs, local reproduction, git bisect
4. DEBUG finds root cause: missing null check in DB query
5. DEBUG writes report, suggests `be` as fix owner, routes to ARCH
6. ARCH routes to BE
7. BE fixes with TDD (write failing test for null case → fix → green), delivers
8. ARCH routes to QA (no prior verdict, `--force` not needed)
9. QA verifies fix

### Findings

35. **PASS — DEBUG → ARCH → BE flow works cleanly.** DEBUG diagnoses, ARCH dispatches, BE fixes. No conflicts.

36. **ISSUE — DEBUG doesn't create a branch or PR.** DEBUG's workflow is `investigate.md` (Reproduce → Observe → Trace → Diagnose → Report → Dispatch → Journal). But the report is just a comment on the issue. If DEBUG needs to add a reproduction script or test file, where does it go?
    - **Severity**: Low — DEBUG dispatches to implementers, doesn't code. But a `reproduce.sh` would be useful.

---

## Iteration 18: Design Review Rejection Loop (FE → ARCH → Design → FE → Design)

**Scenario**: FE delivers a dashboard page. ARCH routes to Design for visual review. Design says NEEDS_CHANGES.

### Simulation

1. FE delivers PR, routes to ARCH
2. ARCH routes to Design (Mode C: Visual Review)
3. Design screenshots, finds issues (e.g., bad spacing, wrong color), posts NEEDS_CHANGES verdict
4. Design routes to ARCH
5. ARCH routes back to FE to fix visual issues
6. FE fixes, delivers updated PR
7. ARCH wants to re-route to Design → `route.sh` blocks (Design already gave verdict)
8. ARCH uses `--force` → re-routes to Design
9. Design re-reviews → APPROVED

### Findings

37. **PASS — `--force` flag fixes the re-route loop.** Without the fix from this audit, step 8 would have been permanently blocked.

38. **ISSUE — When should ARCH route to Design vs QA first?** Currently no documented order. If ARCH routes to QA first and QA passes, then Design finds visual issues, the functional work was wasted effort (QA might need to re-verify after visual fixes).
    - **Severity**: Medium
    - **Recommendation**: Document in ARCH: route to Design BEFORE QA for tasks with visual components. Already partially addressed in verdict priority table, but the routing ORDER should be explicit.

---

## Iteration 19: Parallel Agents — Worktree Hazard

**Scenario**: BE agent and FE agent both working on the same repo simultaneously.

### Simulation

1. ARCH dispatches BE issue #10 and FE issue #11 in parallel
2. BE creates branch `agent/be-1/issue-10`, FE creates `agent/fe-1/issue-11`
3. Both agents run `git add -A` in `deliver.sh`
4. If they share the same working tree → one agent commits the other's WIP

### Findings

39. **KNOWN ISSUE — Shared worktree hazard.** Already documented in memory (`feedback_shared_worktree_hazard.md`). `deliver.sh` uses `git add -A` which is dangerous.
    - **Status**: Known. `deliver.sh` should use `git add` with explicit file lists, or agents should work in isolated worktrees. Memory says "always `git status` before `deliver.sh`/`git add -A`".
    - **Recommendation**: Update `deliver.sh` to run `git status` check before `git add -A` and warn if untracked files exist that aren't part of the current issue.

---

## Iteration 20: OPS Preflight in CI Context

**Scenario**: OPS agent sets up CI pipeline. CI runner doesn't have local CLI auth.

### Simulation

1. ARCH creates issue: "Set up GitHub Actions CI pipeline"
2. OPS picks up, runs `preflight.sh`
3. Preflight checks `vercel whoami`, `fly auth whoami`, `turso auth whoami`
4. All pass locally, but CI runner won't have these CLIs or auth

### Findings

40. **ISSUE — OPS preflight is local-only.** It verifies the developer machine, not the CI environment. CI uses tokens/secrets, not CLI auth.
    - **Severity**: Low — preflight is for the agent's local capability check, not CI. CI config uses `VERCEL_TOKEN`, `FLY_API_TOKEN` etc. in GitHub Actions secrets.
    - **Recommendation**: Add a note in preflight.sh output that CI auth is separate (via platform secrets, not CLI login).

---

## Iteration 21: QA Codify → OPS CI Integration

**Scenario**: QA codifies E2E tests after PASS. OPS needs to make sure CI runs them.

### Simulation

1. QA verifies, PASS, enters Codify phase
2. QA writes `e2e/user-management.spec.ts`
3. QA commits on QA branch, routes to ARCH
4. ARCH merges QA's E2E tests
5. Next PR → CI should run `pnpm exec playwright test`
6. But OPS hasn't set up the E2E CI step yet

### Findings

41. **ISSUE — QA Codify creates E2E tests but depends on OPS CI setup.** QA's "When NOT to Codify" section says "No E2E infrastructure → create follow-up issue for ARCH". But there's no guarantee ARCH will prioritize the OPS task before the next PR.
    - **Severity**: Medium
    - **Recommendation**: First time QA codifies E2E tests for a repo, QA should check if `playwright.config.ts` and `.github/workflows/e2e.yml` exist. If not, create a blocking follow-up issue for OPS before committing the tests.

---

## Iteration 22: Multi-repo Scenario

**Scenario**: Agent team operates across two repos (e.g., `whitelabel-admin` frontend + separate Go backend repo).

### Findings

42. **ISSUE — `route.sh` and all skills assume single-repo.** `REPO_SLUG` is passed per-call, which is correct. But agent claim/release scripts, journal logs, and preflight checks don't account for multi-repo workflows.
    - **Severity**: Low — current setup is monorepo. Multi-repo would need `deliver.sh` to handle cross-repo PRs.

---

## Iteration 23: ARCH scan-unblock.sh dependency chain

**Scenario**: Issue #11 (FE) depends on #10 (BE). BE finishes. Does FE auto-unblock?

### Findings

43. **NEED TO VERIFY — Does `scan-unblock.sh` exist and work?** ARCH SKILL.md references it in housekeeping but we haven't read it.

---

## Round 2 Summary

| # | Severity | Issue |
|---|----------|-------|
| 33 | Medium | FE blocked on BE — dependency unblocking needs verification |
| 34 | Low | QA test plan may go stale during parallel dev |
| 36 | Low | DEBUG has no mechanism to attach reproduction artifacts |
| 38 | Medium | ARCH should route Design BEFORE QA for visual tasks |
| 39 | Known | Shared worktree `git add -A` hazard |
| 40 | Low | OPS preflight is local-only, doesn't cover CI |
| 41 | Medium | QA Codify depends on OPS E2E CI setup |
| 42 | Low | Single-repo assumption in scripts |
| 43 | Verified ✅ | `scan-unblock.sh` works — uses `<!-- deps: N,N -->` in issue body |

### Fixed in Round 2

- #33 — ARCH decomposition now documents `<!-- deps: -->` format for `scan-unblock.sh` ✅
- #38 — ARCH order updated: Design review BEFORE QA for visual tasks ✅

---

# Round 3: Stress Tests & Edge Cases

Deep-dive on scripts, error paths, and concurrent operation scenarios.

---

## Iteration 24: QA review.md vs verify.md — dual workflow confusion

**Scenario**: QA has TWO workflows — `review.md` (code review + functional test) and `verify.md` (test plan execution). When does QA use which?

### Findings

44. **ISSUE — QA has two entry points with overlapping scope.** `review.md` Mode B does functional testing against preview URL. `verify.md` Phase 2-5 also does functional testing against preview URL. If ARCH routes to QA, which workflow does QA follow?
    - **Severity**: Medium
    - **Analysis**: `review.md` is for code review + quick functional smoke. `verify.md` is for full test plan execution. But `review.md` Mode A Phase 5 can merge PRs directly (`gh pr merge`), which conflicts with ARCH being the "sole merge authority."
    - **Fix**: 
      1. Remove `gh pr merge` from `review.md` — QA should never merge, always route back to ARCH.
      2. Document when to use which: `review.md` for code review tasks, `verify.md` for QA verification tasks with test plans.

---

## Iteration 25: QA review.md merge authority violation

**Scenario**: QA review.md Mode A Phase 5 says "APPROVED → merge" with `gh pr merge`.

### Findings

45. **ISSUE — QA review.md bypasses ARCH merge authority.** ARCH SKILL.md explicitly states "Only ARCH merges PRs (`gh pr merge`)". But `review.md` line 88-89 has QA merging directly. And `route.sh` enforces that all agents route back to ARCH.
    - **Severity**: High — violates the central authority model.
    - **Fix**: Replace direct merge in review.md with route-to-ARCH.

---

## Iteration 26: QA review.md preview URL still Vercel-only

**Scenario**: QA review.md Mode B Phase 1 gets preview URL.

### Findings

46. **ISSUE — review.md uses Vercel-only URL pattern.** Line 113 greps for `vercel\.app`. Same issue as #27 but in a different file.
    - **Severity**: Medium
    - **Fix**: Apply same platform-agnostic regex as verify.md.

---

## Iteration 27: ARCH Mode D pre-triage auto-merge safety

**Scenario**: `pre-triage.sh` auto-merges QA PASS PRs without ARCH reviewing.

### Findings

47. **NEED TO VERIFY — Does `pre-triage.sh` auto-merge?** ARCH workflow says "QA PASS → merge and PR delivered → route to QA are already handled by pre-triage.sh." If pre-triage auto-merges, it could merge without Design review for visual PRs.
    - **Severity**: Potentially High
    - **Status**: Need to read `pre-triage.sh`

---

## Iteration 28: deliver.sh git add -A race condition

**Scenario**: All roles use shared `deliver.sh` (or role-specific copies) with `git add -A`.

### Findings

48. **ISSUE — BE and FE deliver.sh both use `git add -A`.** This is the same #39 shared worktree hazard but now confirmed across both roles. The scripts are identical in this regard.
    - **Severity**: Medium (known, deferred)
    - **Status**: Documented in memory, not fixing now.

---

## Iteration 29: ARCH Mode 0 Bootstrap pushes directly to main

**Scenario**: ARCH bootstraps `arch.md` and pushes to main without PR.

### Findings

49. **ISSUE — Mode 0 commits directly to main.** `git push origin main` in architect.md Step 8. All other agents use branches + PRs. ARCH bypasses its own review process.
    - **Severity**: Low — `arch.md` is a documentation file, not code. Direct push is intentional for bootstrapping. But could conflict if main has branch protection rules.
    - **Recommendation**: Note that this requires main branch push access. If branch protection is enabled, ARCH should create a PR instead.

---

## Iteration 30: Design Mode A creates code — potential file conflict with FE

**Scenario**: Design Mode A implements React/Tailwind code for a new page. FE is also assigned to build pages.

### Findings

50. **ISSUE — Design Mode A and FE both write to `src/` or `apps/*/src/`.** OPS Scope Guard says OPS should NOT modify `src/`. But Design has no equivalent Scope Guard — it can write anywhere FE writes.
    - **Severity**: Medium (same as #18)
    - **Fix**: Add Scope Guard to Design SKILL.md: Design Mode A should only create files in its branch, and ARCH should never dispatch both Design Mode A and FE to the same component.

## Round 3 Summary

| # | Severity | Issue |
|---|----------|-------|
| 44 | Medium | QA has two overlapping workflows (review.md vs verify.md) |
| 45 | High | QA review.md merges PRs directly, violating ARCH sole merge authority |
| 46 | Medium | QA review.md preview URL still Vercel-only |
| 47 | Unknown | pre-triage.sh may auto-merge without Design review |
| 48 | Medium | deliver.sh `git add -A` race (known, deferred) |
| 49 | Low | ARCH Mode 0 pushes directly to main |
| 50 | Medium | Design Mode A has no Scope Guard for `src/` writes |
