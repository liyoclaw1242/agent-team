# Rule: AI Design Audit

**Always active.** AI-generated interfaces have predictable failure modes. Check for ALL of these after every implementation.

Inspired by Impeccable (Paul Bakaus) — encoding decades of "this looks wrong" into executable rules.

## Font Errors

| Error | What AI does | Fix |
|-------|-------------|-----|
| Too many fonts | Uses 3-4 different font families | Max 2: one for headings, one for body |
| Decorative fonts for body | Picks a fancy font for paragraph text | Body text: system font or clean sans-serif |
| Missing font-weight variation | Everything is `font-normal` | Use semibold for headings, medium for labels, normal for body |
| Wrong tracking | Default letter-spacing everywhere | Tight (-0.02em) for large headings, normal for body, wider for eyebrows |

## Color Errors

| Error | What AI does | Fix |
|-------|-------------|-----|
| Low-contrast gray text | `text-gray-400` on white background | Min 4.5:1 contrast ratio, use `text-muted-foreground` token |
| Pure black background | `bg-black` for dark mode | Use `bg-gray-950` or `bg-zinc-950` (softer) |
| Random accent colors | Each section gets a different color | One primary, one accent, rest neutral |
| Neon/saturated colors | Bright blue/green/purple everywhere | Desaturate, use muted variants |
| No color hierarchy | Everything same visual weight | Primary action = saturated, secondary = muted, tertiary = ghost |

## Layout Errors

| Error | What AI does | Fix |
|-------|-------------|-----|
| Center everything | Every element `text-center mx-auto` | Left-align text, asymmetric layouts |
| Equal card grids | 3 identical cards in a row | Feature one card, vary importance |
| Nested cards | Card inside card inside card | Max 2 levels of nesting |
| Too much padding | `p-8` or `p-12` on everything | Use spacing scale: 4/8/12/16/24 |
| No breathing room | Elements cramped together | Add section gaps (32-48px between major sections) |

## Component Errors

| Error | What AI does | Fix |
|-------|-------------|-----|
| Flat buttons | Buttons look like text links | Add fill or border + hover state + padding |
| Oversized buttons | `h-16 text-xl` buttons | 36-38px height, text-sm for most buttons |
| Missing states | Only default state implemented | Add loading, error, empty, disabled, hover, focus |
| Fake data looks fake | "Lorem ipsum" or "John Doe" | Use realistic-looking data: real names, plausible numbers |
| Icon overload | Icon on every button and label | Icons for navigation + primary actions only |

## Border/Shadow Errors

| Error | What AI does | Fix |
|-------|-------------|-----|
| Solid gray borders | `border border-gray-300` everywhere | Ring technique: `ring-1 ring-black/5` |
| No elevation difference | Cards and background same level | Cards: `shadow-sm` or `ring-1 ring-border` |
| Drop shadow too harsh | `shadow-lg` or `shadow-xl` | `shadow-sm` for most, `shadow-md` for elevated modals |

## Validation

After every implementation, go through this checklist:

```
AI Design Audit:
- [ ] Max 2 font families?
- [ ] Heading/body font-weight contrast?
- [ ] No low-contrast gray text?
- [ ] No pure black backgrounds?
- [ ] One color hierarchy (primary > secondary > ghost)?
- [ ] Left-aligned text (not center everything)?
- [ ] No card-in-card-in-card?
- [ ] Buttons 36-38px height?
- [ ] All component states present?
- [ ] Ring borders (not solid gray)?
- [ ] Subtle shadows (not harsh)?
- [ ] Realistic-looking sample data?
```
