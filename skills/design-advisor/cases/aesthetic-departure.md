# Case — Aesthetic Departure

A request that, taken at face value, would depart from the committed aesthetic direction. design-advisor surfaces the departure clearly and proposes paths that preserve direction while serving the request's intent.

## The consultation

Parent issue #4010: "Make the new product launch landing page eye-catching, modern, and exciting — use bold colors, gradients, and animations to drive conversions."

arch-shape opened consultation #4011 to design-advisor:

```
- Does this fit our aesthetic direction?
- What's the existing approach for marketing surfaces?
- Recommended path?
```

## Phase 1 — Investigate

```bash
# Aesthetic direction
cat _shared/design-foundations/aesthetic-direction.md
# → "refined utilitarian, restrained palette, content-first"
# → explicitly cautions against "AI slop tells": purple-to-blue gradients,
#   glass morphism, floating cards, etc.
# → encourages bold maximalism OR refined minimalism — but committed
# → current commitment: "refined minimalism with brand-blue accents"

# Last update
git log -1 --format=%ci -- _shared/design-foundations/aesthetic-direction.md
# → 2024-08-14 (1.5 years ago)

# Existing marketing surfaces
ls apps/marketing/
# → landing.tsx, pricing.tsx, about.tsx, careers.tsx, blog/

# How aligned are existing marketing surfaces?
grep -rE "from-.*to-.*gradient" apps/marketing/  
# → 3 hits in apps/marketing/landing-2024.tsx (newer landing)
# → 0 hits in older marketing surfaces

# Marketing surface created when?
git log --diff-filter=A --format=%ci -- apps/marketing/landing-2024.tsx
# → 2024-11 (4 months ago)
# → so the gradient pattern entered marketing 4 months ago, after the
#   aesthetic direction commitment

# Other recent marketing
ls -la apps/marketing/
git log --since "1 year ago" --oneline -- apps/marketing/ | head
# → 5 PRs added marketing surfaces in last year
# → 2 of them depart from aesthetic direction (gradients, animations)

# Conversion data?
ls analytics/ 2>/dev/null
# → no analytics in repo (would need data team consult)

# A11y track record on marketing surfaces
grep -c "aria-" apps/marketing/landing-2024.tsx
# → 8 aria attributes
grep -E "@media.*reduced-motion" apps/marketing/landing-2024.tsx
# → 0 matches
# → reduced-motion not handled despite use of animations

# Token usage in marketing
grep -E "#[0-9a-f]{6}" apps/marketing/landing-2024.tsx
# → 4 hardcoded hex codes
# → drift: marketing uses off-system colors
```

## Phase 2 — Compose response

```markdown
## Advice from design-advisor

### Existing constraints

- Aesthetic direction (_shared/design-foundations/aesthetic-direction.md, 
  last updated 2024-08): "refined utilitarian, restrained palette, 
  content-first. Refined minimalism with brand-blue accents." 
  Explicitly cautions against: purple-to-blue gradients, glass 
  morphism, floating-card grids, "modern" decoration cliches. Lists 
  these as "AI slop tells".
- Recent marketing surfaces have drifted from this direction:
  - apps/marketing/landing-2024.tsx (added 2024-11) uses 3 gradient 
    treatments (`from-...to-...` Tailwind utilities)
  - 4 hardcoded hex colors in landing-2024.tsx (off-token; drift)
  - Reduced-motion handling absent despite animations 
    (verified: no @media (prefers-reduced-motion) match)
- 5 marketing surfaces created in the last year; 2 depart from 
  aesthetic direction. Older surfaces (about.tsx, careers.tsx) 
  remain aligned.
- No conversion data in repo to evaluate whether the recent 
  departures actually drove conversions. Would need data-team 
  consult to verify the assumption that "bold = converts better".
- Aesthetic direction file is 1.5 years old; the recent drift 
  may indicate the direction itself is stale, not just that 
  marketing departed.

### Suggested approach

The request and the documented direction conflict. Three framings:

- **A) Update aesthetic direction first**: this consultation reveals 
  the direction may be stale (4 months of drift in marketing 
  surfaces). Open a separate task to revisit aesthetic-direction.md 
  with input from marketing / brand. Once direction is updated, 
  this landing page is built within the new direction. Highest 
  effort upfront; cleanest going forward.

- **B) Treat marketing as a documented exception zone**: keep the 
  product aesthetic ("refined utilitarian"); explicitly document 
  that marketing surfaces operate under different aesthetic rules 
  ("expressive, conversion-driven, can use color and motion freely"). 
  Then build this landing page accordingly. Mid effort; honest about 
  the divergence.

- **C) Reinterpret "eye-catching" within the existing direction**: 
  the existing direction allows "bold maximalism OR refined 
  minimalism" but committed to refined minimalism. Within refined 
  minimalism, "eye-catching" means deliberate use of brand-blue, 
  generous typography, strong content hierarchy — not gradients 
  and animations. This is design's traditional answer when intent 
  ("convert visitors") is preserved without departing from system. 
  Lowest effort; assumes the requester accepts the reinterpretation.

Recommend **B** because:
- The request reflects a real, recurring need: marketing has 
  different goals than product UI
- Marketing has already drifted; documenting it as deliberate is 
  better than letting it accumulate as silent drift
- Keeps product UI consistent (refined direction) while letting 
  marketing be expressive
- Doesn't require updating aesthetic-direction at the system level 
  (separate, larger conversation)

If arch-shape strongly believes the system aesthetic should evolve 
toward expressive (Direction A), this consultation also surfaces 
that case — but A is bigger work and shouldn't ride on a single 
landing page.

If arch-shape believes the request is wrong about "bold = converts" 
(Direction C), it's a quick win and avoids doc updates — but 
relies on the requester accepting reinterpretation.

### Conflicts with request

- "Bold colors, gradients, animations" is precisely what the 
  aesthetic direction's "AI slop tells" section cautions against. 
  Building this would visibly contradict the documented direction. 
  arch-shape needs to decide: depart from direction (A or B), or 
  reinterpret request (C).
- Conversion claim ("drive conversions") is unverified in this 
  consultation. Without conversion data, the premise that "more 
  visual = better conversion" is folk wisdom. Recommend confirmation 
  before committing to direction-departing work; refined surfaces 
  often outperform "loud" ones for the right audience.
- Accessibility risk: animations in marketing pages historically 
  miss reduced-motion handling (verified: landing-2024.tsx has none). 
  If we sanction more animation-heavy surfaces, a11y discipline must 
  be enforced. Not optional.

### Estimated scope

- For Direction A (update aesthetic direction first): L+ — separate 
  effort; aesthetic-direction.md update needs cross-team input, 
  decision documentation, possibly token additions if direction 
  shifts. Strongly suggest decomposing — direction update is its 
  own task, not bundled with one landing page.

- For Direction B (document marketing as exception zone): M:
  - Update aesthetic-direction.md to add "marketing exception zone" 
    section (~30 lines)
  - Document marketing-specific guidance (color use, motion use, 
    a11y requirements for marketing)
  - Then 1 pencil-spec for the landing page within the new exception 
    rules
  - Some retroactive cleanup (consolidate landing-2024.tsx with the 
    new framework; possibly fix its a11y gaps)

- For Direction C (reinterpret within existing direction): S — 
  1 spec, fits existing pattern; the work is mostly negotiating 
  the reinterpretation with the requester.

### Risks

- Direction A: aesthetic-direction updates rarely succeed in a 
  single consultation; require iteration with stakeholders. Don't 
  rush. Bundling with a landing page deadline creates pressure to 
  ship a half-baked direction.

- Direction B: "marketing exception zone" can grow; without 
  discipline, "marketing" can encompass ever more surfaces 
  ("the dashboard is marketing for upsells", "the empty state 
  is marketing"). Need to draw the line.

- Direction C: requester may push back ("I want loud, you're giving 
  me restrained"). Need design / brand alignment before committing.

- All directions: a11y compliance for any animation work. 
  Reduced-motion handling, contrast in gradients, focus visibility 
  on decorated buttons — these are non-negotiable.

- Direction B and beyond: every new marketing surface creates 
  precedent. The first "expressive" landing page sets the tone 
  for the next 10. Worth getting the framing right.

### Drift noticed

- aesthetic-direction.md (last updated 2024-08, ~1.5 years old) 
  hasn't been revisited despite product evolution. May genuinely be 
  stale; this consultation surfaces the question.
- 4 months of recent marketing surfaces have drifted from 
  documented direction without that drift being acknowledged or 
  documented. Silent drift is the worst kind — it accumulates 
  without informed consent.
- apps/marketing/landing-2024.tsx has 4 hardcoded hex codes 
  (off-token); drift in token discipline. Could be cleaned up 
  alongside this work.
- Reduced-motion handling missing in animated marketing surfaces 
  is an a11y gap that needs addressing regardless of which 
  direction is chosen for this consultation. Worth filing as 
  separate task.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 4011 \
  --advice-file /tmp/advice-issue-4011.md
```

## What this case demonstrates

- **Confronted aesthetic conflict directly**: didn't soften the disagreement
- **Three honest directions**: each with cost and trade-off; arch-shape decides
- **Pushed back on premise**: "bold = converts" is folk wisdom; surfaced for verification
- **Surfaced a11y gap as non-negotiable**: animation work without reduced-motion is a violation
- **Identified silent drift**: 4 months of undocumented departure from direction
- **Recommended pragmatic Direction B**: documented exception zone is honest about reality
- **Refused to make a system-level decision quietly**: aesthetic-direction updates need cross-team input

## Key lessons for aesthetic-departure consultations

1. Aesthetic direction is committed; departures aren't free
2. Silent drift over months is worse than open exception zones
3. Marketing / brand surfaces often have different goals than product UI; sometimes the right answer is to acknowledge that explicitly
4. Conversion claims should be verified, not assumed
5. A11y gates are non-negotiable regardless of aesthetic direction
6. The right answer often isn't "do it" or "don't do it" but "frame it honestly"
7. Aesthetic-direction documents are themselves living artifacts; consultations sometimes reveal them as stale
