# Git Hygiene

Branch naming, commit format, and merge-readiness rules. Applies to all roles unless overridden.

## Branch naming

Pattern: `{role}/issue-{N}-{short-slug}`

Examples:
- `fe/issue-142-cancel-button`
- `be/issue-143-subscription-api`
- `arch-shape/issue-101-decompose-mgmt`

Rules:
- Lowercase only. ASCII a-z, 0-9, hyphen.
- Slug max 5 words; dropping articles is fine (`fix-stale-token` not `fix-the-stale-token`).
- One branch per issue. Don't reuse branches across issues.
- After merge, the branch is deleted automatically by `gh pr merge --delete-branch`. Do not push to a deleted branch.

## Commit format

Conventional commits with these types: `feat` `fix` `chore` `refactor` `docs` `test` `perf`.

Format:
```
{type}({scope}): {summary}

{body — wrap at 72 cols, optional}

Refs: #{issue-number}
```

Required:
- A `Refs: #N` trailer pointing to the issue this commit addresses.
- Summary in imperative mood, lowercase, no trailing period (`add cancel button` not `Added cancel button.`).
- Scope is the bounded context or component (`billing`, `auth`, `ui`).

Forbidden:
- `wip` commits in PR-bound branches. Squash or rebase before opening PR.
- Co-authored commits without explicit attribution (use `Co-authored-by:` trailer).

## PR readiness

Before opening a PR, verify:

- [ ] Branch is up-to-date with the target branch (rebase, do not merge).
- [ ] All commits have a `Refs: #N` trailer.
- [ ] No `console.log`, `print()`, `dbg!` left behind.
- [ ] Self-test record exists at `/tmp/self-test-issue-{N}.md` (per role's deliver gate).
- [ ] CI passes on the branch.

## Validation

Each role's `validate/git-check.sh` runs:
- `git log --pretty=%s` checks every commit for type prefix.
- `git log --pretty=%B | grep -c '^Refs: #'` matches commit count.
- Branch name regex: `^(fe|be|ops|qa|design|debug|arch-[a-z]+)/issue-[0-9]+-[a-z0-9-]+$`.
