# Rule — Self-Test Gate

The deliver gate refuses to ship when self-test is incomplete. Same shape as fe/be/qa/ops, with mode-specific required sections.

## What the gate checks

`actions/deliver.sh` runs:

1. File exists: `/tmp/self-test-issue-{N}.md`
2. File contains `## Acceptance criteria` section
3. Every line starting with `- [` in that section is `- [x]`
4. File contains `## Ready for review: yes` line
5. **Mode A specific**: file contains `## Spec sections present` with all three (Visual / Interaction / Accessibility) checked
6. **Mode A specific**: file contains `## Foundations consulted` listing which foundations were read
7. **Mode B specific**: file contains `## Verdict reference` with link to PR comment
8. **Mode B specific**: file contains `## Foundations consulted`

The mode-specific checks ensure the agent thought through the appropriate dimensions.

## Mode A self-test format

```markdown
# Self-test record — issue #220 (design pencil-spec)

## Acceptance criteria
- [x] AC #1: design spec authored covering form input, validation, submit button
  - Verified: spec embedded via publish-spec.sh
- [x] AC #2: spec includes mobile + desktop variants
  - Verified: Visual spec section enumerates breakpoints
- [x] AC #3: spec aligns with existing form pattern (login screen)
  - Verified: cross-checked with /apps/auth/login

## Spec sections present
- [x] Visual spec
- [x] Interaction spec
- [x] Accessibility spec

## Foundations consulted
- aesthetic-direction.md
- typography.md (label / input / helper text sizes)
- color.md (default / focus / error states)
- space-and-rhythm.md (field spacing)
- patterns/forms.md

## Validators
- spec-completeness: pass

## Ready for review: yes
```

## Mode B self-test format

```markdown
# Self-test record — issue #220 (design visual-review)

## Acceptance criteria
- [x] AC #1: design review completed against spec
  - Verified: walked through visual / interaction / a11y layers
- [x] AC #2: verdict posted with strict format
  - Verified: post-verdict.sh accepted
- [x] AC #3: triage field set correctly
  - Verified: triage: fe (impl issues, not spec issues)

## Foundations consulted
- color.md (contrast verification)
- space-and-rhythm.md (gap check)
- iconography.md (icon size check)

## Verdict reference
PR comment: https://github.com/{repo}/pull/{PR_N}#issuecomment-{ID}
Verdict: NEEDS_CHANGES (1 Critical, 1 Major, 1 Minor)
SHA reviewed: abc1234

## Validators
- token-usage: 2 findings (in verdict)
- contrast: 1 finding (in verdict; Critical)

## Ready for review: yes
```

## What the gate does NOT check

- The quality of the spec (Mode A) or verdict (Mode B) — that's review's job
- Whether the agent actually read the listed foundations — claim is sufficient for the gate
- Whether the verdict format itself is valid — `post-verdict.sh` checks that earlier in the workflow

The gate is a commitment ceremony. Lying on the self-test will be caught downstream (PR review, pre-triage, fe response).

## Why a separate gate from fe/be

The mode-specific checks differ. Fe / be have a single mode (implement) with one shape of self-test. Design has two modes (spec authoring vs review) with different concerns. Separate sections in the self-test reflect that.

The fe/be `Ready for review: yes` line is shared (every role uses it).

## Self-test for Mode C feedback

When ending in Mode C feedback rather than spec or verdict:

```markdown
# Self-test record — issue #220 (design feedback)

## Acceptance criteria
- [x] AC #1: investigated the spec-side concern
  - Verified: read foundations + existing patterns
- [x] AC #2: posted Mode C feedback with format
  - Verified: comment header is "## Technical Feedback from design"
- [x] AC #3: routed to arch
  - Verified: feedback.sh succeeded

## Foundations consulted
- typography.md
- space-and-rhythm.md

## Feedback summary
Concern: foundation-conflict (off-scale type sizes)
Routed: agent:arch (for arch-feedback)

## Ready for review: yes
```

`actions/feedback.sh` doesn't currently run a deliver gate (it just posts + routes), but having a self-test record is good practice for audit.

## Anti-patterns

- **Same as fe/be/qa/ops**: boilerplate self-tests, copy-pasted records, AC marked complete without verification
- **Design-specific**: claiming foundations consulted but not actually reading them. Trust eroded if review reveals foundation-level mistakes.
- **Mode confusion**: Mode A self-test on a Mode B task. The required sections differ; deliver gate refuses.
- **No Verdict reference link in Mode B**: the comment URL is needed for downstream agents to find the verdict.
