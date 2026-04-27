# Rule — Evidence Over Opinion

Every claim cites concrete evidence: foundation document, pattern document, token definition, WCAG SC, codebase grep result, or aesthetic-direction reference. Opinions without evidence dilute the consultation's value.

## The contrast

**Opinion** (low value):
```
- This wouldn't fit our design system
- The aesthetic is too modern for our brand
- Adding a dark mode is hard
```

**Evidence** (high value):
```
- Pattern catalog (skills/design/patterns/) has 6 documented patterns; 
  none cover "dense data table with inline edit". Introducing this 
  pattern adds 1 file (~150 lines like other patterns) plus the actual 
  component implementation. This is system-level work, not single-spec.
- Aesthetic direction (_shared/design-foundations/aesthetic-direction.md) 
  is "refined utilitarian, restrained palette". Request's "vibrant 
  hero with diagonal gradients" departs significantly. Recent landing 
  pages also depart (apps/marketing/landing-2024.tsx); these are the 
  third drift instance in 6 months.
- Dark mode would require ~30 token mappings (counted: 30 color 
  tokens in tokens.json without dark variants) and per-component 
  verification across ~80 components.
```

The evidence answers "how do you know?" before arch-shape has to ask.

## Citation conventions

In the advice:

- **Foundation reference** — `_shared/design-foundations/typography.md`
- **Pattern reference** — `skills/design/patterns/forms.md`
- **Token reference** — `tokens.json (--brand-500)` or `tailwind.config.js (colors.brand[500])`
- **WCAG SC reference** — `WCAG 2.2 SC 1.4.3 (contrast)`
- **Component reference** — `components/ui/Button.tsx:42`
- **arch-ddd reference** — `arch-ddd/design-system.md` if exists
- **Grep result** — `(grep "<Modal" → 18 matches)`
- **Visual reference (deployed)** — `(verified at https://staging.../checkout)`

Make it easy for arch-shape to verify.

## Investigation tools

```bash
# Foundations
ls _shared/design-foundations/
wc -l _shared/design-foundations/*.md   # how detailed is each foundation?

# Patterns  
ls skills/design/patterns/
grep -l "Pattern" skills/design/patterns/*.md   # established patterns

# Token coverage
grep -c "^\s*--" tokens.css 2>/dev/null
grep -A100 "colors:" tailwind.config.js 2>/dev/null

# Component count
find components/ -name "*.tsx" -type f | wc -l
ls components/ui/ 2>/dev/null

# Pattern usage in codebase
grep -rl "<Modal" apps/ components/ | wc -l
grep -rl "<Form" apps/ components/ | wc -l

# Hardcoded values (drift indicator)
grep -rE "#[0-9a-fA-F]{6}" apps/ components/ | grep -v test | head
grep -rE "padding:\s*1[357]px|padding:\s*[0-9]+px" apps/ | grep -vE "(0|2|4|8|12|16|24|32|48)px" | head

# Aesthetic-direction adherence
git log -p --since "6 months ago" -- _shared/design-foundations/aesthetic-direction.md
git log --oneline -- apps/marketing/

# Accessibility coverage
grep -rl "aria-" components/ | wc -l
grep -rl "prefers-reduced-motion" apps/ | wc -l
```

## When evidence is unavailable

Sometimes you can't gather evidence in 2 hours — design system undocumented, foundations files missing, aesthetic direction unclear. Two options:

### Option 1: Acknowledge limit explicitly

```markdown
### Existing constraints

- Aesthetic direction: file _shared/design-foundations/aesthetic-direction.md 
  exists but is sparse (~20 lines, mostly principles). Implicit aesthetic 
  inferable from existing surfaces but not documented. I sampled 5 
  surfaces and the implicit direction reads as "minimalist modern 
  with brand-blue accents".
- Patterns: 6 patterns documented in skills/design/patterns/. The actual 
  product uses these 6 patterns plus 3-4 undocumented variants (sampled 
  from existing surfaces). Comprehensive pattern audit out of scope.
```

### Option 2: Defer to future work

```markdown
### Conflicts with request

- This consultation needs aesthetic direction clarity that the current 
  documentation doesn't provide. Recommend either (a) arch-shape 
  pause this decomposition, open a separate "document the aesthetic 
  direction" task, then resume; or (b) make this consultation's 
  decision based on the available implicit signals, accepting risk 
  of misalignment.
```

## Counts vs estimates

When possible, count:

- "many components" — opinion
- "~80 components" — estimate
- "82 components in components/, 60 in features/, 42 in apps/* (verified: find . -name '*.tsx' | wc -l)" — measured
- "extensive token coverage" — opinion
- "30 color tokens, 8 spacing tokens, 8 type sizes, 4 radii, 4 motion durations (verified: tokens.json)" — measured

## Design-specific evidence priorities

### Aesthetic-direction fingerprint

When a request potentially departs from aesthetic direction:
- The documented direction (file + last update date)
- Recent surfaces' alignment (grep + sample)
- Any prior departures (git log of marketing / landing changes)

### Pattern catalog fingerprint

When a request needs a new pattern:
- Existing pattern names
- Pattern file lengths (proxy for depth)
- Codebase usage of each pattern (grep counts)

### Token coverage fingerprint

When a request implies a new visual property:
- Token category coverage (color stops, spacing stops, etc.)
- Token consumption count (how many components use each)
- Hardcoded values (drift; tokens that should exist but don't)

### Accessibility coverage fingerprint

When a request has a11y implications:
- Established a11y patterns (ARIA usage count)
- WCAG conformance level (typically AA in foundations)
- Reduced-motion handling presence

## Anti-patterns

- **"It would feel inconsistent"** without identifying the consistency rule
- **"This is too modern"** without aesthetic-direction reference
- **"Easy to extend"** without checking pattern depth
- **Citing memory of design system** instead of reading files
- **Inferring tokens from one component** instead of reading the source of truth
- **Reporting the design you'd want** instead of what's there
- **Confusing "this is documented" with "this is consistently followed"** — drift is common

## Why this matters most for advisors

For design (the implementer), opinion shows up in pencil-specs — review catches it. For advisor roles, opinion shows up in advice arch-shape uses to decide. Bad advice → bad decomposition → wasted spec rounds, design system fragmentation. The error compounds.

The rule is "every assertion should be one a reader can verify in 30 seconds — by reading a file, running a grep, or checking a deployed surface". If that's possible, the assertion is sound.

## Quick checklist

- [ ] Every constraint bullet has a foundation / pattern / token / WCAG reference
- [ ] Suggested approach cites which existing pattern it extends
- [ ] Conflicts give specific design-system reasons
- [ ] Scope estimate has counts (patterns, tokens, components)
- [ ] Risks describe specific failure modes (fragmentation, a11y, aesthetic drift)
- [ ] Drift includes both documented direction and codebase reality
