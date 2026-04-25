# Workflow — Implement

## Phase 1 — Read spec

Required:

1. The issue body in full
2. The parent issue body (via `<!-- parent: #N -->`) — context the spec relies on
3. Any `<!-- deps: -->` issues' AC — sibling tasks you depend on
4. AC checklist — print or paste into your own scratchpad; you'll tick each off later

Conditional:

5. The relevant `arch-ddd/bounded-contexts/{ctx}.md` if the issue mentions a domain term whose meaning you're not 100% on
6. The Design spec issue (if `<!-- deps: #DESIGN -->` is present) — never freelance UX from your imagination if a Design task exists

After reading, you should be able to state in one sentence: "I will produce X so that the user can do Y, verified by Z." If you can't, the spec is unclear — switch to `workflow/feedback.md`.

## Phase 2 — Reality check

Before writing any code, check whether the spec matches the current codebase:

- Does the file/component the spec references actually exist in this shape?
- Are the libraries / hooks / patterns the spec implies still the project's standard?
- Are sibling tasks' contracts (BE endpoints, Design specs) actually delivered, or still in-flight?

This check takes 5 minutes and saves hours. If anything is off, **stop and switch to `workflow/feedback.md`**. Do not proceed assuming "I'll figure it out as I go" — that path produces work that has to be redone after Mode C anyway.

## Phase 3 — Implement

Walk through the AC, implementing each. General order:

1. **Static structure first** — types, component shells, route definitions
2. **Wire data flow** — API calls, state management, prop passing
3. **Behaviour** — event handlers, async flows, error paths
4. **Visual fidelity** — match the Design spec exactly
5. **Edge cases** — empty states, loading, errors, a11y

While implementing:

- One commit per coherent unit (per `_shared/rules/git.md`'s commit format)
- Each commit references the issue: `feat(billing): add cancel confirmation modal\n\nRefs: #142`
- Run validators after each commit; don't accumulate broken state

## Phase 4 — Self-test

Self-test happens before opening the PR. Write the record at `/tmp/self-test-issue-{N}.md`:

```markdown
# Self-test record — issue #142

## Acceptance criteria
- [x] AC #1: cancel button shows loading state during request
  - Verified: clicked button, observed disabled state + spinner for ~400ms
- [x] AC #2: confirmation modal opens on click
  - Verified: modal renders, focus moves to first interactive element
- [x] AC #3: success closes modal and refreshes parent
  - Verified: tested with mocked successful response
- [x] AC #4: failure re-enables button and shows error
  - Verified: tested with mocked 500 response
- [x] AC #5: ESC key dismisses modal without action
  - Verified: keyboard test in dev tools

## Manual verification
- Browsers tested: Chrome 130, Safari 17, Firefox 128
- A11y: axe shows 0 issues on the affected surfaces
- Reduced motion: disabling animations doesn't break the flow

## Validators
- lint: pass
- typecheck: pass
- test: pass (added 4 component tests, all green)
- a11y: pass

## Ready for review: yes
```

Every box ticked. Every "verified" line says concretely what you did. Empty checkboxes or "verified: yes" without elaboration is the failure mode `rules/self-test-gate.md` exists to prevent.

## Phase 5 — Deliver

```bash
bash actions/deliver.sh \
  --issue $ISSUE_N \
  --self-test /tmp/self-test-issue-$ISSUE_N.md \
  --pr-title "feat(billing): add cancellation confirmation modal" \
  --pr-body-file /tmp/pr-body.md
```

The action:
1. Verifies `/tmp/self-test-issue-{N}.md` exists and every AC checkbox is `[x]`
2. Pushes the branch
3. Opens the PR with `Refs: #N` in body and the self-test record summary
4. Routes the issue to whichever role does first review

The issue typically routes to `agent:qa` if a sibling QA task exists (shift-left), otherwise to `agent:arch` which dispatches to design / qa per the parent's needs.

## Anti-patterns

- **Implementing first, reading spec later** — spec drift becomes invisible. Read first, implement second.
- **Skipping reality check** — saves 5 minutes, costs 5 hours.
- **Stuffing the self-test** — `[x]` without verification evidence is dishonest. The gate is for you, not the bureaucracy.
- **"While I'm here, let me refactor X"** — file a separate issue. Scope creep is how PRs become unreviewable.
- **Treating `agent:fe` as "do anything"** — your scope is the AC. Anything outside is a separate intake.
