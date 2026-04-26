# Rule — Scope Honesty

The S/M/L estimate is the most consequential part of the advice. arch-shape uses it to decide whether to decompose further or proceed. An estimate that's wrong by a factor of 3-5x leads to wrong decompositions and rework cycles.

## The S/M/L scale

- **S (Small)**: 1-3 files modified, 0-1 new components, no new dependencies. Implementable in a single PR comfortably.
- **M (Medium)**: 4-15 files modified, 2-5 new components, possibly 1 new dependency. Single PR but substantial; one round of feedback expected.
- **L (Large)**: 16+ files modified, 6+ new components, multiple new patterns. Single PR is borderline; may warrant decomposition into multiple sub-tasks.
- **L+ (Beyond Large)**: would touch 50+ files, introduce multiple new architectural patterns, or fundamentally change shipped UX. **Should be decomposed at the arch-shape level** before attempting implementation.

If the answer is L+, say so explicitly:

```
### Estimated scope
- L+ — request as written would touch ~80 files (every screen with auth gate)
  + introduce three new patterns (role-based hiding HOC, permission cache,
  permission UI). Strongly suggest decomposing into:
  1. Role-based hiding (the HOC + opt-in for screens) — M
  2. Permission cache layer — M
  3. Permission settings UI — M
  These can ship sequentially.
```

This kind of pushback is the consultation's most valuable possible output.

## How to estimate

The estimate is grep-driven, not vibe-driven:

### Step 1: Identify touched areas

What modules / surfaces does the request affect? Use the request to derive search terms:

```bash
# For "add real-time permission feedback":
git grep -l "useAuth\|useSession\|usePermission" apps/
git grep -l "onAuthChange\|onPermissionChange" apps/
```

### Step 2: Count modified files

For each existing file in the affected area, decide: would this need to change?

```bash
# Files in the affected area
find apps/auth -type f -name "*.tsx" | wc -l   # 23

# Files actually likely to change for this request
# (judgment call; estimate, then sanity-check)
```

If the request adds a new field to a context, every consumer (potentially) changes:

```bash
# 12 consumers of useSession; if they all need updating: 12
git grep -l "useSession" apps/ | wc -l
```

### Step 3: Count new files

New components, new utilities, new tests. Conservative estimate:

```
- 2 new components (PermissionPanel, PermissionRow)
- 1 new utility (permissions.ts)
- 3 new test files (one per new file)
= 6 new files
```

### Step 4: Sum and round up

```
Files modified: ~12 consumers + 4 auth lib files = 16
Files added: 6
Total: ~22 files → L
```

Round up if uncertain. An estimate that's slightly too high causes arch-shape to decompose; one that's slightly too low causes underspecified implementation.

## What "files" means

Count meaningful changes:

- A file with a one-character change (typo fix as part of the work) — half a file
- A file with a 100-line change — one file
- A file completely rewritten — one large file (counts as more than typical)

Don't game the count. The number's purpose is to give arch-shape a magnitude.

## When the request is vague

If the request says "add permissions UI" and you can't tell what that means:

```
### Estimated scope

- Cannot estimate without clarification. Range:
  - Minimal (a single permissions-list view): S, ~3 files
  - Full RBAC UI (matrix view + bulk operations + audit log): L+, ~40 files
  - Suggest arch-shape narrow the request before scope can be estimated
```

This is honest. Forcing an estimate on a vague spec produces wrong numbers and bad decompositions.

## Avoiding common biases

### Optimism bias

The "first cut" estimate skips:
- Tests for new code (~1x existing code)
- Migration code if data shape changes (~1-3 files)
- Documentation updates (~1-2 files)
- E2E test updates (~1-3 files)

Add 30-50% to your first cut for these. They almost always exist.

### Pessimism bias (less common)

Sometimes you list every conceivably-affected file. Filter to "likely to change", not "could possibly change". The estimate is for likely scope, not worst case.

### Familiarity bias

If you know the affected area well, you may underestimate (you forget how much you internally automated). If you don't know it well, you may overestimate (everything looks complex when unfamiliar).

For unfamiliar areas, run extra greps:

```bash
git log --oneline -20 -- {area}    # how active?
ls -la {area} | wc -l              # how many files?
git grep -l "import" {area} | head # are imports tangled?
```

## Calibration check

After a few consultations, check your estimates against actual implementation PRs. If you keep estimating M and the implementations are L, your S/M/L thresholds are off — recalibrate.

Note recalibration in your skill journal:

```
2026-04-26: estimated M for #220, actual was 18 files (L). Recalibrating
"medium" downward — anything 12+ files I'll mark L going forward unless
clearly bounded.
```

## Anti-patterns

- **"Should be straightforward"** — not an estimate
- **"A few files"** — what's a few?
- **Defaulting to M** for everything — laziness; the M label becomes meaningless
- **Estimating only files modified, ignoring files added** — a "1-file change" that adds a 500-line new utility is not S
- **Hand-waving over hard parts** — "the API call is a one-liner"; one-liners that span network boundaries usually have associated retry / error / loading / type changes
- **Conflating effort with file count** — a 1-file change that requires deep algorithmic thinking is harder than 30 mechanical changes; note both file count and complexity in Risks
- **Estimating someone else's part** — if BE is involved, your estimate is FE-only; say so

## Quick checklist

Before estimating:

- [ ] Used `git grep` to find consumers / affected areas
- [ ] Counted modifications + additions
- [ ] Considered tests, migrations, docs as part of scope
- [ ] Rounded up if uncertain
- [ ] Marked L+ explicitly if applicable
- [ ] Gave a range (with named scenarios) if the request is vague
