# i18n Routing — Step-by-Step Implementation

> Auto-trigger: spec mentions i18n, internationalization, multi-language, locale, translation, 多語系.

## Overview

Locale-prefixed routing with `next-intl`, static message files, and language switcher.

## Tech Stack

| Concern | Solution |
|---------|----------|
| i18n library | `next-intl` (App Router native) |
| Message format | JSON files per locale |
| Routing | `/[locale]/...` prefix |
| Detection | Accept-Language header + cookie |
| Switcher | Dropdown with locale change |

---

## Step 1: Install

```bash
pnpm add next-intl
```

## Step 2: Message Files

```
messages/
  en.json
  zh-TW.json
  ja.json
```

```json
// messages/en.json
{
  "common": {
    "appName": "My App",
    "loading": "Loading...",
    "error": "Something went wrong",
    "retry": "Try again"
  },
  "nav": {
    "home": "Home",
    "about": "About",
    "settings": "Settings"
  },
  "auth": {
    "login": "Log in",
    "logout": "Log out",
    "email": "Email",
    "password": "Password"
  }
}
```

```json
// messages/zh-TW.json
{
  "common": {
    "appName": "我的應用",
    "loading": "載入中...",
    "error": "發生錯誤",
    "retry": "重試"
  },
  "nav": {
    "home": "首頁",
    "about": "關於",
    "settings": "設定"
  },
  "auth": {
    "login": "登入",
    "logout": "登出",
    "email": "電子郵件",
    "password": "密碼"
  }
}
```

### Message Key Convention

- Namespace by feature: `auth.login`, `nav.home`, `dashboard.title`
- Use flat keys within namespace, no deep nesting beyond 2 levels
- Keep keys in English, values in target language

## Step 3: i18n Config

```ts
// src/i18n/config.ts
export const locales = ["en", "zh-TW", "ja"] as const;
export type Locale = (typeof locales)[number];
export const defaultLocale: Locale = "en";
```

```ts
// src/i18n/request.ts
import { getRequestConfig } from "next-intl/server";
import { locales, defaultLocale } from "./config";

export default getRequestConfig(async ({ requestLocale }) => {
  let locale = await requestLocale;
  if (!locale || !locales.includes(locale as any)) {
    locale = defaultLocale;
  }

  return {
    locale,
    messages: (await import(`../../messages/${locale}.json`)).default,
  };
});
```

## Step 4: Middleware (locale detection + redirect)

```ts
// src/middleware.ts
import createMiddleware from "next-intl/middleware";
import { locales, defaultLocale } from "./i18n/config";

export default createMiddleware({
  locales,
  defaultLocale,
  localeDetection: true, // uses Accept-Language header
  localePrefix: "as-needed", // hide prefix for default locale
});

export const config = {
  matcher: [
    // Match all paths except static files and API routes
    "/((?!api|_next|_vercel|.*\\..*).*)",
  ],
};
```

## Step 5: Route Structure

```
src/app/
  [locale]/
    layout.tsx        ← Wraps with NextIntlClientProvider
    page.tsx
    about/
      page.tsx
    settings/
      page.tsx
```

```tsx
// src/app/[locale]/layout.tsx
import { NextIntlClientProvider } from "next-intl";
import { getMessages, setRequestLocale } from "next-intl/server";
import { locales } from "@/i18n/config";

export function generateStaticParams() {
  return locales.map((locale) => ({ locale }));
}

export default async function LocaleLayout({
  children,
  params,
}: {
  children: React.ReactNode;
  params: Promise<{ locale: string }>;
}) {
  const { locale } = await params;
  setRequestLocale(locale);
  const messages = await getMessages();

  return (
    <html lang={locale}>
      <body>
        <NextIntlClientProvider messages={messages}>
          {children}
        </NextIntlClientProvider>
      </body>
    </html>
  );
}
```

## Step 6: Using Translations

### Server Component

```tsx
// src/app/[locale]/page.tsx
import { useTranslations } from "next-intl";
import { setRequestLocale } from "next-intl/server";

export default function HomePage({ params }: { params: Promise<{ locale: string }> }) {
  const { locale } = await params;
  setRequestLocale(locale);
  const t = useTranslations("nav");

  return (
    <main>
      <h1>{t("home")}</h1>
    </main>
  );
}
```

### Client Component

```tsx
"use client";

import { useTranslations } from "next-intl";

export function NavMenu() {
  const t = useTranslations("nav");

  return (
    <nav>
      <a href="/">{t("home")}</a>
      <a href="/about">{t("about")}</a>
    </nav>
  );
}
```

## Step 7: Language Switcher

```tsx
// src/components/ui/locale-switcher.tsx
"use client";

import { useLocale } from "next-intl";
import { useRouter, usePathname } from "next-intl/client";
import { locales, type Locale } from "@/i18n/config";

const labels: Record<Locale, string> = {
  en: "English",
  "zh-TW": "繁體中文",
  ja: "日本語",
};

export function LocaleSwitcher() {
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();

  function handleChange(e: React.ChangeEvent<HTMLSelectElement>) {
    router.replace(pathname, { locale: e.target.value });
  }

  return (
    <select
      value={locale}
      onChange={handleChange}
      aria-label="Select language"
      className="
        /* sizing */  h-9 px-3
        /* visual */  rounded-lg ring-1 ring-border bg-background text-foreground
        /* state  */  hover:ring-foreground/20 focus:ring-2 focus:ring-primary
      "
    >
      {locales.map((loc) => (
        <option key={loc} value={loc}>
          {labels[loc]}
        </option>
      ))}
    </select>
  );
}
```

## Step 8: Tests

```tsx
// src/components/ui/__tests__/locale-switcher.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { NextIntlClientProvider } from "next-intl";
import { LocaleSwitcher } from "../locale-switcher";

const messages = { nav: { home: "Home" } };

function renderSwitcher(locale = "en") {
  return render(
    <NextIntlClientProvider locale={locale} messages={messages}>
      <LocaleSwitcher />
    </NextIntlClientProvider>
  );
}

describe("LocaleSwitcher", () => {
  it("renders with accessible label", () => {
    renderSwitcher();
    expect(screen.getByRole("combobox", { name: /select language/i })).toBeInTheDocument();
  });

  it("shows all locale options", () => {
    renderSwitcher();
    const options = screen.getAllByRole("option");
    expect(options).toHaveLength(3);
  });

  it("has current locale selected", () => {
    renderSwitcher("zh-TW");
    expect(screen.getByRole("combobox")).toHaveValue("zh-TW");
  });
});
```

## Checklist

- [ ] `next-intl` installed
- [ ] Message JSON files created per locale
- [ ] Middleware handles locale detection + redirect
- [ ] `[locale]` dynamic segment in app directory
- [ ] `NextIntlClientProvider` in locale layout
- [ ] `generateStaticParams` returns all locales
- [ ] Switcher has `aria-label`
- [ ] `localePrefix: "as-needed"` hides default locale from URL
- [ ] No hardcoded strings in components — all use `t()`
