# Rule — Schema Compliance

The advice comment is mechanically validated. Format violations cause `actions/respond.sh` to refuse posting.

## The exact schema

```markdown
## Advice from fe-advisor

### Existing constraints
- {bullet}
- {bullet}

### Suggested approach
- {bullet}
- {bullet}

### Conflicts with request
- {bullet}
(or single line: "none")

### Estimated scope
- {S | M | L} — {file count} files, {component count} components touched

### Risks
- {bullet}

### Drift noticed
- {bullet}
(or single line: "none")
```

## What the validator checks

`validate/advice-format.sh`:

1. First non-empty line is exactly `## Advice from fe-advisor`
2. All six required `### ` sections present:
   - `### Existing constraints`
   - `### Suggested approach`
   - `### Conflicts with request`
   - `### Estimated scope`
   - `### Risks`
   - `### Drift noticed`
3. Each section has at least one non-empty line of content (a bullet or a single word like "none")
4. The estimated scope section contains exactly one of `S`, `M`, or `L`

The validator does not check semantic quality — that's arch-shape's job during synthesis.

## Why a strict schema

arch-shape's `cases/brainstorm-flow.md` Phase C extracts each section by name. If fe-advisor uses `### Approach` instead of `### Suggested approach`, the extraction silently drops it. The strict format is the contract.

The same schema applies for `be-advisor`, `ops-advisor`, and `design-advisor` — only the `## Advice from {role}` header changes. Cross-advisor synthesis depends on this consistency.

## Sections in detail

### Existing constraints

What in the current codebase shapes how the request can be satisfied. Always cite locations:

```
- Auth state lives in lib/auth/session.ts:14; consumed via useSession() hook
  in 23 components (grep: `useSession\(`)
- Forms use react-hook-form throughout; switching libraries would touch ~40
  components
- All API calls go through lib/api/client.ts; no direct fetch() usage in
  feature code (grep confirmed: 0 matches in apps/)
```

NOT:
- "We use React" (true but useless)
- "There are some forms" (no anchor)

### Suggested approach

Direction with rationale. Not pseudocode. Not "do X". A way to fit the request into existing patterns:

```
- Extend useSession() with a `permissions` field rather than introducing a
  separate usePermissions() hook — keeps auth state in one place; existing
  consumers can opt in
- New permission UI uses existing Modal pattern (lib/ui/Modal); fits the
  "settings" navigation area; no new top-level route needed
```

### Conflicts with request

Places the request would force a deviation. Be honest:

```
- Request says "instant feedback on permission change". Current architecture
  invalidates session on permission write, requiring user re-login. Either
  the spec accepts re-login UX, or we add a refresh-without-login path
  (~5 files of work)
- Request implies role-based UI hiding. Existing components don't take a
  role context; would need a HOC or context provider added at the app root.
```

If genuinely no conflicts:

```
- none
```

### Estimated scope

S/M/L based on actual codebase grep, not vibes:

- **S**: 1-3 files, 0-1 new components, no new dependencies
- **M**: 4-15 files, 2-5 new components, possibly 1 new dependency
- **L**: 16+ files, 6+ new components, multiple new patterns

```
- M — ~8 files: lib/auth/session.ts (modify), 4 form components (consume new
  field), 2 new permission UI components, 1 new test file
```

If it's an L+ situation (50+ files, multiple new patterns), say so:

```
- L+ — request would touch every screen with auth gate (~80 files); strongly
  suggest decomposing further before implementation
```

### Risks

Failure modes and deferred-debt costs:

```
- If permission cache TTL is too long, users see stale permissions after role
  change; if too short, every navigation hits the API
- Adding a HOC for role-based hiding creates a pattern others may copy;
  if we want to remove it later, we'll need a migration path
- The new permission UI's pattern doesn't match any existing settings UI;
  could create future inconsistency unless we standardize the settings shape
```

### Drift noticed

arch-ddd vs codebase reality:

```
- arch-ddd/bounded-contexts/auth.md says "session refresh is JWT-based";
  code uses both JWT (web) and opaque tokens (mobile API) — apps/mobile/auth.ts
  has different flow than documented
- arch-ddd has no mention of the permissions module added in PR #145;
  bounded-contexts/auth.md should reference it
```

Or:

```
- none
```

## Common violations

- **Wrong header level** — `# Advice from fe-advisor` instead of `## `
- **Missing section** — skipping "Drift noticed" because nothing seems wrong; even then, write `- none`
- **Empty section** — section header with no content lines
- **Wrong section names** — `### Approach` (not `Suggested approach`); `### Issues` (not `Conflicts with request`)
- **Scope without S/M/L** — "about 8 files" doesn't tell synthesis the rough magnitude
- **Bullets that aren't bullets** — paragraphs of prose under each section; the synthesis grep looks for content, but bullets are the convention
- **Adding extra sections** — your own bonus sections aren't read by arch-shape; they fit nowhere

## Quick checklist

Before running `respond.sh`:

- [ ] Header is exactly `## Advice from fe-advisor`
- [ ] All six required sections present with exact wording
- [ ] Every section has at least one bullet (or `- none` where applicable)
- [ ] Estimated scope contains S, M, or L
- [ ] No extra sections beyond the schema
- [ ] No code blocks larger than ~5 lines (advice is high-level, not implementation)
