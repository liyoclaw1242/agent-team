# Design Workflow

Three modes:
- **Mode A: Design-First** — sketch in Pencil canvas → review → implement in code
- **Mode B: Code-Direct** — implement directly in code (minor changes, design already decided)
- **Mode C: Visual Review** — black-box validation of other agents' PRs

See `SKILL.md` → Mode Routing for how to choose.

---

## Mode A: Design-First (new pages, layouts, major UI changes)

Canvas sketch → Visual review → Code implementation

### Phase 1: Context

1. Read design system: tokens, Tailwind config, component library
2. Read `design-decisions.md` if it exists
3. Read journal entries from `log/`
4. Read `cases/visual-vocabulary.md` for established patterns
5. Scan spec for auto-trigger keywords (see `SKILL.md` → Cases → Auto-trigger Rule)

### Phase 2: Research (for non-trivial tasks)

1. Identify the pattern type (dashboard, settings, card grid, form, etc.)
2. Browse reference sites using `WebFetch`:
   - Awwwards (`https://www.awwwards.com/directory/`) — layout & visual quality
   - Mobbin (`https://mobbin.com/discover/sites/latest`) — real-world component patterns
   - Variant (`https://variant.com/community`) — design system patterns
3. Extract principles, not pixels
4. Record inspiration in `design-decisions.md`

**Gate**: Can you describe the visual approach in one sentence?

### Phase 3: Sketch in Pencil

Create a design proposal on canvas before writing any code:

```bash
# Create initial design
pencil --out {feature-name}.pen \
  --prompt "Design a {description}. Style: {design system context}. Layout: {approach from research}."

# Export preview for self-review
pencil --in {feature-name}.pen --export /tmp/sketch-preview.png --export-scale 2
```

Read the exported PNG. Evaluate against your design intuition and the AI Design Audit checklist.

**Iterate if needed:**
```bash
# Fix issues
pencil --in {feature-name}.pen --out {feature-name}.pen \
  --prompt "Fix: {specific issues you see in the preview}"

# Re-export and re-review
pencil --in {feature-name}.pen --export /tmp/sketch-v2.png --export-scale 2
```

Max 3 iterations. When satisfied, move to code.

**Gate**: Does the sketch look like something you'd approve in a visual review? If not, iterate.

### Phase 4: Implement in Code

Now translate the approved sketch into React/Tailwind:

1. Create branch: `actions/setup-branch.sh`
2. Implement following the sketch as your visual target
3. Apply patterns from `cases/visual-vocabulary.md` (ring borders, spacing scale, etc.)
4. Handle all component states (loading, error, empty)

### Phase 5: Capture + Compare

1. Start dev server: `pnpm dev &`
2. Screenshot the implemented result:
   ```bash
   bash actions/capture-screenshots.sh http://localhost:3000 /tmp/implemented /route
   ```
3. **Compare sketch vs implementation** — read both PNGs:
   - Does the implementation match the sketch?
   - Any details lost in translation?

### Phase 6: Validate

Run the design checklist gate:

```bash
bash validate/check-all.sh implement
```

Review every item. Fix failures against:
- `rules/ai-design-audit.md`
- `rules/accessibility.md`
- `rules/responsive.md`

Max 2 fix-and-revalidate rounds.

**Gate**: All checklist items confirmed.

### Phase 7: Polish

Fix remaining issues from validation. Recapture screenshots to confirm.

### Phase 8: Record

- Update `design-decisions.md` in the repo
- Commit the `.pen` file alongside the code (optional — for design history)

### Phase 9: Deliver

1. Run `actions/deliver.sh` — commit + push + open PR + route to ARCH (deliver.sh handles routing)

### Phase 10: Journal + Distill

1. Write journal entry to `log/` via `actions/write-journal.sh`
2. Distill reusable patterns to `cases/visual-vocabulary.md`
3. Distill review insights to `cases/review-heuristics.md`

---

## Mode B: Code-Direct (minor changes, tweaks, polish)

For tasks where the design is already decided (bug fixes, spacing adjustments, color changes).

Skip Pencil. Go straight to code:

1. **Context** — same as Mode A Phase 1
2. **Implement** — same as Mode A Phase 4 (create branch, code, handle states)
3. **Capture** — screenshot at 3 breakpoints
4. **Validate** — run `bash validate/check-all.sh implement`, review all items
5. **Deliver** — same as Mode A Phase 9
6. **Journal** — same as Mode A Phase 10

---

## Mode C: Visual Review (black-box validation of PRs)

You review **what the user sees**, not the code.

### Phase 1: Setup

```bash
gh pr checkout {PR_NUMBER} --repo {REPO_SLUG}
pnpm install && pnpm dev &
sleep 5
```

### Phase 2: Capture

```bash
# Identify affected routes
gh pr diff {PR_NUMBER} --repo {REPO_SLUG} | grep -E 'app/.*page\.(tsx|ts)' | head -10

# Screenshot all affected routes
bash actions/capture-screenshots.sh http://localhost:3000 /tmp/design-review / /route1 /route2
```

### Phase 3: Validate

Run the review checklist gate:

```bash
bash validate/check-all.sh review
```

Read each screenshot and confirm every item in the checklist:

- **Layout**: hierarchy, spacing, alignment, responsive
- **Typography**: heading scale, readability, line-height
- **Color**: palette cohesion, contrast, interactive distinction
- **Interaction**: buttons clickable, links distinguishable, disabled states
- **Consistency**: matches design system, no one-off styling
- **Dark mode**: intentional, not inverted (if applicable)

### Phase 4: Corrective Sketch (if rejecting)

When you find issues, **show don't tell** — create a Pencil sketch showing the correct version:

```bash
# Create "should look like" design
pencil --out /tmp/correction.pen \
  --prompt "Design a {component/page} that fixes: {issues found}. Match existing design system."

# Export for comparison
pencil --in /tmp/correction.pen --export /tmp/should-look-like.png --export-scale 2
```

Attach both the "current" screenshot and the "should look like" export in your review comment.

### Phase 5: Verdict

**APPROVED**:
```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## Design Review by \`{AGENT_ID}\`

### Visual Assessment
{what looks good}

### Screenshots Reviewed
- mobile (320px): ✓
- tablet (768px): ✓
- desktop (1280px): ✓

**Verdict: APPROVED**"
```

**NEEDS CHANGES**:
```bash
gh pr comment {PR_NUMBER} --repo {REPO_SLUG} \
  --body "## Design Review by \`{AGENT_ID}\`

### Issues Found
1. {what you see} → {what it should look like} (see attached sketch)

### Current vs Expected
Current: [screenshot description]
Expected: [Pencil sketch description]

**Verdict: NEEDS CHANGES**"
```

**Design does NOT merge, reject, or reassign.** Post your verdict, then route back to ARCH:

```bash
bash scripts/route.sh "{REPO_SLUG}" {N} arch "{AGENT_ID}"
```

ARCH reads the verdict and decides: merge (if approved), route back to FE (if needs changes), or escalate.

### Phase 6: Journal + Distill

1. Write journal — what you reviewed, findings, verdict
2. Distill recurring issues to `cases/review-heuristics.md`
3. Capture good patterns from approved PRs to `cases/visual-vocabulary.md`
