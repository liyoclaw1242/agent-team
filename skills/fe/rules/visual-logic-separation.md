# Rule: Visual / Logic Separation

**Activation**: Always active. This is a core architectural discipline.

## Principle

Visual (how it looks) and logic (what it does) must live in separate layers. This prevents:
- UI changes from breaking business logic
- Logic changes from causing visual regressions
- Fast iteration from accumulating tech debt that blocks future iteration

## The Three Layers

```
┌─────────────────────────────────────────────┐
│  Page / Route                               │  ← orchestration only
│  Composes features, handles routing/layout   │
├─────────────────────────────────────────────┤
│  Logic Layer (hooks / stores / services)    │  ← pure data + behavior
│  useAuth(), useCart(), api.fetchUsers()      │
│  No JSX, no className, no DOM references    │
├─────────────────────────────────────────────┤
│  Visual Layer (components)                  │  ← pure presentation
│  Button, Card, UserProfile                  │
│  Receives data via props, emits via callbacks│
│  No fetch, no business rules                │
└─────────────────────────────────────────────┘
```

## Rules

1. **Components receive, don't fetch** — data comes in via props, actions go out via callbacks
2. **Hooks encapsulate logic** — `useUser(id)` returns `{ data, isLoading, error }`, not JSX
3. **No business rules in components** — "is admin?" check lives in a hook or util, not in the component
4. **No styling in hooks** — hooks return data, never classNames or style objects
5. **Page components are thin** — they compose logic hooks + visual components, nothing else

## Refactoring Signal

If you see any of these, separation is broken:

| Smell | Problem | Fix |
|-------|---------|-----|
| `fetch()` inside a component | Logic in visual layer | Extract to hook |
| `if (user.role === 'admin')` in JSX | Business rule in visual layer | Extract to `usePermissions()` |
| `className` in a hook return | Styling in logic layer | Return data, let component style |
| 200+ line component with both API calls and JSX | Mixed layers | Split into hook + component |
| Component imports `db` or `prisma` | Server logic leaking to client | Move to API route / server action |

## Standard Refactoring Pattern

When you encounter a mixed component:

```tsx
// BEFORE: mixed
function UserDashboard() {
  const [users, setUsers] = useState([]);
  useEffect(() => { fetch("/api/users").then(r => r.json()).then(setUsers); }, []);
  const admins = users.filter(u => u.role === "admin");
  return <div>{admins.map(u => <span style={{color: "red"}}>{u.name}</span>)}</div>;
}

// AFTER: separated
// 1. Logic hook
function useAdminUsers() {
  const { data: users, isLoading, error } = useSWR("/api/users", fetcher);
  const admins = useMemo(() => (users ?? []).filter(u => u.role === "admin"), [users]);
  return { admins, isLoading, error };
}

// 2. Visual component
function AdminList({ users }: { users: User[] }) {
  return (
    <ul className="space-y-2">
      {users.map(u => (
        <li key={u.id} className="text-sm text-destructive font-medium">{u.name}</li>
      ))}
    </ul>
  );
}

// 3. Page composition
function UserDashboard() {
  const { admins, isLoading, error } = useAdminUsers();
  if (isLoading) return <AdminListSkeleton />;
  if (error) return <ErrorState />;
  return <AdminList users={admins} />;
}
```
