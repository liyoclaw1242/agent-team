# Rule: Responsive Design

- Mobile-first: start with mobile layout, add `md:` / `lg:` breakpoints
- Test at 3 breakpoints: 320px (mobile), 768px (tablet), 1280px (desktop)
- Mobile: content stacks vertically, text remains readable, no horizontal scroll
- Tablet: layout adapts (e.g. 2-column), interactive targets stay tappable (min 44px)
- Desktop: uses available space intentionally, not just stretched mobile
- Prefer `flex` / `grid` with responsive gaps over fixed widths
- Hide non-essential elements on mobile rather than shrinking everything
- Navigation: collapse to hamburger or bottom nav on mobile
