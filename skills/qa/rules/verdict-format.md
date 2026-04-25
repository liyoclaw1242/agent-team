# Rule — Verdict Format

The verdict comment is a **system contract**. `pre-triage.sh` parses it deterministically; `arch-judgment` reads it during conflict resolution; `actions/post-verdict.sh` enforces format before posting. The format is non-negotiable.

## Required structure

```markdown
## QA Verdict: {PASS|FAIL}

(per-AC list with verdicts and evidence)

triage: {role|none}

Verified-on: {commit SHA}
```

## Required fields

### First line: `## QA Verdict: PASS` or `## QA Verdict: FAIL`

Exactly this format. Not:

❌ `## QA verdict: pass` (lowercase)
❌ `## QA Verdict — PASS` (em-dash)
❌ `## QA Verdict: PASSED` (suffix)
❌ `## QA verdict for #142: PASS` (annotated)
❌ `## QA Verdict: PASS WITH NOTES` (qualifier)

The regex pre-triage uses is approximately `^## QA Verdict:\s+(PASS|FAIL)\s*$`. Any deviation makes the verdict invisible to automation.

### AC list

Every AC item from the parent issue gets a line with verdict character and evidence:

```markdown
- AC #N: {AC text} — {✓|✗}
  Evidence: {test name|manual step|log|etc}
```

Even on PASS, every AC needs evidence. "Evidence: passes" is too vague; cite specifics.

### `triage:` line

Required even on PASS:

- PASS: `triage: none`
- FAIL: `triage: {role}` where role is one of `fe`, `be`, `ops`, `design`

The `triage:` line is what `pre-triage.sh` reads to route the failed issue to the right role for fixing. Picking the wrong role = the issue bounces.

### `Verified-on:` line

The SHA of the commit you verified. Format: `Verified-on: {7+ hex chars}`. If the PR is force-pushed after your verdict, future readers see a mismatch and can request re-verification.

## Optional fields

### `Notes:` block

Below the required fields, free-form. Useful for:

- Recommendations that don't block the verdict ("consider adding X test in follow-up")
- Caveats ("manual verification was on staging, not prod")
- Cross-references to other issues

```markdown
Notes:
- The 5xx error path returned 500 instead of 503 in one of my manual tests; could not reproduce. Filing follow-up #200 to investigate.
- Performance is borderline: 180ms response time in staging vs the 200ms target. Acceptable for now but worth watching.
```

Notes don't change the verdict. PASS stays PASS even with notes.

### `## QA Verdict: PASS (with reservations)` — does NOT exist

There's no in-between state. Either the AC are met (PASS, possibly with Notes) or they aren't (FAIL with specific findings).

If you genuinely can't decide, that's not a verdict — it's Mode C feedback (`workflow/feedback.md`'s `unverifiable-pr` category). Don't invent intermediate states.

## Format validation

`actions/post-verdict.sh` runs these checks before posting:

1. First non-blank line matches `^## QA Verdict: (PASS|FAIL)$` exactly
2. At least one `triage:` line present
3. `triage:` value is `none` (PASS) or one of {fe, be, ops, design} (FAIL)
4. `Verified-on:` line present with a hex SHA (≥7 chars)
5. PASS + `triage: none` is consistent; FAIL + `triage: none` is rejected (you must name a triage role)

If any check fails, posting is refused.

## Why such strict format

Two reasons:

1. **Automation depends on it**. `pre-triage.sh` makes routing decisions from this comment. Sloppy format = bad routing.

2. **Auditability**. Months later, someone reads "why did this PR fail QA round 1?" — they look at the verdict comment. Strict structure means the answer is findable.

The format isn't bureaucratic — it's the price of having a deterministic post-impl pipeline.

## Common mistakes

### Mistake: missing `triage:` on FAIL

```
## QA Verdict: FAIL

- AC #1: ...

(no triage line)
```

Posting refused. FAIL must specify which role gets the bounce.

### Mistake: hedging in PASS line

```
## QA Verdict: PASS (with minor concerns)
```

Posting refused. Move concerns to a `Notes:` block; verdict line is a clean PASS.

### Mistake: triage role outside the set

```
triage: arch
```

Posting refused. `triage:` is for implementer roles (fe/be/ops/design). If you genuinely think the failure is at arch level (decomposition wrong), that's Mode C feedback territory, not triage.

### Mistake: inflated AC list

```
- AC #1: ...
- AC #2: ...
- AC #3: also verified that error messages are clear (this AC wasn't in parent)
```

Don't invent AC. The list mirrors the parent. If you found an issue not covered by AC, add it as a note:

```
Notes:
- Out of scope but observed: error messages on 5xx are generic; consider follow-up improvement
```

## Verdict on a PR that fixes multiple issues

If a PR addresses multiple issues (PR has `Refs: #142, #143`), each issue gets its own QA verdict comment. Don't bundle.

## Verdict on a partial fix

A PR that addresses some AC but explicitly defers others is `FAIL` until all are addressed. The `triage:` field points back to the implementer to finish.

If the parent issue itself was decomposed wrong (only some AC are achievable in this PR; others belong to a different task), that's an arch-shape level concern. Mode C feedback rather than FAIL.

## Self-test record records the verdict

In post-impl mode, the QA self-test references the verdict:

```markdown
## Verdict
PASS — see verdict comment on PR #501

## Verdict comment URL
https://github.com/owner/repo/pull/501#issuecomment-XYZ
```

This makes QA's own audit trail self-contained.
