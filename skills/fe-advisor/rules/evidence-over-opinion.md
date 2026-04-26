# Rule — Evidence Over Opinion

Every claim in the advice cites concrete evidence: a file path, a line number, a commit, a grep result, a count. Opinions without evidence dilute the value of the consultation.

## The contrast

**Opinion** (low value):
```
- The auth code is messy and would be hard to refactor
- Forms in this app use a lot of state
- Adding a new component is probably easy
```

**Evidence** (high value):
```
- Auth state is split across 4 files (lib/auth/session.ts, lib/auth/state.ts,
  lib/auth/cookies.ts, lib/auth/refresh.ts) with overlapping responsibilities;
  unifying them would touch 23 callers (grep: `from '@/lib/auth'`)
- Form state uses react-hook-form's useFormContext in 12 of 14 form
  components; the 2 outliers (CheckoutForm, SignupForm) use local useState —
  pattern inconsistency that complicates a generic form refactor
- New components in /components/ui/ follow a consistent pattern
  (4 examples: Button, Card, Modal, Tooltip); copying that pattern adds
  ~5 files (component, story, test, types, index export)
```

The evidence answers "how do you know?" before arch-shape has to ask.

## How to gather evidence

Before writing each section, run searches:

```bash
# Find all files implementing/using a concept
git grep -l "useAuth" apps/

# Count usages
git grep -c "from '@/lib/api'" apps/ | wc -l

# Recent changes to an area
git log --oneline -20 -- apps/auth/

# Files in an area
find apps/auth -type f \( -name "*.tsx" -o -name "*.ts" \) | head -30

# Specific anchor for a claim
grep -n "interface Session" lib/auth/session.ts
```

The investigation is most of the work. The writeup is summary.

## Citation conventions

In the advice, anchor evidence with one of:

- **file:line** — `lib/auth/session.ts:14`
- **path** alone — when referring to an area, not a specific line
- **grep: pattern** — when reporting counts: `grep: 23 matches`
- **commit / PR** — `(PR #145)` or `(commit a1b2c3d)`
- **arch-ddd reference** — `(arch-ddd/bounded-contexts/auth.md)`

Make it easy for arch-shape (or another reader) to verify.

## When evidence is unavailable

Sometimes you can't gather evidence in 2 hours — codebase is unfamiliar, a relevant area is undocumented, etc. Two options:

### Option 1: Acknowledge limit explicitly

```
### Existing constraints

- Auth: ~~confident report~~ session module at lib/auth/session.ts; have
  not traced all consumers in this consultation
- Forms: pattern consistent across what I sampled (~5 components); did
  not exhaustively grep
- Backend integration: I can describe FE side; backend specifics are
  be-advisor's territory
```

Better than fake confidence.

### Option 2: Defer with a follow-up

Post the response with what you know; suggest arch-shape open a follow-up consultation if a specific area needs deeper analysis:

```
### Suggested approach

- Approach A: extend existing useSession() — fits current pattern
- Approach B: introduce new usePermissions() hook — would require
  follow-up consultation on cache invalidation strategy

### Conflicts with request

- Request implies real-time permission updates. I can describe FE-side
  state but cache invalidation is a cross-cutting concern. Recommend a
  follow-up consultation specifically on session/permission cache
  strategy if this approach is selected.
```

Don't pretend to know. Don't withhold what you do know.

## When code "should be" vs "is"

Beware of the temptation to describe what the codebase ought to look like. Evidence is about what IS:

```
WRONG:
- Auth state should be unified in lib/auth/index.ts

RIGHT:
- Auth state is currently in 4 files (lib/auth/{session,state,cookies,refresh}.ts)
  — could be unified, would touch ~23 callers if attempted
```

The wrong version is opinion presented as constraint. The right version is fact + an aside about feasibility.

## Counts vs estimates

When possible, count:

- "~40 files" — estimate; sometimes ok
- "23 files" (grep verified) — better
- "uses Tailwind extensively" — opinion
- "Tailwind is configured at tailwind.config.ts; 100% of components in /apps/web use Tailwind classes (sampled 50, all used Tailwind)" — measured

The exact granularity depends on the question. A scope estimate doesn't need exactness; a constraint claim usually does.

## Anti-patterns

- **"It would be hard"** without explaining why
- **"This is technical debt"** without naming the debt
- **"Easy to add"** without counting files or noting pattern reuse
- **Citing memory instead of `git grep`** — the codebase you remember and the codebase that exists may differ
- **Reporting only what supports the conclusion you reached** — confirmation bias; the synthesis depends on full picture
- **Framing your opinion as the codebase's** — "the code wants to be refactored" is opinion; "the code has X structural pattern that could support refactor Y" is evidence

## Why this matters most for advisors

For implementer roles (fe, be), opinion shows up in code — review catches it. For advisor roles, opinion shows up in the advice that arch-shape uses to make decisions. Bad advice → bad decomposition → wasted implementation rounds. The error compounds.

The rule isn't "be exhaustive". It's "every assertion should be one a reader can verify in 30 seconds with a grep". If that's possible, evidence is honest. If it's not, the assertion may not be sound.

## Quick checklist

Before posting:

- [ ] Every "Existing constraints" bullet has a file path or grep reference
- [ ] "Suggested approach" cites which existing pattern it extends
- [ ] "Conflicts with request" gives specific rather than vague reasons
- [ ] "Estimated scope" includes a file count or component count
- [ ] "Risks" describes the failure mode, not just "risky"
- [ ] "Drift noticed" includes both the arch-ddd reference and the codebase reality
