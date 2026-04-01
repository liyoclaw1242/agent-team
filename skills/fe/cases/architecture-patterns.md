# Case: Frontend Architecture Patterns

Reference implementations for common architectural decisions.

---

## 1. Factory Pattern — Component Registry

When you need to render different components based on a type/config:

```tsx
// components/widgets/registry.ts
import { ChartWidget } from "./chart-widget";
import { TableWidget } from "./table-widget";
import { MetricWidget } from "./metric-widget";

const widgetRegistry = {
  chart: ChartWidget,
  table: TableWidget,
  metric: MetricWidget,
} as const;

type WidgetType = keyof typeof widgetRegistry;

export function createWidget(type: WidgetType, props: any) {
  const Component = widgetRegistry[type];
  if (!Component) throw new Error(`Unknown widget type: ${type}`);
  return <Component {...props} />;
}

// Usage in page
function Dashboard({ config }: { config: WidgetConfig[] }) {
  return (
    <div className="grid grid-cols-2 gap-4">
      {config.map(w => (
        <div key={w.id}>{createWidget(w.type, w.props)}</div>
      ))}
    </div>
  );
}
```

**When to use**: Dynamic component rendering, plugin systems, configurable dashboards.

---

## 2. Dependency Injection — Context Provider Pattern

When services/dependencies need to be swappable (testing, multi-tenant):

```tsx
// lib/api-context.tsx
interface ApiClient {
  fetchUsers(): Promise<User[]>;
  createUser(data: CreateUserInput): Promise<User>;
}

const ApiContext = createContext<ApiClient | null>(null);

export function ApiProvider({ client, children }: { client: ApiClient; children: ReactNode }) {
  return <ApiContext.Provider value={client}>{children}</ApiContext.Provider>;
}

export function useApi(): ApiClient {
  const api = useContext(ApiContext);
  if (!api) throw new Error("useApi must be used within ApiProvider");
  return api;
}

// Production
<ApiProvider client={new HttpApiClient("https://api.example.com")}>
  <App />
</ApiProvider>

// Test
<ApiProvider client={new MockApiClient()}>
  <UserList />
</ApiProvider>
```

**When to use**: Testing with mocks, multi-environment configs, swappable backends.

---

## 3. Proxy Pattern — API Layer Abstraction

When you need to intercept, transform, or cache API calls:

```tsx
// lib/api/client.ts
class ApiClient {
  private baseUrl: string;
  private token: string | null = null;

  constructor(baseUrl: string) {
    this.baseUrl = baseUrl;
  }

  setToken(token: string) { this.token = token; }

  private async request<T>(path: string, options?: RequestInit): Promise<T> {
    const headers: Record<string, string> = {
      "Content-Type": "application/json",
      ...(this.token ? { Authorization: `Bearer ${this.token}` } : {}),
    };

    const res = await fetch(`${this.baseUrl}${path}`, { ...options, headers });

    if (res.status === 401) {
      // Auto-redirect to login
      window.location.href = "/login";
      throw new Error("Unauthorized");
    }

    if (!res.ok) {
      const body = await res.json().catch(() => ({}));
      throw new ApiError(res.status, body.error ?? "unknown", body.message);
    }

    return res.json();
  }

  // Typed endpoints
  users = {
    list: () => this.request<User[]>("/users"),
    get: (id: string) => this.request<User>(`/users/${id}`),
    create: (data: CreateUserInput) => this.request<User>("/users", {
      method: "POST", body: JSON.stringify(data),
    }),
  };
}

export const api = new ApiClient(process.env.NEXT_PUBLIC_API_URL!);
```

**When to use**: Centralized auth, error handling, request/response transforms.

---

## 4. Adapter Pattern — Data Source Abstraction

When components shouldn't know where data comes from:

```tsx
// adapters/user-adapter.ts
interface UserDataSource {
  getUsers(): Promise<User[]>;
  getUser(id: string): Promise<User>;
}

// REST adapter
class RestUserAdapter implements UserDataSource {
  async getUsers() { return api.users.list(); }
  async getUser(id: string) { return api.users.get(id); }
}

// GraphQL adapter
class GraphQLUserAdapter implements UserDataSource {
  async getUsers() {
    const { data } = await client.query({ query: GET_USERS });
    return data.users;
  }
  async getUser(id: string) { ... }
}

// Mock adapter (for Storybook / tests)
class MockUserAdapter implements UserDataSource {
  async getUsers() { return mockUsers; }
  async getUser(id: string) { return mockUsers.find(u => u.id === id)!; }
}

// Hook uses adapter, doesn't know the source
function useUsers(adapter: UserDataSource) {
  return useSWR("users", () => adapter.getUsers());
}
```

**When to use**: Backend migration (REST → GraphQL), Storybook isolation, offline mode.

---

## 5. Middleware Pattern — Route Guards & Interceptors

Next.js middleware for cross-cutting concerns:

```tsx
// middleware.ts
import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";

export function middleware(request: NextRequest) {
  const token = request.cookies.get("token")?.value;
  const isAuthPage = request.nextUrl.pathname.startsWith("/login");
  const isPublicApi = request.nextUrl.pathname.startsWith("/api/public");

  // Auth guard
  if (!token && !isAuthPage && !isPublicApi) {
    return NextResponse.redirect(new URL("/login", request.url));
  }

  // Locale detection
  const locale = request.headers.get("accept-language")?.split(",")[0]?.split("-")[0] ?? "en";
  const response = NextResponse.next();
  response.headers.set("x-locale", locale);

  return response;
}

export const config = {
  matcher: ["/((?!_next/static|_next/image|favicon.ico).*)"],
};
```

**When to use**: Auth, i18n, A/B testing, feature flags, rate limiting.

---

## 6. Observer Pattern — Event Bus for Decoupled Components

When sibling components need to communicate without prop drilling:

```tsx
// lib/event-bus.ts
type Handler<T = any> = (payload: T) => void;

class EventBus {
  private handlers = new Map<string, Set<Handler>>();

  on<T>(event: string, handler: Handler<T>) {
    if (!this.handlers.has(event)) this.handlers.set(event, new Set());
    this.handlers.get(event)!.add(handler);
    return () => this.handlers.get(event)?.delete(handler);
  }

  emit<T>(event: string, payload: T) {
    this.handlers.get(event)?.forEach(h => h(payload));
  }
}

export const bus = new EventBus();

// Hook for React integration
function useEvent<T>(event: string, handler: Handler<T>) {
  useEffect(() => bus.on(event, handler), [event, handler]);
}

// Component A emits
bus.emit("cart:updated", { itemCount: 3 });

// Component B listens
useEvent("cart:updated", ({ itemCount }) => setBadge(itemCount));
```

**When to use**: Cross-feature notifications, toast system, analytics events.
