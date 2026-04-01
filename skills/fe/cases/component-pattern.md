# Case: Standard Component Pattern

## Good: Complete component with all states

```tsx
// src/components/features/user-card.tsx
interface UserCardProps {
  userId: string;
}

export function UserCard({ userId }: UserCardProps) {
  const { data: user, isLoading, error } = useUser(userId);

  if (isLoading) return <UserCardSkeleton />;
  if (error) return <ErrorState message="Failed to load user" onRetry={() => {}} />;
  if (!user) return <EmptyState message="User not found" />;

  return (
    <div className="
      /* layout */  flex items-center gap-4 p-4
      /* visual */  bg-card rounded-xl ring-1 ring-border
      /* state  */  hover:ring-border-hover transition-shadow
    ">
      <img
        src={user.avatar}
        alt={`${user.name}'s avatar`}
        className="size-10 rounded-full"
      />
      <div>
        <p className="text-sm font-medium text-foreground">{user.name}</p>
        <p className="text-xs text-muted-foreground">{user.email}</p>
      </div>
    </div>
  );
}

function UserCardSkeleton() {
  return (
    <div className="flex items-center gap-4 p-4 animate-pulse">
      <div className="size-10 rounded-full bg-muted" />
      <div className="space-y-2">
        <div className="h-3 w-24 rounded bg-muted" />
        <div className="h-3 w-32 rounded bg-muted" />
      </div>
    </div>
  );
}
```

## Good: Corresponding test

```tsx
// src/components/features/user-card.test.tsx
import { render, screen } from "@testing-library/react";
import { UserCard } from "./user-card";

describe("UserCard", () => {
  it("renders user info", () => {
    mockUser({ name: "Alice", email: "alice@example.com" });
    render(<UserCard userId="1" />);
    expect(screen.getByText("Alice")).toBeInTheDocument();
    expect(screen.getByRole("img", { name: /alice/i })).toBeInTheDocument();
  });

  it("shows skeleton while loading", () => {
    mockLoading();
    const { container } = render(<UserCard userId="1" />);
    expect(container.querySelector(".animate-pulse")).toBeInTheDocument();
  });

  it("shows error with retry", () => {
    mockError();
    render(<UserCard userId="1" />);
    expect(screen.getByText(/failed to load/i)).toBeInTheDocument();
  });
});
```

## Bad: Incomplete component

```tsx
// Missing loading, error, empty states
// Hardcoded colors instead of tokens
// No test file
export default function UserCard({ user }) {
  return (
    <div style={{ padding: 16, background: "#fff" }}>
      <img src={user.avatar} />
      <p>{user.name}</p>
    </div>
  );
}
```
