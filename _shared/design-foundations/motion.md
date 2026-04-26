# Motion

The most over-applied foundation. The default for motion should be *less*, not more.

## When motion adds value

Motion is justified when it:

1. **Provides feedback** for an action (button press, item dragged)
2. **Maintains spatial context** during a transition (page slides in showing where it came from)
3. **Directs attention** to a change (a number ticking up, a notification appearing)
4. **Communicates state** (loading spinner, progress bar)
5. **Creates personality** (only for moments where personality is appropriate — landing pages, onboarding)

When motion is **not** justified:

- Decorating a static element ("make it spin because empty")
- Adding "delight" without functional purpose
- Replacing instant feedback with a delay
- Drawing attention to things that don't need it

The test: would removing the motion break the user's understanding? If no, the motion is decoration. Decoration is fine in moderation; ubiquitous decoration is noise.

## Duration

The single most important parameter. Defaults that work:

| Duration | Used for |
|----------|----------|
| **0ms** (instant) | Most state changes — hover, click feedback |
| **75-100ms** | Quick acknowledgments — button press color change, checkbox flip |
| **150-200ms** | Element entrances/exits — tooltip appears, dropdown opens |
| **300-400ms** | Larger transitions — modal opens, page changes |
| **500-700ms** | Storytelling moments — onboarding step transitions, key feature reveals |
| **>1000ms** | Almost always wrong — only for genuine narrative content |

The pattern: **smaller things move faster**.

```css
--duration-instant: 0ms;
--duration-quick: 100ms;
--duration-fast: 200ms;
--duration-base: 300ms;
--duration-slow: 500ms;
```

If your defaults are 500-1000ms, you're slowing the interface down. Users feel sluggishness as a usability problem before they consciously notice the durations.

## Easing

The curve a value follows from start to end. The big four:

```css
/* Linear — constant speed; rarely used (feels mechanical) */
--ease-linear: linear;

/* Ease-out — fast start, slow end; default for things APPEARING */
--ease-out: cubic-bezier(0.0, 0, 0.2, 1);

/* Ease-in — slow start, fast end; default for things LEAVING */
--ease-in: cubic-bezier(0.4, 0, 1, 1);

/* Ease-in-out — symmetric; default for things MOVING */
--ease-in-out: cubic-bezier(0.4, 0, 0.2, 1);
```

The semantic mapping:

- **Entering the screen**: ease-out (decelerates as it arrives — feels grounded)
- **Leaving the screen**: ease-in (accelerates as it goes — feels resolved)
- **Moving from A to B on the screen**: ease-in-out (smooth on both ends)
- **Background animations** (loading, idle effects): ease-in-out or linear

Custom curves (spring physics, bouncy) are appropriate for playful designs. For most product UI, the four above are enough.

## Choreography

When multiple things animate together, they shouldn't all move at once. Stagger them.

Example: a list of cards appearing on page load.

```css
.card { animation: fade-in 200ms ease-out backwards; }
.card:nth-child(1) { animation-delay: 0ms; }
.card:nth-child(2) { animation-delay: 50ms; }
.card:nth-child(3) { animation-delay: 100ms; }
.card:nth-child(4) { animation-delay: 150ms; }
```

The 50ms stagger creates a clear "wave" without being slow. Cards arrive in sequence, the eye follows naturally.

Bad choreography:

- All elements animate simultaneously (chaotic)
- Stagger too long (200ms+) — feels delayed
- Too many staggered elements — first user action waits for animation to finish
- Stagger on items that don't share semantic relationship (random elements ≠ wave)

## Page transitions

For SPA route changes, two common patterns:

### Cross-fade (most common, safe)

Old content fades out (150ms ease-in), new content fades in (200ms ease-out, slightly delayed). Total: ~250ms.

### Slide / shared element

For transitions where there's spatial relationship between pages (item in list → detail view), animate the shared element across the transition. Powerful but expensive to maintain.

Most products should default to cross-fade. Slide transitions are great when they're justified, awful when they're not.

## Loading states

Three options for showing work-in-progress:

1. **Skeleton screens** — show placeholder shapes for the content that's loading. Keeps layout stable.
2. **Spinners** — universal "something is happening". Works but signals "please wait".
3. **Progress bars** — for known-duration tasks (uploads, multi-step processes).

Default to skeletons for content fetching (page loads, lists, details). Use spinners for UI-triggered actions where the duration is short and unknowable. Use progress bars for long operations.

A spinner that spins for 5+ seconds creates anxiety. If something will take that long, switch to a progress bar (estimated) or a step-by-step indicator.

## Reduced motion

Some users have vestibular conditions that make animations physically uncomfortable. Respect:

```css
@media (prefers-reduced-motion: reduce) {
  *,
  *::before,
  *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
```

This reduces all animations to effectively-instant. Don't disable them outright — feedback animations (button press flash) still serve users who want reduced motion. Just make them fast.

For more nuanced handling: keep functional animations (button feedback, modal open/close) at reduced speed; remove decorative animations entirely.

## Common motion mistakes

- **Default duration is 500ms+** — most things should be 100-300ms
- **Animating on every page load** — once is delight, every time is annoyance
- **Bouncy / springy animations everywhere** — appropriate for playful brands; out of place in serious products
- **Hover animations that delay clicks** — if the click target only registers after the hover animation, that's a 150ms delay every interaction
- **Loading spinners that appear for <500ms work** — by the time the user notices the spinner, the work is done. Just complete instantly or show after a delay.
- **Animation interrupted by another animation** — looks broken. Cancel cleanly or queue.
- **No `prefers-reduced-motion` handling** — accessibility violation
- **Animation as a way to "feel modern"** — modernity isn't conveyed by animation; it's conveyed by everything else

## When in doubt: less

If you're unsure whether a motion is needed, leave it out. A static, instant interface feels fast and confident. An animated interface feels considered when motion is purposeful, and slow when it's not.

The best product UIs use motion sparingly: feedback for clicks, transitions for state changes, occasional moments of personality. Everything else is instant.

## Quick checklist

For any animation:

- [ ] Duration ≤ 400ms unless a reason justifies more
- [ ] Easing matches direction (out for enter, in for exit)
- [ ] `prefers-reduced-motion` handled
- [ ] No animation on hover that delays click feedback
- [ ] Skeleton screens for content loads, not spinners
- [ ] Stagger only when wave-like sequence helps comprehension
- [ ] Removing the motion would make the UI worse, not better
