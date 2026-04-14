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
