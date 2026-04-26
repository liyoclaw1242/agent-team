# Aesthetic Direction

The first thing to establish before any UI work: **what does this look like, and why?**

Not "what does the spec say" — anyone can read a spec. The question is what the *intent* is. Is this a refined, restrained interface? A maximalist, expressive one? Something playful? Something institutional?

Without a direction, the result drifts toward generic — what most people call "AI slop": Inter font, purple gradients, flat cards on white, rounded buttons that look like every other product. Not bad, but forgettable, and unmistakably committee-designed.

## Picking a direction

For a new product or one-off creative work, pick something deliberately. Some directions worth considering:

- **Brutally minimal** — heavy negative space, tight monochrome palette, sharp grid, no decoration
- **Maximalist** — dense layouts, layered color, expressive type, ornament
- **Editorial** — magazine-like, mixed font sizes, hierarchical, content-forward
- **Industrial / utilitarian** — dense data, mono fonts, functional, almost CAD-like
- **Soft / pastel** — generous radius, muted palette, breathing room, friendly
- **Retro-futuristic** — chunky elements, saturated accents, deliberate "unmodern" feel
- **Brutalist / raw** — system fonts, hard edges, structural visibility, anti-polish
- **Refined / luxury** — extra spacing, thin type, restraint, deliberate whitespace

These aren't a menu — they're examples of what *committed* directions look like. The point is to commit, not to pick one labelled in a list.

## What to avoid (the AI slop tells)

Generic AI-generated aesthetics share a recognisable look. Watch for:

- **Inter / Roboto / system-default sans** without intentional pairing
- **Purple-to-blue or purple-to-pink gradients** on white backgrounds
- **Equal-weight cards** in a grid with the same rounded corners (`rounded-lg`)
- **Centered hero with CTA** as the default landing-page shape
- **"Modern" cliches**: glass morphism, neon-on-black, drop shadows everywhere
- **Timid palettes** where every color is the same saturation and value
- **Flat icons** floating in colored circles next to feature names
- **The same component patterns** as ten thousand other dashboards

Most of these aren't bad in isolation — they're bad as defaults. If you reach for purple gradient because it's the first idea, that's the warning sign. Reach further.

## When systematic > expressive

The above is for one-off and creative work. For **product UI inside an existing system**, the direction is usually already set — your job is to extend it consistently, not to express a new direction. In that mode:

- Read the existing patterns first
- Use the existing tokens (color, type, spacing) as-is
- Match component shape (radius, border weight, density)
- Save creative energy for the *new* problems, not for restyling solved ones

A new feature that visually fits feels right. A new feature that "improves" the styling makes the product feel inconsistent. Pick the right battle.

## Decision logging

When you commit to a direction (greenfield) or extend an existing one (product), record the decision somewhere it can be reviewed:

```markdown
## Aesthetic direction

**Pick**: editorial-minimal
**Rationale**: content is long-form and image-light; readers spend
minutes per page; restraint serves comprehension better than density
**Reference**: existing app patterns at /apps/marketing — keep colors,
adjust type for editorial tone

**Specifically**:
- Type: pair Söhne (display) with Source Serif 4 (body) for editorial weight
- Color: monochrome with one accent (--accent: #1a4d2e); generous neutrals
- Space: 1.6 line-height body; 80ch max measure; 96px section gaps
- No decorative gradients; sparse use of color
```

This is the document that the rest of the foundations refine. Without it, every decision downstream is unanchored.

## On bold maximalism vs refined minimalism

Both work. Both fail when half-committed.

A maximalist design with timid color is just busy. A minimalist design with arbitrary accents looks unfinished. Pick a polarity and execute it precisely. The mid-ground is where AI slop lives.

Refinement isn't always the answer; restraint isn't always the answer. **Intentionality** is the answer. The user will remember a deliberate aesthetic — they will not remember "well-balanced".

## When stuck

If you can't pick a direction, the question is probably wrong. Ask:

- What does this product *not* look like? (Eliminating cliches narrows the space.)
- What are three references — products, magazines, environments — that share the feeling I want? (Reference-based decisions are stronger than abstract ones.)
- What's the one thing someone will remember? Type? A specific color? A motion? Build around that.

If you can't answer those, get more context. Don't paper over a missing direction with "make it modern".
