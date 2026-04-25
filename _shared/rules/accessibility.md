# Accessibility (a11y)

WCAG 2.2 AA baseline. Applies to FE (implementation) and Design (specs).

## Semantic HTML

- Use the right element for the job. `<button>` for actions, `<a>` for navigation.
- Headings (`<h1>` … `<h6>`) form an outline; don't skip levels.
- Lists use `<ul>` / `<ol>`. Don't fake them with divs.
- Forms have `<label>` connected via `for` / `htmlFor` or wrapping.

## Keyboard

- Every interactive element is reachable by Tab.
- Focus order matches visual order.
- Focus indicator is visible. Don't `outline: none` without a replacement.
- Escape closes modals; Enter activates focused buttons.
- Custom controls handle their own keyboard interactions per WAI-ARIA Authoring Practices.

## Colour & contrast

- Text contrast ≥4.5:1 (large text ≥3:1).
- Don't convey information by colour alone. Combine with text, icons, or shape.
- Disabled state: contrast may relax, but the element shouldn't appear interactive.
- Test designs in greyscale before sign-off.

## Images

- `<img>` has `alt`. Empty `alt=""` for decorative images; descriptive for informational.
- Icons used as buttons need `aria-label` or visually hidden text.
- Background images that convey meaning must have a text alternative.

## ARIA

- First rule of ARIA: don't use it if a native element does the job.
- `role` doesn't change behaviour; pair with the JS that implements that behaviour.
- `aria-hidden` removes from accessibility tree — be sure that's what you want.
- `aria-live` for dynamic content. `polite` for most updates, `assertive` for errors only.

## Motion

- `prefers-reduced-motion` respected. Animations disabled or substantially shortened.
- Auto-playing video / parallax: don't.
- Transitions ≤200ms or under user control.

## Validation

FE-side validator runs:
```bash
axe-core src/
# In Playwright tests:
await injectAxe(page);
await checkA11y(page);
```

Design-side checks happen during Design review per `design/workflow/review.md`.
