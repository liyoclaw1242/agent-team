# Rule — Verdict Format

The Mode B verdict comment follows a strict format that `scripts/pre-triage.sh` parses to make routing decisions automatically. Format violations break the routing chain.

## The strict shape

```
## Design Verdict: APPROVED|NEEDS_CHANGES

[optional summary paragraph]

### Findings

- **[Critical|Major|Minor]** {short description}
  - Location: {file:line or rendered preview reference}
  - Spec said: {what spec specified}
  - Actual: {what implementation does}
  - Reference: {spec section / foundation / WCAG SC}

[... more findings ...]

### What's needed

[short summary of what addressing the findings looks like]

triage: {fe|be|design|none}
Reviewed-on: {SHA}
```

## What's mechanically checked

`actions/post-verdict.sh` rejects malformed verdicts. It checks:

1. **First non-empty line** must be exactly `## Design Verdict: APPROVED` or `## Design Verdict: NEEDS_CHANGES` — no other variations
2. **`triage:` line** must be present at any indentation, with a value in `{fe, be, design, ops, none}`
3. **`Reviewed-on:` line** must be present with a value matching `[a-f0-9]{7,40}` (commit SHA)
4. **Internal consistency**:
   - `APPROVED` requires `triage: none`
   - `NEEDS_CHANGES` requires `triage:` to be a role (not `none`)

If any of these fail, the verdict is rejected and design must fix and resubmit. This is the same defensive pattern as `qa/actions/post-verdict.sh`.

## The verdict line — exactly

The first non-empty line:

```
## Design Verdict: APPROVED
```

or

```
## Design Verdict: NEEDS_CHANGES
```

NOT:

- `## design verdict: approved` (case-sensitive)
- `# Design Verdict: APPROVED` (must be `##`)
- `## Design Verdict: PASS` (must use APPROVED/NEEDS_CHANGES specifically)
- `## Design Verdict — APPROVED` (must use colon)
- Anything before the verdict line (no preamble)

The strictness exists because pre-triage greps for these exact strings. Variation breaks routing.

## The findings section

`### Findings` is an `<h3>`. Each finding is a list item with:

- **First-level**: the severity tag in `[brackets]` made bold, then a short description
- **Sub-items** indented: Location, Spec said, Actual, Reference

The finding format isn't mechanically enforced — pre-triage doesn't parse findings — but the format helps fe agents read findings consistently.

### Severity tags

Three severity levels, with strict definitions:

- **`[Critical]`** — accessibility floor violation OR significant divergence from spec that breaks the user task. Must be fixed before merge.
- **`[Major]`** — visual / interaction divergence from spec that affects perceived quality. Should usually be fixed; can occasionally defer.
- **`[Minor]`** — refinement; not user-impacting. Can be a follow-up.

Don't invent severities (`[Trivial]`, `[Blocker]`, `[Note]`). Pre-triage / fe expect these three.

### Severity calibration

When in doubt:

- Accessibility violations → always Critical
- Spec divergences that change the user's experience meaningfully → Major (sometimes Critical)
- Stylistic preferences → not flagged (or Minor if part of an obvious pattern violation)

Common over-classification: marking everything Major. If 80% of your findings are Major, recalibrate — they're probably Minor.

Common under-classification: marking accessibility issues as Major because "fe will fix it later". A11y is Critical — flag it as such or don't include it.

## The triage field

```
triage: fe
```

Valid values:

- `fe` — implementation issue; fe to fix
- `be` — backend / data shape issue (rare in design review)
- `design` — spec itself is wrong; design needs to revise
- `ops` — deployment / config issue (rare in design review)
- `none` — APPROVED with no follow-up

The triage field is what pre-triage uses to route the issue. Pick deliberately:

- If findings are about implementation not matching spec → `fe`
- If findings reveal the spec was incomplete or wrong → `design`
- If the implementation reveals the data doesn't fit the design → `be`

Mixed findings (some impl, some spec): pick the dominant one. If genuinely 50/50, escalate via Mode C and route to `design` (let arch-feedback / arch-judgment handle).

## The Reviewed-on field

```
Reviewed-on: abc1234
```

The PR's HEAD SHA at the time of review. Get it via:

```bash
gh pr view $PR_N --repo $REPO --json headRefOid --jq '.headRefOid' | cut -c1-7
```

This matters because:

- If the PR is updated after review, the verdict is stale
- pre-triage can detect "verdict references SHA X but PR is now at SHA Y" and request re-review
- Audit trail: the verdict is for a specific snapshot of the code

## When updating an existing verdict

If you posted a verdict and need to update it (re-review after fixes, mistake in original):

- Don't post a "correction" comment alongside the original (pre-triage will find the wrong one)
- Post a new verdict comment; make it clear it supersedes the previous via a leading note

```markdown
**Re-review after fix push** — supersedes earlier verdict.

## Design Verdict: APPROVED
...
triage: none
Reviewed-on: def5678
```

The "supersedes" note is for human readers; pre-triage just takes the most recent verdict.

## Examples

### Clean APPROVED

```markdown
## Design Verdict: APPROVED

Spec adherence is consistent; foundations applied correctly; accessibility verified.

### Findings

None.

### What's needed

Nothing.

triage: none
Reviewed-on: 7c3a91b
```

### APPROVED with follow-ups

```markdown
## Design Verdict: APPROVED

Implementation meets spec at the levels that matter for shipping. Two minor refinements
worth filing as follow-up.

### Findings

- **[Minor]** Loading spinner color is text-secondary; spec implied text-tertiary
  - Location: src/components/SignupForm.tsx:62
  - Reference: spec section "Visual spec → States → loading"
- **[Minor]** Field label spacing is 6px between label and input; spec said 8px
  - Location: src/components/SignupForm.tsx:30
  - Reference: spec section "Visual spec → Spacing"

### What's needed

Both above can be addressed in a follow-up PR; not blocking this merge.

triage: none
Reviewed-on: 7c3a91b
```

### NEEDS_CHANGES with mixed severity

```markdown
## Design Verdict: NEEDS_CHANGES

One critical accessibility issue plus two visual deviations.

### Findings

- **[Critical]** Submit button contrast — text-on-brand on bg-brand-600 = 3.8:1 (FAIL AA)
  - Location: src/components/SignupForm.tsx:44 (button styling)
  - Spec said: "text-on-brand on bg-brand-600 should pass AA (4.5:1)"
  - Actual: token resolution gives 3.8:1
  - Reference: spec "Accessibility spec"; WCAG 2.2 SC 1.4.3
- **[Major]** Field gap mismatch — 12px instead of 16px
  - Location: src/components/SignupForm.tsx:30 (.field-stack gap)
  - Spec said: `space-4` (16px)
  - Actual: `space-3` (12px)
  - Reference: spec "Visual spec → Spacing"
- **[Minor]** Help text color is text-tertiary; spec said text-secondary
  - Location: src/components/SignupForm.tsx:28
  - Reference: spec "Visual spec → Type"

### What's needed

Critical contrast issue must be addressed (lighten the bg or darken the text token,
likely the latter). Major spacing should be aligned. Minor color can be a follow-up.

triage: fe
Reviewed-on: abc1234
```

### NEEDS_CHANGES routing to design (spec issue)

```markdown
## Design Verdict: NEEDS_CHANGES

Implementation matches spec, but the spec itself has an issue surfaced by the
real implementation.

### Findings

- **[Critical]** Color-only state encoding for active/paused/ended status
  - Location: src/components/StatusBadge.tsx (entire component)
  - Spec said: "Color-coded status badges"
  - Actual: implementation correctly uses spec's color-only encoding; this fails
    WCAG 1.4.1 (Use of Color)
  - Reference: WCAG 2.2 SC 1.4.1

### What's needed

The spec needs revision to add a non-color signal (icon or text). This isn't a fe
issue — fe correctly implemented what was specced.

triage: design
Reviewed-on: 5e9b22a
```

This kind of routing (back to design instead of forward to fe) is what makes the system robust to spec mistakes.

## Anti-patterns

- **Verdict line variation** — `## Design Verdict - PASS` instead of the exact format. post-verdict.sh refuses.
- **Findings without locations** — "the contrast is wrong somewhere" — fe can't act on this. Always location + spec said + actual.
- **APPROVED with Critical findings** — contradicts itself. NEEDS_CHANGES if Critical exists.
- **Using `triage:` as a comment field** — `triage: fe (and probably be too)` — only one role; pick.
- **Reviewing without `Reviewed-on:`** — verdict can't be tied to a specific SHA; gets stale invisibly.
- **Multiple verdict comments without supersedes note** — pre-triage may pick the wrong one; humans confused.
- **Hidden/inline verdicts** — verdict in a PR review comment instead of a top-level PR comment. pre-triage looks at top-level comments.
