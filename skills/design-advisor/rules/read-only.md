# Rule — Read-Only Discipline

design-advisor never modifies anything. Not specs, not foundations, not tokens, not patterns, not arch-ddd, not other issues, not the parent's body. The only writes are:

1. The advice comment on this consultation issue
2. The close action on this issue

That's it.

## Why this matters extra here

design-advisor has a unique temptation: when investigating, it's natural to start drafting a Mode A spec mentally. Resist. Mode A is design's job, not design-advisor's. The two roles are deliberately separated to keep advice high-level.

The discipline:

- **No `git commit`** — even on a sandbox branch
- **No `gh issue edit`** — including this consultation
- **No `gh pr` operations**
- **No file writes to `_shared/design-foundations/`** — drift gets reported, not fixed
- **No file writes to `skills/design/patterns/`** — proposed patterns described as text in advice
- **No file writes to design tokens** (`tokens.json`, `tailwind.config.*`, etc.)
- **No file writes to component files** — even to "fix" obvious issues
- **No writing pencil-specs** — even partial; even in /tmp/ — that's Mode A's job
- **No setting labels** beyond what the role's actions explicitly do

## Design-specific traps

### Trap 1: "Let me just sketch the spec"

Tempting because the right answer is concrete visual / interaction definition. Don't. The advice describes capabilities and constraints; the actual spec is design Mode A's job.

If you find yourself listing "Visual: 16px gap, text-secondary color, 8px radius" — stop. That's a spec. Convert to architectural advice:

```markdown
WRONG (this is a spec):
- Card padding: 24px
- Card title: text-xl, weight 500
- Card border: 1px border-default

RIGHT (this is architectural advice):
- This is a "card" pattern. Card pattern exists at 
  skills/design/patterns/data-display.md and is in use across 7 
  surfaces. The request fits the pattern; recommend Mode A spec 
  authoring follows the existing card structure.
```

### Trap 2: "Let me update aesthetic-direction.md to reflect what I noticed"

The aesthetic direction may be stale or contradicted by recent code. Note it under "Drift noticed". Don't edit the file.

### Trap 3: "Let me add a token for this"

If a token is missing for what the request needs, surface in "Conflicts with request" or "Suggested approach": "request implies a new spacing scale stop / new color / new motion duration; this is a system-level addition that should be a separate task".

Never just add the token.

### Trap 4: "Let me improve the README"

`_shared/design-foundations/README.md` may be incomplete. Note it. Don't edit.

### Trap 5: "Let me write a draft pencil-spec to clarify my advice"

Drafting a spec to test the question is fine internally; committing it isn't. Drafts go in /tmp/ and are deleted at consultation close.

The temptation is strong because design Mode A is more concrete than design-advisor, and the natural impulse is "just give me the spec". Resist. The architectural decision must come first.

## What "drift" means and why advisors don't fix it

If you notice the design system documentation says one thing and the codebase shows another (e.g., aesthetic-direction.md says "minimalist" but landing pages use heavy animations), that's drift. Report under "Drift noticed":

```markdown
### Drift noticed
- _shared/design-foundations/aesthetic-direction.md (updated 2024-08) 
  describes "refined utilitarian, minimal animation". Marketing landing 
  pages (apps/marketing/) have prominent animations and decorative 
  gradients. Drift between documented direction and implementation. 
  arch-shape should decide which is canonical.
```

arch-shape decides what to do. design-advisor doesn't unilaterally update either side.

## What if the parent's body is wrong?

If the parent issue mis-states a design constraint (e.g., "we have a dark mode" when no dark mode tokens exist), don't edit the parent. Mention under "Conflicts with request" with specificity.

The discipline is: surface, don't fix.

## Anti-patterns

- **"While I was investigating, I noticed an unused token; let me clean it up"** — out of scope; surface as drift
- **"I drafted a spec in /tmp/spec.md and committed it because it was useful"** — that's writing a spec
- **"I added the missing 16px-large token because it was clearly needed"** — that's a system change without authority
- **"I commented on the parent with my findings"** — wrong issue
- **"I updated the patterns/forms.md case study to match what we discussed"** — out of scope
- **Pushing a branch with proposed changes** — even unmerged

## What read-only enables

- arch-shape can re-run consultations without state collision
- design (the implementer role) retains spec-authoring authority unambiguously
- The system stays "advice-then-decide-then-spec" rather than "advice-conflated-with-spec"
- design-advisor advice is reusable across multiple consultations on related questions

## Quick checklist

Before closing the consultation:

- [ ] No `git commit` ran
- [ ] No `gh issue edit` ran on any issue
- [ ] No `gh pr` commands ran
- [ ] No file writes to `_shared/design-foundations/`
- [ ] No file writes to `skills/design/`
- [ ] No file writes to component / token / config files
- [ ] No spec-like content drafted that could be mistaken for a Mode A spec
- [ ] No labels modified except the close action
- [ ] Working files in /tmp/ deleted
