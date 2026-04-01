# Design Workflow

Two modes: **Implementation** (create/modify UI) and **Visual Review** (black-box validation of FE work).

---

## Mode A: Implementation

Iterative: Context → Research → Generate → Capture → Audit → Polish → Record → Deliver → Journal

### Phase 1: Context

1. Read design system: tokens, Tailwind config, component library
2. Read `design-decisions.md` if it exists
3. Read journal entries from `log/`
4. Understand the existing visual language

### Phase 2: Research (for non-trivial tasks)

Skip this phase for minor fixes or polish. Activate for:
- New page layouts
- New component types the project hasn't used before
- Design system-level decisions

1. **Identify the pattern** — what type of UI are you building? (dashboard, settings, card grid, form, etc.)
2. **Browse reference sites** using `WebFetch`:
   - Awwwards (`https://www.awwwards.com/directory/`) — layout & visual quality
   - Mobbin (`https://mobbin.com/discover/sites/latest`) — real-world component patterns
   - Variant (`https://variant.com/community`) — design system patterns
3. **Extract principles, not pixels** — note spacing ratios, color relationships, hierarchy techniques
4. **Record inspiration** in `design-decisions.md` with source attribution

**Gate**: Can you describe the visual approach in one sentence? If not, research more.

### Phase 3: Generate

Implement based on issue type:
- **Component** → styling, a11y, responsive, design tokens
- **Layout/page** → responsive breakpoints, spacing, asymmetric layouts
- **Icon selection** → check project's icon library first

Design techniques:
- Ring borders (not solid) for subtle containers
- Concentric border radius
- Tight letter-spacing on headlines
- Shadow + ring combo for depth
- Button sizing: 36-38px height

### Phase 3: Capture

**Take screenshots to verify your own work visually:**

1. Start dev server if not running: `pnpm dev &`
2. Capture screenshots:
   ```bash
   bash skills/design/actions/capture-screenshots.sh http://localhost:3000 /tmp/design-review /route/you/changed
   ```
3. **Read each screenshot** (Claude can see images):
   ```bash
   # Claude will visually inspect these
   ls /tmp/design-review/*.png
   ```
   Read each .png file to see the actual rendered result.

### Phase 4: Audit

Review the screenshots against quality rules:

**Critical (must fix)**:
- [ ] Missing focus indicators on interactive elements
- [ ] Text unreadable (contrast, size, truncation)
- [ ] Broken layout at any breakpoint
- [ ] Elements overlapping or overflowing

**Warning (should fix)**:
- [ ] Everything centered (no visual hierarchy)
- [ ] Identical card grids (no variation in emphasis)
- [ ] Muddy borders (solid gray vs ring technique)
- [ ] Inconsistent spacing

**Visual polish**:
- [ ] Shadow quality (too harsh? too subtle?)
- [ ] Color harmony (do the colors work together?)
- [ ] Typography hierarchy (clear heading > body distinction?)
- [ ] Whitespace balance (breathing room?)

### Phase 5: Polish

Fix issues found. Recapture + re-audit. Max 2 rounds.

### Phase 6: Record

Update `design-decisions.md` with choices made.

### Phase 7: Deliver + Journal

---

## Mode B: Visual Review (black-box validation of FE/other agent's PR)

This is the Design equivalent of QA's code review — but you look at **what the user sees**, not the code.

### Phase 1: Setup

1. Checkout the PR branch:
   ```bash
   gh pr checkout {PR_NUMBER} --repo {REPO_SLUG}
   ```
2. Install dependencies and start dev server:
   ```bash
   pnpm install && pnpm dev &
   ```
3. Wait for server to be ready:
   ```bash
   sleep 5
   curl -sf http://localhost:3000 > /dev/null || sleep 5
   ```

### Phase 2: Capture

Identify which pages/routes the PR affects (from PR description or diff), then screenshot them all:

```bash
# Determine affected routes from the PR diff
gh pr diff {PR_NUMBER} --repo {REPO_SLUG} | grep -E 'app/.*page\.(tsx|ts)' | head -10

# Capture all affected routes at 3 breakpoints
bash skills/design/actions/capture-screenshots.sh \
  http://localhost:3000 \
  /tmp/design-review \
  / /affected-route-1 /affected-route-2
```

### Phase 3: Visual Review

**Read each screenshot** and evaluate:

#### Layout & Composition
- [ ] Visual hierarchy clear? (what draws the eye first?)
- [ ] Spacing consistent? (same scale used throughout?)
- [ ] Alignment clean? (no jagged edges, elements lined up?)
- [ ] Responsive? (mobile doesn't just squish desktop)

#### Typography
- [ ] Heading hierarchy clear? (h1 > h2 > h3 visually distinct?)
- [ ] Body text readable? (size, line-height, contrast)
- [ ] No orphaned words or awkward wrapping?

#### Color & Contrast
- [ ] Color palette cohesive? (not random colors)
- [ ] Sufficient contrast for readability?
- [ ] Interactive elements visually distinct from static?
- [ ] Dark mode (if applicable) looks intentional, not inverted?

#### Interaction Cues
- [ ] Buttons look clickable? (not flat text)
- [ ] Links distinguishable from text?
- [ ] Disabled states visually distinct?
- [ ] Hover/focus states present? (capture with Playwright hover if needed)

#### Consistency
- [ ] Matches design system / existing pages?
- [ ] Same component style used across similar elements?
- [ ] No "one-off" styling that breaks the visual language?

### Phase 4: Verdict

**APPROVED** — post comment with visual assessment:
```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## Design Review by \`{AGENT_ID}\`

### Visual Assessment
{summary of what looks good}

### Screenshots Reviewed
- mobile (320px): ✓
- tablet (768px): ✓
- desktop (1280px): ✓

**Verdict: APPROVED** — visual quality meets standards."
```

**NEEDS CHANGES** — post specific visual feedback:
```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## Design Review by \`{AGENT_ID}\`

### Issues Found
1. {specific visual issue — describe what you see, where, and what it should look like}
2. {another issue}

### Screenshots
(Attach or describe the problematic screenshots)

**Verdict: NEEDS CHANGES** — see issues above."
```

If rejected: close PR, post feedback on the issue, reset status to `ready`.

### Phase 5: Journal

Record what visual patterns you observed in this repo.
