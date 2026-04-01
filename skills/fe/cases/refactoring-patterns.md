# Case: Standard Refactoring Patterns

Standardized refactoring moves for maintaining visual/logic separation during fast iteration. Each pattern is mechanical — follow the steps, don't improvise.

---

## 1. Extract Hook — Logic from Component

**Signal**: Component has `useState` + `useEffect` + data transformation.

```tsx
// BEFORE
function UserList() {
  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState("");
  useEffect(() => { fetchUsers().then(setUsers); }, []);
  const filtered = users.filter(u => u.name.includes(search));
  return (/* JSX using filtered */);
}

// AFTER
function useUserList() {
  const [users, setUsers] = useState<User[]>([]);
  const [search, setSearch] = useState("");
  useEffect(() => { fetchUsers().then(setUsers); }, []);
  const filtered = useMemo(() => users.filter(u => u.name.includes(search)), [users, search]);
  return { filtered, search, setSearch, isLoading: users.length === 0 };
}

function UserList() {
  const { filtered, search, setSearch, isLoading } = useUserList();
  if (isLoading) return <UserListSkeleton />;
  return (/* pure JSX, no logic */);
}
```

**Steps**:
1. Identify all state + effects + derived data
2. Move to `useXxx()` hook
3. Return `{ data, actions, flags }`
4. Component becomes pure render

---

## 2. Extract Component — Visual from Parent

**Signal**: JSX block inside `.map()` or conditional that's > 20 lines.

```tsx
// BEFORE
function Dashboard() {
  return (
    <div>
      {projects.map(p => (
        <div className="p-4 rounded-lg ring-1 ring-border">
          <h3>{p.name}</h3>
          <p>{p.description}</p>
          <div className="flex gap-2">
            {p.tags.map(t => <span className="badge">{t}</span>)}
          </div>
          <button onClick={() => archive(p.id)}>Archive</button>
        </div>
      ))}
    </div>
  );
}

// AFTER
function ProjectCard({ project, onArchive }: { project: Project; onArchive: (id: string) => void }) {
  return (
    <div className="p-4 rounded-lg ring-1 ring-border">
      <h3>{project.name}</h3>
      <p>{project.description}</p>
      <TagList tags={project.tags} />
      <button onClick={() => onArchive(project.id)}>Archive</button>
    </div>
  );
}

function Dashboard() {
  return (
    <div>
      {projects.map(p => <ProjectCard key={p.id} project={p} onArchive={archive} />)}
    </div>
  );
}
```

**Steps**:
1. Identify the repeated/complex JSX block
2. Determine its props interface (data in, actions out)
3. Extract to named component
4. Parent passes data + callbacks

---

## 3. Lift State — Shared State Up

**Signal**: Two sibling components need the same data, or one component controls another.

```tsx
// BEFORE: duplicated fetch
function Sidebar() {
  const { data: user } = useSWR("/api/me"); // fetch #1
  return <nav>{user?.name}</nav>;
}
function Header() {
  const { data: user } = useSWR("/api/me"); // fetch #2 (deduped by SWR, but still wrong pattern)
  return <header>{user?.avatar}</header>;
}

// AFTER: lifted to layout
function AppLayout({ children }) {
  const { data: user, isLoading } = useSWR("/api/me"); // single source
  if (isLoading) return <AppSkeleton />;
  return (
    <>
      <Header user={user} />
      <Sidebar user={user} />
      <main>{children}</main>
    </>
  );
}
```

**Steps**:
1. Find the lowest common ancestor
2. Move state/fetch there
3. Pass down via props (or context if deeply nested)

---

## 4. Replace Conditional Render — Strategy Pattern

**Signal**: Component has `if/else` or `switch` on a type to render different UIs.

```tsx
// BEFORE: growing switch
function NotificationItem({ notification }) {
  switch (notification.type) {
    case "message": return <div><MessageIcon />{notification.text}</div>;
    case "alert": return <div><AlertIcon />{notification.text}</div>;
    case "update": return <div><UpdateIcon />{notification.text}</div>;
    // ... grows endlessly
  }
}

// AFTER: registry (factory pattern)
const notificationRenderers: Record<string, FC<{ notification: Notification }>> = {
  message: MessageNotification,
  alert: AlertNotification,
  update: UpdateNotification,
};

function NotificationItem({ notification }) {
  const Renderer = notificationRenderers[notification.type] ?? DefaultNotification;
  return <Renderer notification={notification} />;
}
```

**Steps**:
1. Identify the switch/conditional on type
2. Create a component for each case
3. Build a registry (Record<type, Component>)
4. Parent looks up and renders

---

## 5. Colocation — Move Files Together

**Signal**: A component, its test, its hook, and its types are scattered across different directories.

```
// BEFORE: scattered
src/components/UserProfile.tsx
src/hooks/useUserProfile.ts
src/types/user-profile.ts
src/__tests__/UserProfile.test.tsx

// AFTER: colocated
src/components/features/user-profile/
  index.tsx           (component)
  user-profile.test.tsx
  use-user-profile.ts (hook)
  types.ts
```

**When to colocate**: When files always change together.
**When NOT to**: When the hook/type is shared across multiple components.
