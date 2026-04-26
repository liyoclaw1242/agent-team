# Design Foundations

Universal design knowledge shared between roles. Both `skills/design/` (for spec authoring and visual review) and `skills/fe/` (for implementation) read this directory.

## Files

| File | What it covers |
|------|----------------|
| `aesthetic-direction.md` | Picking and committing to a visual direction; avoiding generic AI aesthetics |
| `typography.md` | Type scale, weight, line-height, pairing, fluid type |
| `color.md` | Palettes, neutrals, semantic colors, contrast, dark mode, tokens |
| `space-and-rhythm.md` | Spacing scale, vertical rhythm, density |
| `hierarchy.md` | How to make important things obvious; the four levers (size, weight, color, position) |
| `layout-and-grid.md` | Grids, container widths, breakpoints, alignment |
| `motion.md` | When motion adds value; durations and easings; choreography |
| `iconography.md` | Icon systems, sizing with text, alignment, stroke weight |

## How to use

When designing or implementing UI:

1. Start with `aesthetic-direction.md` — establish or read the current direction
2. Read the foundations relevant to your task (typography for text-heavy, color for data viz, etc.)
3. Apply consistently — the foundations are a system, not a menu

## Tension between novelty and consistency

`aesthetic-direction.md` reflects a "be bold, avoid generic AI aesthetics" stance — appropriate for one-off creative work (landing pages, marketing sites, demos). The other foundations (typography, color, space) reflect a "pick a system and stick to it" stance — appropriate for product UI where consistency matters more than novelty.

Both apply. The first asks "what's the aesthetic direction?". The rest ask "how do you execute that direction with discipline?". Don't read them as contradictory — read them as a creative-then-systematic sequence.

For product UI work specifically: pick the direction once (often by reading existing patterns in the codebase), then apply the systematic foundations. For greenfield creative work: spend more energy on the aesthetic direction; the foundations still apply but with more latitude for breaking rules.
