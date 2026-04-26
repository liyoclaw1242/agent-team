# Rule — Design Token Discipline

Specs reference design tokens. Reviews reject hardcoded values. This rule keeps the system coherent across screens and across time.

## What "token" means here

A design token is a named reference for a foundational value:

- `--space-4` → 16px (a value on the spacing scale)
- `--text-secondary` → resolves to a neutral color depending on theme
- `--brand-500` → the primary brand color
- `--text-base` → 16px (a value on the type scale)
- `--radius-md` → 8px (a corner radius value)
- `--duration-fast` → 200ms (a motion duration)

Tokens are defined once (typically in CSS variables, Tailwind config, or a tokens JSON file). Components reference tokens. Specs reference tokens.

## The rule for spec authoring

When authoring a spec:

```markdown
WRONG:
- Field gap: 16px
- Submit button background: #3B82F6
- Hover transition: 200ms ease-out
- Border radius: 8px

RIGHT:
- Field gap: `space-4`
- Submit button background: `bg-brand-500`
- Hover transition: `duration-fast ease-out`
- Border radius: `radius-md`
```

The spec mentions tokens, not raw values. This:

- Keeps the spec aligned with the design system
- Lets the implementation use tokens directly (the spec becomes pseudo-code)
- Survives token re-tuning (if `--space-4` becomes 18px, the spec doesn't need rewriting)

## When a token doesn't exist

Sometimes the spec needs a value that's not in the token system:

- A specific brand asset color (logo)
- An off-scale value because of an external constraint (matches a partner's design)
- A novel motion timing not on the standard scale

Two correct moves:

1. **Propose adding a token** — note in the spec that this needs a new token; reference it speculatively in the spec; add it to the design tokens definition

2. **Use raw value with annotation** — include the raw value AND mark explicitly why the token doesn't exist:

```markdown
- Logo height: 32px (note: brand asset; not a generic size token)
- Specific embed dimension: 720px wide × 405px tall (16:9 aspect for video)
```

The annotation is the key. Without it, raw values look like the agent forgot to use tokens.

**Wrong move**: silently insert a raw value because it's faster. The spec becomes corrupted.

## The rule for visual review

When reviewing a PR:

- Hardcoded color hex (e.g., `color: #3B82F6`) → **Major** finding ("use token instead")
- Off-scale spacing values (e.g., `padding: 13px`) → **Major** finding
- Font sizes off the type scale → **Major** finding
- Duration values not from the motion tokens → **Minor** finding

Exception: in test files, mock data, and ad-hoc utility scripts, raw values are fine.

`validate/token-usage.sh` (in `validate/`) automates much of this — it scans the diff for likely hardcoded values and flags them.

## What counts as a token reference

Acceptable forms:

- CSS custom property: `var(--space-4)`
- Tailwind class: `gap-4`, `bg-brand-500`, `text-base`
- Theme function call: `theme('space.4')`
- Imported JS object: `tokens.space[4]`
- Sass / Less variable: `$space-4`

Whatever the system uses. The point is: **named, single-source-of-truth, theme-aware**.

## What does NOT count

- Inline style with hardcoded value: `style={{ padding: '16px' }}` — even if 16px happens to be on the scale, the *reference* is the wrong shape
- "Magic number" comment: `// 16px to match design system` — a comment doesn't fix the value being hardcoded
- Value computed from another hardcoded: `padding: 16px * 0.75` — both values are off-system

## When the codebase doesn't have a token system yet

This is unusual but real. New projects, prototypes, or codebases that grew without intentional design tokens.

If the codebase doesn't have tokens:

- Don't pretend it does. Specs use values + a note that "tokens don't exist yet; consolidating into a design token system is a pending architecture task"
- Reviews don't fail on hardcoded values (the codebase pattern is hardcoded)
- File a separate task for "introduce design token system"

This is rare. Most modern projects have at least Tailwind, which provides a token-like surface for free.

## Compound tokens

Some products have compound tokens — pre-built combinations:

```css
--card-default: {
  background: var(--bg-secondary);
  border: 1px solid var(--border-default);
  border-radius: var(--radius-lg);
  padding: var(--space-6);
}
```

When these exist, prefer them over re-specifying the constituent values. Specs reference the compound:

```markdown
- Container: card-default
- Inner content gap: space-4
```

If the project uses compound tokens, the spec should follow that level of abstraction.

## Anti-patterns

- **"It's just one hex"** — that's one hex per screen, hundreds of screens later
- **Token references that aren't tokens** — `var(--my-blue)` defined inline in a component file isn't a token; it's a local variable
- **Specs that are too abstract** — spec only says "use the form pattern"; doesn't say which spacing or which states. Tokens at the spec level let fe implement without re-deciding.
- **Conflicting tokens** — `--bg-card` and `--bg-secondary` are both defined and slightly different; specs reference both at random. Pick one or document when each applies.
- **Tokens without a defined scale** — `--space-tiny`, `--space-small`, `--space-medium`, `--space-big` — all relative; unclear how they relate. The scale provides the relationships.

## How this rule interacts with `aesthetic-direction.md`

Aesthetic direction picks a feel; tokens are how the feel becomes systematic. The aesthetic might say "generous whitespace, restrained color"; the tokens encode what "generous" and "restrained" mean numerically. Specs reference the tokens; reviews verify implementation referenced the tokens.

This is the chain: aesthetic direction → token values → specs reference tokens → impl uses tokens → reviews verify.

## Quick checklist

For any spec:

- [ ] All values are token references, or raw values are explicitly justified
- [ ] No hex codes in the spec (unless brand-asset annotation)
- [ ] No magic spacings or sizes (must map to scale)
- [ ] Compound tokens used where they exist

For any review:

- [ ] Diff has no obviously hardcoded values that should be tokens
- [ ] `validate/token-usage.sh` results reviewed
- [ ] Edge cases (test files, scripts) excluded from findings
