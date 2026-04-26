# Case — Design Conflict (Mode C Feedback)

Mode C worked example. Scenario: spec asks for something that violates a foundation in a way that needs arch-level discussion. design posts feedback rather than authoring an off-foundation spec.

## The issue

```markdown
## Goal
Add a notification bell with unread count badge to the top navigation.

## Acceptance criteria
- [ ] AC #1: bell icon in the top-right of nav
- [ ] AC #2: red dot when unread notifications exist; number when ≥1
- [ ] AC #3: clicking opens a notification panel
- [ ] AC #4: badge size: 18px diameter; text 11px white on red background

<!-- intake-kind: business -->
<!-- parent: #601 -->
```

## Phase 1 — Read

Foundations:
- `typography.md` — type scale starts at 12px; **11px is below the floor**
- `color.md` — text-on-color contrast computed
- `aesthetic-direction.md` — project is "refined utilitarian"; loud red badges may not fit

The issue's AC #4 specifies 11px text, which is below the typography scale's minimum. This is the conflict.

Verify:
- Is 11px really off-scale for this product? Check tokens. Confirmed: scale is 12 / 14 / 16 / 18 / 23 / 29 / 36 / 45.
- Is there a reason 11px was specified? AC says "text 11px"; no rationale.

Computed contrast for white on red-500: 4.7:1 (PASS AA at 11px? — need to verify the specific SC).

WCAG 2.2 SC 1.4.3 says "normal text" requires 4.5:1. 11px is normal text. So contrast itself passes.

But there's another consideration: WCAG 1.4.4 (AA) — Resize text — text must be resizable to 200% without loss of content/functionality. At 11px scaled 2x = 22px; OK on the rendering side. But text below 12px is generally considered a usability issue beyond strict WCAG.

The conflict is foundation, not a11y. The type scale starts at 12px because below that, legibility on common screen densities is poor. Going off-scale weakens the system.

## Phase 2 — Decide whether feedback or implement

Could I just implement at 12px (closest scale value) and note it in the spec? Two reasons not to:

1. The AC was specific (11px). If I implement at 12px, fe builds at 12px, but the AC technically isn't met. There's no AC saying "11px or thereabouts".
2. The badge use case may benefit from being slightly smaller; if so, the type scale itself might need a 10px or 11px stop added (deliberately introducing a "label-tiny" tier). That's an architecture-level discussion, not a spec.

The right move: feedback to arch. Either arch agrees 12px is fine (most likely; AC was probably approximate), or arch adds a new scale stop (less likely but possible).

## Phase 3 — Compose feedback

```markdown
## Technical Feedback from design

### Concern category
foundation-conflict

### What the spec says
"Badge size: 18px diameter; text 11px white on red background"

### What the foundation reality shows
Type scale defined in `_shared/design-foundations/typography.md` starts at 12px:
12 / 14 / 16 / 18 / 23 / 29 / 36 / 45 (Major Third).

11px is below the scale. The scale starts at 12px because below that, glyph
rendering on common screen densities (1x, 1.5x, 2x) becomes inconsistent;
characters cluster; legibility degrades.

WCAG 1.4.3 contrast requirement (AA) — at 11px white on red-500 passes 4.7:1.
This is a usability concern, not a strict accessibility violation. But sub-12px
text in production UI is generally considered poor practice.

### Options I see
1. Use 12px (`text-xs`) — closest scale value; minor visual shift from 11px;
   keeps the system intact
2. Use 10px (genuinely small) — would need to add a `text-2xs` stop to the
   scale (architecture-level decision; affects whole product)
3. Make the badge slightly larger so the 11px requirement isn't visually
   needed — e.g., 22px diameter with 14px text reads similarly to 18px/11px
   in context
4. Hide the number when count > 9 ("9+" badge); this lets the badge stay
   small without needing tiny type because the content is shorter
5. Stick with 11px off-scale (rejected — weakens the system; sets precedent)

### My preference
Option 1. The visual difference between 11px and 12px in a notification
badge is minimal; users won't notice. Keeping the type scale clean is worth
the 1px deviation from the original AC.

If the AC was intentional (someone really wanted exactly 11px for design
reasons), Option 4 (text "9+" instead of "10") would let us keep the badge
visually compact without going off-scale.

### Drift noticed
None directly relevant; the type scale itself is well-defined and used
consistently elsewhere.
```

## Phase 4 — Post and route

```bash
bash actions/feedback.sh \
  --issue 602 \
  --feedback-file /tmp/feedback-602.md
```

The feedback action:
- Validates header is exactly `## Technical Feedback from design`
- Posts as a comment on issue #602
- Routes #602 to `agent:arch`

dispatcher routes to `arch-feedback` (since `## Technical Feedback from` was detected).

## Phase 5 — arch-feedback decides

arch-feedback reads the feedback, weighs options:

- The agent's preference is option 1 (12px)
- Cost of accepting: trivial (update AC #4 to "text-xs / 12px"); fe implements at 12px
- Cost of countering: requires defending why 11px was specified; if defensible, agent is wrong

arch-feedback accepts:

```markdown
## Feedback decision: ACCEPT

The original AC's specific 11px size was approximate; the system's type
scale starts at 12px and that's the right default. Agreed with option 1.

Updating AC #4 to: "Badge size: 18px diameter; text 12px white on red
background (text-xs)".

design: please re-spec with 12px text. The rest of the spec proceeds
unchanged.
```

The AC is updated; issue #602 routes back to design with new state.

## Phase 6 — design re-specs

design re-reads the updated issue, restarts from `workflow/pencil-spec.md` Phase 1, and produces the spec with 12px text. No further conflict.

## Self-test for the feedback round

```markdown
# Self-test record — issue #602 (design feedback round 1)

## Acceptance criteria
- [x] AC #1: investigated foundation concern — typography.md scale checked
- [x] AC #2: posted Mode C feedback with format — header and structure correct
- [x] AC #3: routed to arch — feedback.sh succeeded

## Foundations consulted
- typography.md (scale; reasons for 12px floor)
- color.md (contrast verification — passes)

## Feedback summary
Concern: foundation-conflict (11px below 12px scale floor)
Routed: agent:arch (for arch-feedback)

## Ready for review: yes
```

## What this case demonstrates

- **Feedback isn't combat**: framed as "here are options + my preference"
- **Computes the actual issue**: contrast verified (passes); the issue is type scale, not a11y per se
- **Multiple options offered**: gives arch flexibility; prevents ping-pong
- **Foundation-anchored**: cites typography.md specifically, not "I think it's small"
- **Round 1 only**: design accepts arch's decision; no round 2 needed
- **Result is a spec that respects the system**: the exchange improves the product over silently building off-foundation

## When NOT to write Mode C feedback

If the spec violation were tiny — e.g., spec says 16px gap, the standard nearby pattern uses 14px — that's a spec choice, not a foundation conflict. Implement what the spec says; flag the inconsistency in your spec notes.

If the spec were wrong in a way you could just fix in the spec — e.g., AC says "use red color" but no color is specified, you can pick danger-500 from semantic colors and document why — no Mode C needed. Spec authoring includes filling reasonable gaps.

Mode C is for genuine "this needs arch-level discussion before I author a spec".
