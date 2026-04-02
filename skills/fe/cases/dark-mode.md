# Dark Mode — Step-by-Step Implementation

> Auto-trigger: spec mentions dark mode, theme toggle, theme switch, light/dark, color scheme.

## Overview

System-aware dark mode with manual toggle, persisted preference, no flash on load.

## Tech Stack

| Concern | Solution |
|---------|----------|
| CSS | Tailwind `dark:` variant (class strategy) |
| Persistence | `localStorage` + `system` default |
| SSR flash prevention | Inline `<script>` in `<head>` |
| State | React context + hook |

---

## Step 1: Tailwind Config

```ts
// tailwind.config.ts
import type { Config } from "tailwindcss";

const config: Config = {
  darkMode: "class", // not "media" — we need manual toggle
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        background: "hsl(var(--background))",
        foreground: "hsl(var(--foreground))",
        card: "hsl(var(--card))",
        "card-foreground": "hsl(var(--card-foreground))",
        border: "hsl(var(--border))",
        muted: "hsl(var(--muted))",
        "muted-foreground": "hsl(var(--muted-foreground))",
        primary: "hsl(var(--primary))",
        "primary-foreground": "hsl(var(--primary-foreground))",
      },
    },
  },
};

export default config;
```

## Step 2: CSS Variables

```css
/* src/app/globals.css */
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 0 0% 3.9%;
    --card: 0 0% 100%;
    --card-foreground: 0 0% 3.9%;
    --border: 0 0% 89.8%;
    --muted: 0 0% 96.1%;
    --muted-foreground: 0 0% 45.1%;
    --primary: 0 0% 9%;
    --primary-foreground: 0 0% 98%;
  }

  .dark {
    --background: 0 0% 3.9%;
    --foreground: 0 0% 98%;
    --card: 0 0% 3.9%;
    --card-foreground: 0 0% 98%;
    --border: 0 0% 14.9%;
    --muted: 0 0% 14.9%;
    --muted-foreground: 0 0% 63.9%;
    --primary: 0 0% 98%;
    --primary-foreground: 0 0% 9%;
  }
}
```

## Step 3: Flash Prevention Script

Add inline script in root layout `<head>` to apply theme before React hydrates:

```tsx
// src/app/layout.tsx
export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en" suppressHydrationWarning>
      <head>
        <script
          dangerouslySetInnerHTML={{
            __html: `
              (function() {
                var theme = localStorage.getItem('theme');
                if (theme === 'dark' || (!theme && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
                  document.documentElement.classList.add('dark');
                }
              })();
            `,
          }}
        />
      </head>
      <body className="bg-background text-foreground">
        <ThemeProvider>{children}</ThemeProvider>
      </body>
    </html>
  );
}
```

## Step 4: Theme Context + Hook

```tsx
// src/hooks/use-theme.tsx
"use client";

import { createContext, useContext, useEffect, useState } from "react";

type Theme = "light" | "dark" | "system";

interface ThemeContextValue {
  theme: Theme;
  resolvedTheme: "light" | "dark";
  setTheme: (theme: Theme) => void;
}

const ThemeContext = createContext<ThemeContextValue | null>(null);

function getSystemTheme(): "light" | "dark" {
  if (typeof window === "undefined") return "light";
  return window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light";
}

function resolveTheme(theme: Theme): "light" | "dark" {
  return theme === "system" ? getSystemTheme() : theme;
}

export function ThemeProvider({ children }: { children: React.ReactNode }) {
  const [theme, setThemeState] = useState<Theme>("system");
  const [resolvedTheme, setResolvedTheme] = useState<"light" | "dark">("light");

  // Init from localStorage
  useEffect(() => {
    const stored = localStorage.getItem("theme") as Theme | null;
    const initial = stored ?? "system";
    setThemeState(initial);
    setResolvedTheme(resolveTheme(initial));
  }, []);

  // Apply to DOM + persist
  useEffect(() => {
    const resolved = resolveTheme(theme);
    setResolvedTheme(resolved);
    document.documentElement.classList.toggle("dark", resolved === "dark");
    localStorage.setItem("theme", theme);
  }, [theme]);

  // Listen for system preference changes
  useEffect(() => {
    if (theme !== "system") return;
    const mq = window.matchMedia("(prefers-color-scheme: dark)");
    const handler = () => setResolvedTheme(getSystemTheme());
    mq.addEventListener("change", handler);
    return () => mq.removeEventListener("change", handler);
  }, [theme]);

  return (
    <ThemeContext.Provider value={{ theme, resolvedTheme, setTheme: setThemeState }}>
      {children}
    </ThemeContext.Provider>
  );
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) throw new Error("useTheme must be used within ThemeProvider");
  return ctx;
}
```

## Step 5: Toggle Component

```tsx
// src/components/ui/theme-toggle.tsx
"use client";

import { useTheme } from "@/hooks/use-theme";

export function ThemeToggle() {
  const { theme, setTheme } = useTheme();

  return (
    <button
      type="button"
      onClick={() => setTheme(theme === "dark" ? "light" : "dark")}
      className="
        /* layout */  flex items-center justify-center
        /* sizing */  h-9 w-9
        /* visual */  rounded-lg ring-1 ring-border
        /* state  */  hover:bg-muted transition-colors
      "
      aria-label={`Switch to ${theme === "dark" ? "light" : "dark"} mode`}
    >
      {theme === "dark" ? (
        <SunIcon className="h-4 w-4" />
      ) : (
        <MoonIcon className="h-4 w-4" />
      )}
    </button>
  );
}
```

## Step 6: Tests

```tsx
// src/components/ui/__tests__/theme-toggle.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ThemeProvider } from "@/hooks/use-theme";
import { ThemeToggle } from "../theme-toggle";

function renderToggle() {
  return render(
    <ThemeProvider>
      <ThemeToggle />
    </ThemeProvider>
  );
}

describe("ThemeToggle", () => {
  beforeEach(() => localStorage.clear());

  it("renders with accessible label", () => {
    renderToggle();
    expect(screen.getByRole("button", { name: /switch to/i })).toBeInTheDocument();
  });

  it("toggles theme on click", async () => {
    renderToggle();
    const button = screen.getByRole("button");
    await userEvent.click(button);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  it("persists preference to localStorage", async () => {
    renderToggle();
    await userEvent.click(screen.getByRole("button"));
    expect(localStorage.getItem("theme")).toBe("dark");
  });
});
```

## Checklist

- [ ] `tailwind.config.ts` uses `darkMode: "class"`
- [ ] CSS variables defined for both `:root` and `.dark`
- [ ] Inline `<script>` in `<head>` prevents flash
- [ ] `ThemeProvider` wraps app in root layout
- [ ] Toggle has `aria-label`
- [ ] System preference fallback works
- [ ] Preference persists across reload
- [ ] No hardcoded colors — all use semantic tokens
