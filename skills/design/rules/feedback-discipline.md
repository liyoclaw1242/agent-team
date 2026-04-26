# Rule — Feedback Discipline

Same shape as other roles. Design-specific patterns and traps.

## When to write feedback (Mode C)

- **Foundation conflict**: spec asks for off-scale values without justification
- **Pattern conflict**: spec describes a UI shape that doesn't fit existing patterns; introducing one is bigger than this task
- **A11y impossibility**: spec's interaction model can't be made accessible
- **Domain conflict**: spec assumes data shape that doesn't match BE
- **Cross-task coupling**: spec only makes sense alongside a non-existent task
- **Wrong-outcome**: spec optimises for the wrong thing
- **Code-conflict / missing-AC / over-prescription**: same as fe/be

Don't write feedback for:

- Personal aesthetic preference ("I'd rather it be blue")
- Workload concerns ("this is a lot of work")
- Pure scope expansion thoughts ("we should also do X")

## Strong vs weak feedback

Strong feedback:
- Cites specific sections of foundations or patterns
- Computes the actual impact (contrast ratio, off-scale value)
- Lists concrete options
- States preference with rationale

Weak feedback:
- "This doesn't feel right"
- "I don't think this works"
- "Could be improved"

The strong vs weak distinction:

```
WEAK:
> The spec's spacing seems off.

STRONG:
> The spec specifies 14px field gap. Type scale defines 12px and 16px;
> 14px is off-scale. Forms in this codebase use 16px (e.g., signup,
> billing flows). Recommend 16px for consistency. If 14px was intentional
> for tighter density, that's a Mode A discussion: should we add a
> "compact" density mode token? But for this single spec, 16px keeps
> us aligned.
```

## Tone

Same as other roles: neutral, professional, concrete. Feedback isn't combat.

## Design-specific traps

### Trap: feedback is design preference

```
WEAK:
> The spec uses purple for the brand color; I'd suggest green instead
> because it feels fresher.

(Not feedback. Personal preference.)
```

```
STRONG:
> The spec uses purple for brand color. The product's existing brand
> tokens at /design-system/tokens.json define `--brand-500: #00C896`
> (green). Spec's purple introduces a second brand color; this is a
> system-level decision (cross-product impact). Either:
> 1. Use existing brand-500 (consistency)
> 2. Discuss multi-brand-color approach at arch-shape level
```

### Trap: feedback that's actually scope expansion

Spec is for "improve form spacing"; you find that the entire form pattern is inconsistent with the design system. You want to fix the whole pattern.

Don't bundle:

```
DO:
> Concerns about this spec's spacing: [details]
> 
> Separately (not blocking this spec): the broader form pattern has
> inconsistencies that may warrant a pattern-level review. I can file
> that as a follow-up if relevant.
```

The big problem becomes a separate issue, not feedback bundled into this one.

### Trap: feedback as a way to shift work to fe

```
WEAK:
> The spec is ambiguous about state management; fe should figure out
> how this state machine works.

(Not feedback. Asking fe to design.)
```

```
STRONG:
> The spec describes "loading", "error", and "success" states but doesn't
> specify the transitions between them. Specifically:
> - Does success persist or auto-dismiss after N seconds?
> - On error, does the form remain editable or freeze?
> - On retry, does loading replace error or layer on top?
>
> Suggested defaults: success auto-dismisses in 3s; form remains editable
> on error; retry replaces error.
>
> If these aren't right for this product, please clarify before fe starts.
```

The strong version is feedback to design itself, requesting completion.

## Round limit

Same as other roles: 2 rounds max; round 3+ escalates to arch-judgment automatically. If your feedback is rejected and you'd write the same thing again, escalate instead.

## After feedback returns

Same: read new state, restart from `workflow/pencil-spec.md` Phase 1 (or `visual-review.md` if Mode B).

## Anti-patterns

- **Feedback as preference**: design role's job is to apply foundations, not impose taste
- **Feedback that quotes foundations without specificity**: "this violates typography.md" — which rule? what's the impact?
- **Feedback that re-litigates settled decisions**: if the project has chosen X, don't keep advocating Y
- **Combative tone**: "the spec author should have known X"
- **Bundled feedback**: one issue worth of unrelated concerns

## Quick checklist

Before posting Mode C feedback:

- [ ] One specific concern, not a list of grievances
- [ ] Cites foundation / pattern / a11y rule with location
- [ ] Computes impact where applicable (ratio, value, count)
- [ ] Provides options (not just complaints)
- [ ] States preference with rationale
- [ ] Uses the exact `## Technical Feedback from design` header
- [ ] Routes via `feedback.sh` (not direct comment + manual route)
