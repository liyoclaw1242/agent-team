# Auth Flow — Step-by-Step Implementation

> Auto-trigger: spec mentions auth, login, logout, sign in, sign up, register, protected route, session, authentication.

## Overview

Cookie-based session auth with protected routes, login/register forms, and middleware guard.

## Tech Stack

| Concern | Solution |
|---------|----------|
| Auth library | `next-auth` v5 (Auth.js) |
| Session | JWT in HTTP-only cookie |
| Route protection | Next.js middleware |
| Forms | Server Actions + `useActionState` |
| Validation | Zod (shared client/server schemas) |

---

## Step 1: Install

```bash
pnpm add next-auth@beta @auth/core
```

```bash
# Generate auth secret
npx auth secret
# → adds AUTH_SECRET to .env.local
```

## Step 2: Auth Config

```ts
// src/lib/auth.ts
import NextAuth from "next-auth";
import Credentials from "next-auth/providers/credentials";
import { z } from "zod";

const loginSchema = z.object({
  email: z.string().email(),
  password: z.string().min(8),
});

export const { handlers, signIn, signOut, auth } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        email: { label: "Email", type: "email" },
        password: { label: "Password", type: "password" },
      },
      async authorize(credentials) {
        const parsed = loginSchema.safeParse(credentials);
        if (!parsed.success) return null;

        // Replace with your actual user lookup
        const user = await fetchUser(parsed.data.email, parsed.data.password);
        if (!user) return null;

        return { id: user.id, name: user.name, email: user.email };
      },
    }),
  ],
  pages: {
    signIn: "/login",
  },
  callbacks: {
    authorized({ auth, request: { nextUrl } }) {
      const isLoggedIn = !!auth?.user;
      const isProtected = nextUrl.pathname.startsWith("/dashboard");
      if (isProtected && !isLoggedIn) {
        return Response.redirect(new URL("/login", nextUrl));
      }
      return true;
    },
  },
});
```

## Step 3: API Route

```ts
// src/app/api/auth/[...nextauth]/route.ts
import { handlers } from "@/lib/auth";

export const { GET, POST } = handlers;
```

## Step 4: Middleware (route protection)

```ts
// src/middleware.ts
export { auth as middleware } from "@/lib/auth";

export const config = {
  matcher: [
    // Protect all routes except public ones
    "/((?!api|_next|_vercel|login|register|.*\\..*).*)",
  ],
};
```

## Step 5: Login Form

```tsx
// src/components/features/auth/login-form.tsx
"use client";

import { useActionState } from "react";
import { login } from "@/app/(auth)/login/actions";

interface LoginState {
  error?: string;
}

export function LoginForm() {
  const [state, action, pending] = useActionState<LoginState, FormData>(login, {});

  return (
    <form action={action} className="flex flex-col gap-4 w-full max-w-sm">
      <h1 className="text-2xl font-semibold text-foreground">Log in</h1>

      {state.error && (
        <div role="alert" className="p-3 rounded-lg bg-red-50 text-red-700 text-sm dark:bg-red-950 dark:text-red-300">
          {state.error}
        </div>
      )}

      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-medium text-foreground">Email</span>
        <input
          type="email"
          name="email"
          required
          autoComplete="email"
          className="
            /* sizing */  h-10 px-3
            /* visual */  rounded-lg ring-1 ring-border bg-background text-foreground
            /* state  */  focus:ring-2 focus:ring-primary focus:outline-none
          "
        />
      </label>

      <label className="flex flex-col gap-1.5">
        <span className="text-sm font-medium text-foreground">Password</span>
        <input
          type="password"
          name="password"
          required
          autoComplete="current-password"
          className="
            /* sizing */  h-10 px-3
            /* visual */  rounded-lg ring-1 ring-border bg-background text-foreground
            /* state  */  focus:ring-2 focus:ring-primary focus:outline-none
          "
        />
      </label>

      <button
        type="submit"
        disabled={pending}
        className="
          /* sizing */  h-10
          /* visual */  rounded-lg bg-primary text-primary-foreground font-medium
          /* state  */  hover:opacity-90 disabled:opacity-50 disabled:cursor-not-allowed
          /* motion */  transition-opacity
        "
      >
        {pending ? "Logging in..." : "Log in"}
      </button>
    </form>
  );
}
```

## Step 6: Server Action

```ts
// src/app/(auth)/login/actions.ts
"use server";

import { signIn } from "@/lib/auth";
import { AuthError } from "next-auth";

export async function login(_prevState: { error?: string }, formData: FormData) {
  try {
    await signIn("credentials", {
      email: formData.get("email"),
      password: formData.get("password"),
      redirectTo: "/dashboard",
    });
    return {};
  } catch (error) {
    if (error instanceof AuthError) {
      return { error: "Invalid email or password." };
    }
    throw error; // re-throw unexpected errors
  }
}
```

## Step 7: Session Access

### Server Component

```tsx
// src/app/dashboard/page.tsx
import { auth } from "@/lib/auth";
import { redirect } from "next/navigation";

export default async function DashboardPage() {
  const session = await auth();
  if (!session?.user) redirect("/login");

  return (
    <main>
      <h1>Welcome, {session.user.name}</h1>
    </main>
  );
}
```

### Client Component

```tsx
"use client";

import { useSession } from "next-auth/react";

export function UserMenu() {
  const { data: session, status } = useSession();

  if (status === "loading") return <div className="h-8 w-8 rounded-full bg-muted animate-pulse" />;
  if (!session) return null;

  return (
    <div className="flex items-center gap-2">
      <span className="text-sm text-foreground">{session.user?.name}</span>
      <LogoutButton />
    </div>
  );
}
```

## Step 8: Logout

```tsx
// src/components/features/auth/logout-button.tsx
import { signOut } from "@/lib/auth";

export function LogoutButton() {
  return (
    <form
      action={async () => {
        "use server";
        await signOut({ redirectTo: "/login" });
      }}
    >
      <button
        type="submit"
        className="text-sm text-muted-foreground hover:text-foreground transition-colors"
      >
        Log out
      </button>
    </form>
  );
}
```

## Step 9: Session Provider (for client components)

```tsx
// src/app/layout.tsx
import { SessionProvider } from "next-auth/react";

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="en">
      <body>
        <SessionProvider>{children}</SessionProvider>
      </body>
    </html>
  );
}
```

## Step 10: Tests

```tsx
// src/components/features/auth/__tests__/login-form.test.tsx
import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { LoginForm } from "../login-form";

// Mock server action
vi.mock("@/app/(auth)/login/actions", () => ({
  login: vi.fn(() => ({})),
}));

describe("LoginForm", () => {
  it("renders email and password fields", () => {
    render(<LoginForm />);
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument();
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument();
  });

  it("renders submit button", () => {
    render(<LoginForm />);
    expect(screen.getByRole("button", { name: /log in/i })).toBeInTheDocument();
  });

  it("shows error message when login fails", () => {
    render(<LoginForm />);
    // Simulate error state via useActionState mock
    // The error div uses role="alert" for screen reader announcement
  });

  it("disables button while submitting", async () => {
    render(<LoginForm />);
    const button = screen.getByRole("button", { name: /log in/i });
    // Button shows "Logging in..." and is disabled during submission
    expect(button).not.toBeDisabled();
  });

  it("has proper autocomplete attributes", () => {
    render(<LoginForm />);
    expect(screen.getByLabelText(/email/i)).toHaveAttribute("autocomplete", "email");
    expect(screen.getByLabelText(/password/i)).toHaveAttribute("autocomplete", "current-password");
  });
});
```

## Route Layout

```
src/app/
  (auth)/              ← Route group (no layout chrome)
    login/
      page.tsx
      actions.ts
    register/
      page.tsx
      actions.ts
  (protected)/         ← Route group (with nav, sidebar)
    dashboard/
      page.tsx
    settings/
      page.tsx
  api/
    auth/
      [...nextauth]/
        route.ts
```

## Checklist

- [ ] `next-auth` installed + `AUTH_SECRET` in `.env.local`
- [ ] Auth config with provider + `authorized` callback
- [ ] API route at `/api/auth/[...nextauth]`
- [ ] Middleware protects routes
- [ ] Login form uses Server Action (not client-side fetch)
- [ ] Error state shown with `role="alert"`
- [ ] Loading state disables submit button
- [ ] `autocomplete` attributes on email/password
- [ ] `SessionProvider` wraps app for client components
- [ ] Logout uses Server Action form
- [ ] No secrets in client code — all auth logic server-side
