# `_shared/` — Cross-skill shared layer

Files in this folder are **referenced by relative path** from skill SKILL.md files (e.g. `../_shared/rules/git.md`). They are the single source of truth for any rule, action, or knowledge that applies to more than one skill.

## What lives here

| Subfolder | Contents |
|-----------|----------|
| `rules/` | Validation rules and behavioural conventions referenced by multiple skills |
| `actions/` | Executable scripts referenced by multiple skills |
| `validate/` | Aggregator + helper libraries for `check-all.sh` plug-in model |
| `domain/` | Project-specific DDD artefacts (bounded contexts, glossary, service chain) — see `domain/README.md` |

## What does NOT live here

- **Workflow files** — each skill has its own workflow because workflows encode role-specific phase gates.
- **Cases** — distilled experience per role; by definition role-specific.
- **Role-specific rules** — e.g. `be/rules/api.md` covers HTTP/gRPC concerns specific to BE, doesn't belong here.

## Referencing rules

Skills reference shared files using **explicit relative paths**, not symlinks:

```markdown
| Rule | File |
|------|------|
| Git Hygiene | `../_shared/rules/git.md` |
| Code Quality | `../_shared/rules/code-quality/base.md` |
```

This is deliberate. Reasons:
- Cross-platform: works on Windows clones without `core.symlinks=true`.
- Discoverability: SKILL.md tables show at-a-glance which rules are shared vs role-local.
- grep-friendly: `grep -r "_shared/rules/git" skills/` finds every consumer.

## Override mechanism — when a role legitimately diverges

The default is "shared, period". When a role genuinely needs to deviate:

1. The role creates a local rule file with the same conceptual name (e.g. `be/rules/git.md`).
2. The local file **must include** the shared baseline by reference and document only the override:

```markdown
<!-- be/rules/git.md -->
# Git hygiene (BE)

Extends `../../_shared/rules/git.md`. BE-specific additions only:

## Commit trailer (BE-only)

Every commit must include a `Test-coverage: <pct>` trailer.
```

3. SKILL.md's rule table points at the local file. Reviewers should be able to see immediately what the role is overriding and why.

## Adding a new shared rule

1. Confirm the rule applies to ≥2 skills. If only one, it belongs in that skill's `rules/`.
2. Place the file in `_shared/rules/`.
3. Update each consuming skill's SKILL.md rule table to reference the new path.
4. Add a test case in the consuming skill's tests if the rule has a `validate/` script.

## Versioning

These files are version-controlled with the rest of the repo. Changes to `_shared/` require ARCH-judgment review (per LABEL_RULES.md governance). Plan migrations across all consumers in the same PR.
