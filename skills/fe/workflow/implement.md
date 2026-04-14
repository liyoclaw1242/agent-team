# Frontend Implementation Workflow

Phases: Onboard Context → Locate Impact → Plan → Implement → Self-Test → Validate → Deliver → Journal

Each phase has a gate. Do not skip ahead.

---

## Phase 1: Onboard Context

> "An engineer who understands the project overview can locate the right file in seconds.
> One who doesn't will search for hours and still modify the wrong component."

You should already have project context from Phase 0 (onboarding). If this is your first task, go back and read the README + project structure first.

Before touching any code for this task:

1. **Re-read the project overview** — refresh your mental model of the component tree, routing, state management, and design system.
2. **Read `design-decisions.md`** if it exists — know the established patterns.
3. **Read last 3 journal entries** for this repo — learn what previous agents discovered.

**Gate**: Can you describe the component hierarchy relevant to this task? If not, read more.

---

## Phase 2: Locate Impact

Based on your understanding of the project, determine:

1. **Which components are affected?** — trace from the route/page down to the leaf components.
2. **Which shared modules are involved?** — hooks, utils, API clients, stores.
3. **What's the state flow?** — where does data come from, how does it transform, where does it render?
4. **Are there design tokens/theme values involved?** — check Tailwind config, CSS variables, theme files.
5. **What tests exist for these components?** — locate test files, understand coverage.

**Do NOT guess file paths.** Use the project structure from onboarding. If uncertain, search:
```bash
grep -rn "ComponentName" --include="*.tsx" --include="*.ts" src/
```

**Gate**: Concrete list of files to read and modify. No assumptions.

---

## Phase 3: Plan

1. **List changes** — for each file: what changes and why.
2. **Determine test strategy** — check the issue spec's `testing` field:
   - `unit-required` → plan unit tests for hooks/components (see `rules/testing.md` Mode 2)
   - `self-test-only` or not specified → plan browser self-test steps only
3. **Check for blockers** — missing API endpoints, unclear design spec, dependency on other tasks.
4. **Conservative scope** — if the spec says "add a button", add a button. Don't redesign the page.
5. **Spec feasibility check** — does the spec conflict with:
   - The project's tech stack constraints? (e.g. Server Components can't use client-side APIs)
   - Existing code that the spec didn't account for? (e.g. an API already exists)
   - Your role's rules? (e.g. visual-logic-separation violated by the spec's design)
   - A better approach you know from your codebase knowledge?

### If spec has problems → feedback to ARCH

Don't force an implementation that contradicts what you know. You understand the codebase deeper than ARCH does. Feed back:

```bash
# 1. Comment with your technical insight
gh issue comment {N} --repo {REPO_SLUG} \
  --body "## Technical Feedback from \`{AGENT_ID}\`

### Conflict
{what the spec asks} conflicts with {what you know about the codebase}.

### Suggestion
{your recommended approach, with reasoning}

### Affected
{which parts of the spec need to change}"

# 2. Hand back to ARCH for re-evaluation (MUST use route.sh)
bash scripts/route.sh "{REPO_SLUG}" {N} arch "{AGENT_ID}"
```

Then move on to your next task. Don't wait for ARCH — they'll update the spec and it will come back to you.

6. **Auto-load Feature Cases** — scan the issue/spec text for these keywords:
   - dark mode, theme toggle, theme switch, light/dark, color scheme → read `cases/dark-mode.md`
   - i18n, internationalization, multi-language, locale, translation, 多語系 → read `cases/i18n-routing.md`
   - auth, login, logout, sign in, sign up, register, protected route, session → read `cases/auth-flow.md`
   - form, validation, input, submit, react-hook-form, zod → read `cases/form-validation.md`

   Multiple cases can activate simultaneously (e.g. a login page triggers both Auth Flow and Form Validation). Use the case as your implementation baseline, then adapt to the project's existing patterns.

**Gate**: Spec is feasible with your tech stack. If not, feed back and move on.

---

## Phase 4: Implement

1. **Create branch**: run `actions/setup-branch.sh`

2. **Follow existing patterns** — match the code around you:
   - Function components? Stay with function components.
   - CSS modules? Don't introduce styled-components.
   - Existing `Button` component? Use it, don't make a new one.

3. **Write unit tests alongside code** — only if spec says `testing: unit-required`:
   - Testing Library: `getByRole` > `getByLabelText` > `getByText` > `getByTestId`
   - Test behavior, not implementation details
   - See `rules/testing.md` Mode 2 for what needs unit tests

4. **Handle all states**:
   - Default (happy path render)
   - Loading (skeleton/spinner)
   - Error (error message + retry action)
   - Empty (zero-data state with guidance)
   - Interactive (hover, focus, click, keyboard)

5. **Accessibility from the start** — not bolted on after:
   - Semantic HTML elements
   - Keyboard navigation
   - ARIA labels for non-obvious elements
   - Focus management for modals/dialogs

---

## Phase 5: Self-Test

> "Build it like production, test it like a user."

This phase is mandatory for every task. You are the first QA — catch your own bugs before anyone else sees them.

### 5a. Production Build

```bash
pnpm build
```

If build fails, go back to Phase 4 and fix. Do not proceed with a broken build.

### 5b. Start & Test via Browser MCP

```bash
pnpm start &
```

Using Browser MCP, walk through each Acceptance Criteria item from the issue spec:

1. **Navigate** to the affected route
2. **Operate** — click, type, scroll, as described in the AC
3. **Observe** — does the UI respond correctly?
4. **Check DevTools** — console errors? network failures? JS exceptions?
5. **Screenshot** — capture evidence at each key step

### 5c. Write Self-Test Record

Write results to `/tmp/self-test-issue-{N}.md`. See `rules/testing.md` for the file format.

**If any step fails**: go back to Phase 4, fix, rebuild, re-test. Max 3 rounds.

**Gate**: All AC items pass. Self-test file exists at `/tmp/self-test-issue-{N}.md`.

---

## Phase 6: Validate

Run `validate/check-all.sh` for static checks (TypeScript, lint, a11y scan, security scan, git hygiene).

Max 3 rounds: validate → fix → re-validate.

**Gate**: All checks pass AND self-test passed in Phase 5.

---

## Phase 7: Deliver

1. Run `actions/deliver.sh` — commit + push + open PR + route to ARCH
   - `deliver.sh` will verify self-test file exists before proceeding
   - Self-test record is automatically posted as a PR comment

---

## Phase 8: Journal

Write entry to `log/` via `actions/write-journal.sh`. Focus on:
- Component patterns discovered
- Design tokens and naming conventions
- Self-test findings (what broke during testing, what was tricky to verify)
- Repo-specific gotchas
