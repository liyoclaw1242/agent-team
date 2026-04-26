# Hierarchy

The most important question in any UI: **what's the most important thing on this screen?** If the answer takes more than a glance, the hierarchy is broken.

## The four levers

You make something more important using one of four levers, in rough order of impact:

### 1. Size
Bigger = more important. The strongest signal.

A 32px headline reads as more important than a 16px headline next to it. A 200px hero image dominates a 80px thumbnail. Size is the first lever to reach for.

### 2. Weight
Bolder = more important.

Within the same size, a 700-weight word draws the eye over a 400-weight word. Weight contrast within text creates micro-hierarchy without changing layout.

### 3. Color
High-contrast or saturated = more important.

Black text on white grabs more attention than gray on white. A red dot on a gray scrollbar is the only thing your eye sees. Color is potent — overuse it and nothing stands out.

### 4. Position
Higher = more important. Centered or isolated = more important.

Top-of-page is read first (in left-to-right cultures, top-left specifically). Things in their own space — surrounded by whitespace — feel important. Things crammed in a list of similar items feel equal.

## The combinations

Most well-designed elements use 2-3 levers in concert:

- **Page title**: size (large) + weight (bold) + position (top, left or centered)
- **Primary CTA**: color (brand color fill) + weight (bolder text) + position (after content)
- **Error message**: color (red) + size (slightly larger than body) + position (close to source of error)
- **Body text**: low on all levers — that's why it's body text

Mistakes happen when too many levers are pulled at once for the same element ("make it bigger AND bolder AND red AND centered AND uppercase") — it stops feeling important and starts feeling like shouting.

## Hierarchy as a tree

A well-designed screen has a clear hierarchy tree:

```
Page
├── Page title (level 1 — most important)
│   └── Subtitle (level 1.5)
├── Primary section
│   ├── Section heading (level 2)
│   ├── Content
│   ├── Primary action (level 1.5 — competes with title)
│   └── Secondary action (level 3)
├── Secondary section
│   ├── Section heading (level 2)
│   └── Content
└── Footer (level 4 — least important)
```

Most screens have **3-4 levels** of hierarchy. Fewer and the screen feels flat (everything equal); more and the eye doesn't know what's important.

## When to break uniformity

Lists of items are the most common place hierarchy breaks down. A list of 50 invoices: every row looks the same — by design. But the row the user actually wants is one of those 50.

Solutions:

- **Hover/focus states** (one row at a time gets prominence)
- **Filter/sort** (let the user reduce the list to the relevant subset)
- **Highlighting** (rows matching certain criteria get a tint, badge, or accent)
- **Pagination/virtualization** (don't show 50 — show 10)

Treating list-of-equal-things as a hierarchy problem itself is the move. The user's task isn't "scan all 50" — it's "find the one I need".

## The reverse pyramid

For content (articles, dashboards, modals), arrange importance top-to-bottom:

1. **Headline / what this is**
2. **Most important info / takeaway**
3. **Supporting details**
4. **Tertiary data**

If a user reads only the first 20% of a screen, they should still come away with the key information. This is the journalistic "inverted pyramid" applied to UI.

Don't bury the lede. The success/failure of a transaction is more important than its receipt number — the message reads "Payment successful" not "Reference: ABC123 — payment status: success".

## Visual weight on a screen

Imagine the screen reduced to grayscale and blurred. The dark / dense areas are where attention goes. Distribute these deliberately:

- One **primary anchor** per screen (hero, page title, primary action)
- 2-3 **secondary anchors** (section heads, secondary CTAs, key data points)
- The rest as **supporting content** (body, metadata)

Multiple equal-weight anchors fighting for attention = no anchor.

## The minus sign

A counterintuitive lever: **making other things less important** is often easier than making one thing more important.

Want the primary CTA to stand out? Don't make it bigger / bolder / brighter. Make the secondary actions smaller, lighter, and less colored. The CTA stands out by contrast.

Want a key metric to draw the eye on a dashboard? Don't use a flashy color. Make the surrounding metrics subtle, gray, low-contrast. The key metric is the only thing alive.

This applies broadly. Restraint creates hierarchy.

## Hierarchy through contrast, not density

A common failure: trying to convey hierarchy by adding *more* (bigger, bolder, more colorful, more decorations). The result is louder but less clear.

Hierarchy comes from **difference**, not magnitude. The contrast between a 32px bold heading and 14px regular body is what creates the hierarchy — making both 16px (body 14, heading 16) muddies it. The contrast between black and gray (text-primary vs text-secondary) creates hierarchy — making everything black removes it.

Make the most important thing one notch more prominent. Make the rest one notch less. The gap is the hierarchy.

## Common mistakes

- **Everything is bold**: nothing reads as emphasized
- **All headings same size**: structure invisible
- **Multiple primary CTAs on one screen**: user doesn't know what to do
- **Brand color on every interactive element**: links, buttons, badges, accents all look equally important
- **Too many hierarchy levels** (6+): brain can't construct the tree
- **Too few levels** (1-2): screen feels flat and undirected
- **Fighting hierarchy with decoration**: ornaments on a gray button to make it "stand out" — make it less gray instead

## Quick checklist

For any screen:

- [ ] One thing is most important; obvious within 2 seconds
- [ ] 3-4 levels of hierarchy total
- [ ] Headings show clear size hierarchy
- [ ] Primary CTA is the most prominent action; secondary actions are visibly secondary
- [ ] Body text is the largest mass of text but not the most prominent
- [ ] Removing/dimming things tested as a way to elevate priorities
