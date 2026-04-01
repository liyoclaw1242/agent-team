# Case: Tailwind Patterns

## Namespace Grouping

Group classes by concern with comments:

```tsx
<button className="
  /* layout  */ inline-flex items-center justify-center gap-2
  /* sizing  */ h-9 px-4
  /* text    */ text-sm font-medium
  /* visual  */ bg-primary text-primary-foreground rounded-lg
  /* border  */ ring-1 ring-primary/20
  /* hover   */ hover:bg-primary/90
  /* focus   */ focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring
  /* active  */ active:scale-[0.98]
  /* motion  */ transition-all duration-150
">
```

## Ring Borders (not solid)

```tsx
// Good: subtle, composable
<div className="ring-1 ring-black/5 rounded-lg">

// Good: interactive ring
<div className="ring-1 ring-border hover:ring-border-hover focus-within:ring-2 focus-within:ring-primary">

// Avoid: flat solid border
<div className="border border-gray-200">
```

## Responsive Layout

```tsx
// Mobile-first: stack → row
<div className="flex flex-col gap-4 md:flex-row md:items-center md:gap-6">

// Grid: 1 col → 2 → 3
<div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
```

## Dark Mode

```tsx
// Use semantic tokens that auto-switch
<div className="bg-background text-foreground">

// Not raw color values
<div className="bg-white dark:bg-gray-900 text-gray-900 dark:text-white">
```
