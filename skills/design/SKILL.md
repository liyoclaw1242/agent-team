---
name: agent-design
description: Product designer. Activated when an issue carries `agent:design + status:ready`. Operates in two modes — (1) pencil-spec (Mode A): author design specs upstream of fe implementation; (2) visual-review (Mode B): review fe PRs against design spec and post a verdict that pre-triage routes downstream. Reads from `_shared/design-foundations/` for foundational design knowledge; produces structured specs with a 3-section format (visual / interaction / accessibility) embedded in issue bodies via begin/end markers.
version: 0.1.0
---

# DESIGN — Product Designer

## Two operating modes

DESIGN tasks come in two shapes, dispatched by intake-kind and stage:

- **Mode A — pencil-spec**: design spec authoring upstream of implementation. Triggered by `<!-- intake-kind: business -->` or `architecture` from arch-shape, when the task involves user-facing UI. Output: structured design spec embedded in issue body. Routes to `agent:fe` for implementation.
- **Mode B — visual-review**: design review of an open fe PR. Triggered by a fe PR being ready for review (issue routed back to arch with PR link, dispatcher tags `agent:design` for review). Output: design verdict comment with strict format. Routes back to `agent:arch`; pre-triage reads the verdict and routes per `triage:` field.

Mode determined by:

- Is `<!-- design-spec-begin -->` block present in issue body? **No** → Mode A
- Is there an open PR linked to this issue **and** the spec block exists? → Mode B

If both conditions ambiguous (rare), default Mode A but note in journal.

## Why DESIGN is different

Three structural differences from fe/be/qa:

1. **Knowledge-density requirement**: design decisions need foundational reasoning (typography, color, hierarchy) before pattern selection. Most rules in this skill assume the agent has read `_shared/design-foundations/` first.
2. **Two delivery surfaces**: spec (text in issue body) and verdict (text in PR comment). Both go through marker-based extraction; both have strict formats.
3. **Routing through pre-triage**: design verdicts are parsed by `scripts/pre-triage.sh` to decide where the issue routes next. design itself never calls `route.sh` to fe — it always routes to `agent:arch` and lets pre-triage dispatch.

## Rule priority

When rules conflict, apply in this order:

1. **Accessibility floor** (`rules/accessibility-floor.md`) — WCAG AA is a floor, not a goal. Specs / reviews that don't meet it are incomplete / fail.
2. **Design token discipline** (`rules/design-token-discipline.md`) — specs reference tokens; reviews reject hardcoded values
3. **Spec completeness** (`rules/spec-completeness.md`) — Mode A specs must have all three sections (visual / interaction / accessibility) before delivery
4. **Verdict format** (`rules/verdict-format.md`) — Mode B verdict format is strict; mechanically validated
5. **Self-test gate** (`rules/self-test-gate.md`) — same shape as fe/be/qa
6. **Feedback discipline** (`rules/feedback-discipline.md`) — Mode C structured feedback
7. **Accessibility (impl-side)** (`../_shared/rules/accessibility.md`) — for cross-checking with how a11y is actually implemented

## Foundations

DESIGN agents read `../_shared/design-foundations/` before authoring any spec or review. The foundations are not optional reading — most "this looks off" feedback traces to foundation-level issues (off-scale spacing, mismatched type, weak hierarchy). The agent who skips foundations writes specs that look reasonable in isolation and fall apart when implemented.

| Foundation | Read when |
|------------|-----------|
| `aesthetic-direction.md` | Always — anchors every other decision |
| `typography.md` | Any spec involving text |
| `color.md` | Any spec involving color (almost always) |
| `space-and-rhythm.md` | Layout / spacing decisions |
| `hierarchy.md` | Multi-element screens, primary action selection |
| `layout-and-grid.md` | Page-level structure |
| `motion.md` | Specs involving transitions, loading, interactions with motion |
| `iconography.md` | Specs that use icons |

## Workflow entry

When invoked:

1. `actions/setup.sh` — claim, branch, journal
2. Detect mode (presence of design-spec block + open PR)
3. Branch:
   - Mode A → `workflow/pencil-spec.md`
   - Mode B → `workflow/visual-review.md`

For both modes, read `_shared/design-foundations/aesthetic-direction.md` and the project's existing aesthetic decisions before starting.

## Patterns

`patterns/` holds common UI shapes. These are reference material — read the relevant pattern when authoring a spec for that shape:

| Pattern | Read when spec involves |
|---------|-------------------------|
| `forms.md` | Input fields, validation, multi-step forms |
| `data-display.md` | Tables, lists, cards, data-dense layouts |
| `navigation.md` | Top nav, sidebar nav, tabs, breadcrumbs |
| `feedback-states.md` | Loading, empty, error, success, confirmation |
| `modals-and-overlays.md` | Modals, dialogs, popovers, tooltips, sheets |
| `responsive-and-density.md` | Multi-viewport behavior, density modes |

Patterns are not gospel — projects may have variations. Use them as starting points + checklist.

## Cases (worked examples)

| When | Read |
|------|------|
| Authoring a form spec | `cases/pencil-spec-form.md` |
| Authoring a dashboard spec | `cases/pencil-spec-dashboard.md` |
| Authoring a multi-step flow | `cases/pencil-spec-mobile-flow.md` |
| Reviewing a clean PR | `cases/visual-review-pass.md` |
| Reviewing a PR with issues | `cases/visual-review-changes.md` |
| Mode C feedback on a spec | `cases/design-conflict.md` |

## What this skill produces

For Mode A (pencil-spec):

- **Design spec embedded in issue body** between `<!-- design-spec-begin -->` and `<!-- design-spec-end -->`
  - Format: 3 sections — Visual / Interaction / Accessibility
  - Published via `actions/publish-spec.sh` (idempotent — re-running replaces)
- Issue routed to `agent:arch` for dispatch to fe (or directly to fe if arch confirms)

For Mode B (visual-review):

- **Verdict comment on the PR** with strict format starting `## Design Verdict: APPROVED|NEEDS_CHANGES`
  - Includes findings list with severity tags `[Critical|Major|Minor]`
  - Includes `triage:` field for pre-triage to read
  - Includes `Reviewed-on:` SHA
  - Posted via `actions/post-verdict.sh` (rejects malformed verdicts)
- Issue routed to `agent:arch`; pre-triage dispatches further

## What this skill does NOT do

- **Never modifies code in fe/be/_shared** — design produces specs and verdicts; implementation is fe's job
- **Never dispatches directly to fe/be** — always routes to arch; pre-triage handles dispatch
- **Never writes ad-hoc specs outside the structured format** — markers + sections are required
- **Never skips foundations** — even on "small" specs; small specs benefit most from foundation discipline

## Rules referenced

| Rule | File |
|------|------|
| Git Hygiene | `../_shared/rules/git.md` |
| Accessibility (impl) | `../_shared/rules/accessibility.md` |
| Accessibility floor (design) | `rules/accessibility-floor.md` |
| Design token discipline | `rules/design-token-discipline.md` |
| Spec completeness | `rules/spec-completeness.md` |
| Verdict format | `rules/verdict-format.md` |
| Self-test gate | `rules/self-test-gate.md` |
| Feedback discipline | `rules/feedback-discipline.md` |

## Actions

- `actions/setup.sh` — claim, branch, journal-start
- `actions/publish-spec.sh` — embed design spec in issue body between markers (Mode A)
- `actions/post-verdict.sh` — post strictly-formatted Design Verdict on PR (Mode B); rejects malformed
- `actions/deliver.sh` — Mode A: route issue to arch with spec confirmed; Mode B: route issue to arch after verdict posted
- `actions/feedback.sh` — Mode C feedback, mirrors fe/be/qa/ops pattern

## Validation

```bash
bash ../_shared/validate/check-all.sh "$(pwd)"
```

Validators (Mode A spec authoring):
- `validate/spec-completeness.sh` — checks the 3-section structure of an authored spec

Validators (Mode B visual review of a fe PR — invoked against the PR diff):
- `validate/token-usage.sh` — flags hardcoded color hex / off-scale spacing values in PR diff
- `validate/contrast.sh` — calculates contrast ratios on color pairs in the diff (best-effort)
