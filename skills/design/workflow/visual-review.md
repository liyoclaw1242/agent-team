# Workflow — Visual Review (Mode B)

Reviewing a fe PR against the design spec. Output: a verdict comment that pre-triage parses and routes from.

## Phase 1 — Read

Required:

1. The issue body — extract the design-spec block from between markers
2. The PR linked to this issue (search PR body for `Refs: #N`)
3. The PR diff — the actual code changes
4. The PR's deployed preview if available (Vercel preview, staging deploy)

Conditional:

5. The QA test plan if QA ran shift-left mode (in issue body between qa-test-plan markers)
6. Recent design specs / verdicts for similar PRs — calibration

If the spec is missing or the PR isn't reviewable yet (still in draft, CI failing), pause:

```bash
# Skip review; route back to arch with note
bash route.sh $ISSUE_N arch \
  --reason "PR not in reviewable state; design review deferred"
```

## Phase 2 — Reality check the diff

Before forming a verdict:

- Does the PR actually implement what the spec specified?
- Are there changes outside the spec scope? (Sometimes fe refactors adjacent code; not always wrong but worth noting.)
- Did fe post Mode C feedback that arch accepted? Then the spec may have been amended — re-read.

## Phase 3 — Inspect against foundations + spec

Three layers to check, in order:

### Layer 1: Foundation compliance

These are systemic checks. Walk through the diff:

- **Type**: are font sizes on the type scale? Are weights from the established set?
- **Color**: are colors referenced via tokens? Any hardcoded hex?
- **Space**: are paddings / margins / gaps on the spacing scale?
- **Hierarchy**: does the implementation produce the hierarchy the spec described, or is it flatter / more chaotic?
- **Iconography**: same icon library? Correct sizes? Aligned with text?

`validate/token-usage.sh` automates the most common foundation violations. Run it; review findings.

### Layer 2: Spec adherence

- Does each visual element match the spec? Type role, color, spacing as specified?
- Are all states implemented? Default / hover / focus / active / disabled / loading / error — the spec listed which apply
- Does interaction match? Transitions, focus management, keyboard support
- Is the responsive behavior as specified?

When the implementation visually differs from spec — even slightly — call it out specifically. "Spec said 16px gap; implementation has 12px" is actionable. "Looks tighter than the spec" isn't.

### Layer 3: Accessibility verification

- Semantic HTML matches spec
- ARIA where spec required it
- Contrast ratios meet the spec's stated levels — verify with a contrast tool
- Touch targets ≥24x24
- Screen reader announcements (e.g., aria-live regions) present
- Reduced motion handled

`validate/contrast.sh` does best-effort contrast verification on color pairs in the diff.

## Phase 4 — Compile findings

Each finding has:

- **Severity** — Critical / Major / Minor (definitions below)
- **Location** — file:line in the PR diff or "in the rendered preview at [URL]"
- **What's wrong** — specifically; not "looks off"
- **Reference** — which spec section, which foundation, which a11y rule

### Severity definitions

- **Critical** — accessibility floor violation (contrast fails AA, missing required ARIA, keyboard inaccessible) OR significant divergence from spec that breaks the user task
- **Major** — visual / interaction divergence from spec that affects perceived quality (wrong type weight, off-scale spacing, missing state)
- **Minor** — refinement needed but not user-impacting (slight color shift, marginal alignment, cosmetic detail)

### Calibration

Use Critical sparingly. A11y violations are always Critical. Spec divergences are usually Major, occasionally Critical (when the divergence breaks the user story). Stylistic preference is Minor or not flagged at all.

## Phase 5 — Decide verdict

The verdict format is one of two strings:

- `## Design Verdict: APPROVED` — no Critical findings; Major findings minor enough to land later if any
- `## Design Verdict: NEEDS_CHANGES` — at least one Critical finding, OR multiple Major findings that warrant rework before merge

### When NEEDS_CHANGES is the right call

- Any Critical finding (a11y violation, broken user task)
- 3+ Major findings (death by a thousand papercuts)
- A Major finding that wouldn't be reasonable to defer

### When APPROVED is the right call

- No Critical findings
- ≤2 Major findings AND they're suitable as follow-up issues
- Minor findings only

For APPROVED with notes, include the findings in a `Follow-up:` line — they become tasks for later, not blockers.

## Phase 6 — Compose verdict

Strict format. The first line MUST be exactly `## Design Verdict: APPROVED` or `## Design Verdict: NEEDS_CHANGES`. The verdict body follows the format defined in `rules/verdict-format.md`:

```markdown
## Design Verdict: NEEDS_CHANGES

### Findings

- **[Critical]** Color contrast — submit button text on background fails 4.5:1
  - Location: src/components/SignupForm.tsx:44
  - Spec said: `text-on-brand` on `bg-brand-600` should pass AA (4.5:1)
  - Actual: token `text-on-brand` resolves to neutral-100 (#F5F5F5) on `bg-brand-600` (#3B82F6) → 3.8:1
  - Reference: spec section "Accessibility spec"; WCAG 2.2 SC 1.4.3
- **[Major]** Field gap — vertical spacing between fields is 12px; spec said 16px
  - Location: src/components/SignupForm.tsx:30 (.field-stack)
  - Spec said: `space-4` (16px)
  - Actual: `space-3` (12px)
  - Reference: spec section "Visual spec → Spacing"
- **[Minor]** Loading spinner icon size — 14px; spec said 16px
  - Location: src/components/SignupForm.tsx:62
  - Reference: spec section "Visual spec → Iconography"

### What's needed

Address the Critical (contrast) before merge. Major spacing should also be fixed.
Minor spinner can be a follow-up.

triage: fe
Reviewed-on: abc1234
```

### `triage:` field

The most important field for routing:

- `triage: fe` — findings are implementation issues; route to fe to fix
- `triage: design` — findings reveal the spec itself was incorrect / incomplete; design needs to revise the spec first
- `triage: be` — findings reveal a backend / data issue (rare in design review; happens when the data shape returned doesn't fit the design)
- `triage: none` — APPROVED with no follow-up

For NEEDS_CHANGES verdicts, `triage:` is required and must be a valid role. For APPROVED, `triage: none`.

### `Reviewed-on:` field

The PR's HEAD commit SHA at the time of review. If the PR is updated post-review, the original verdict is for the old SHA — pre-triage can detect this and request re-review.

## Phase 7 — Post verdict

```bash
bash actions/post-verdict.sh \
  --issue $ISSUE_N \
  --pr $PR_N \
  --verdict-file /tmp/verdict-$ISSUE_N.md
```

The action:
1. Validates the verdict format strictly (exit non-zero if wrong)
2. Posts as a comment on the PR
3. Routes the issue to `agent:arch`

`scripts/pre-triage.sh` then reads the verdict on its next pass:
- APPROVED + no QA fail → merge
- NEEDS_CHANGES → route to `triage:` role
- conflict with QA verdict → escalate to arch-judgment

## Phase 8 — Self-test

```markdown
# Self-test record — issue #220 (design visual-review)

## Acceptance criteria
- [x] AC #1: design review completed against spec
  - Verified: walked through visual / interaction / a11y layers
- [x] AC #2: verdict posted with strict format
  - Verified: post-verdict.sh accepted it (no format errors)
- [x] AC #3: triage field set correctly
  - Verified: triage: fe (findings are impl issues, not spec issues)

## Foundations consulted
- color.md (contrast verification)
- space-and-rhythm.md (gap check)
- iconography.md (icon size check)

## Verdict reference
PR comment: https://github.com/{repo}/pull/{N}#issuecomment-{ID}
Verdict: NEEDS_CHANGES (1 Critical, 1 Major, 1 Minor)

## Ready for review: yes
```

## Anti-patterns

- **Verdict that doesn't follow the strict format** — post-verdict.sh refuses; not optional
- **Vague findings** — "looks off", "feels wrong", "could be better" — useless to fe. Always: location + what + reference
- **Severity inflation** — calling everything Critical. Loses meaning quickly. Save Critical for actual blocks.
- **Severity deflation** — treating contrast failures as Minor. Accessibility violations are always Critical.
- **APPROVED on a PR with Critical findings** — don't. Either find a way to defer (rare) or NEEDS_CHANGES.
- **Reviewing without reading the spec** — your verdict is "this looks fine" without comparing to anything. Re-read the spec block first.
- **Reviewing only the rendered preview, not the diff** — preview shows visual; diff shows token usage. Both matter.
- **Adding spec changes mid-review** — if the spec was wrong, set `triage: design` and route back; don't change the spec inline.

## When to use Mode C feedback instead

If reviewing reveals the spec itself is wrong (not just impl), don't write a NEEDS_CHANGES verdict. Use Mode C:

- The spec asks for something not implementable in the codebase's design system
- The spec's accessibility requirements conflict with reality
- The spec contradicts a foundation in a way the agent now realises is wrong

In these cases: `workflow/feedback.md`. The verdict for the PR can be NEEDS_CHANGES with `triage: design`, and a separate Mode C comment can flag the spec issue to arch.
