"""PR-routed writes: ADRs, CONTEXT.md changes, contracts.

Pattern:
  1. Branch off main: `<kind>/<slug>`
  2. Write the file(s)
  3. Commit + push
  4. Open PR via gh

Used by `propose-adr`, `propose-context-change`, `add-contract`.
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from rlm.adapters import gh, git


@dataclass
class PrRoutedResult:
    branch: str
    commit_sha: str
    pr_number: int
    pr_url: str


def open_pr_for_file_change(
    *,
    repo_root: Path,
    branch: str,
    file_path: Path,
    file_content: str,
    commit_message: str,
    pr_title: str,
    pr_body: str,
    base: str = "main",
) -> PrRoutedResult:
    """Create branch from base, write file, commit, push, open PR.

    The file_path must be inside repo_root. File is overwritten if it exists
    on the new branch (typical for single-file additions; for edits, callers
    should fetch existing content into file_content before calling).
    """
    file_path = file_path.resolve()
    if not str(file_path).startswith(str(repo_root.resolve())):
        from rlm.errors import ValidationError

        raise ValidationError(
            f"file_path {file_path} is outside repo_root {repo_root}",
            field="file_path",
        )

    # 1. branch off base
    git.checkout_new_branch(branch, base=base, cwd=repo_root)

    # 2. write file
    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(file_content, encoding="utf-8", newline="\n")

    # 3. commit
    rel = file_path.relative_to(repo_root)
    git.add([str(rel)], cwd=repo_root)
    sha = git.commit(commit_message, cwd=repo_root)

    # 4. push + open PR
    git.push(branch, cwd=repo_root)
    pr_number = gh.pr_create(head=branch, base=base, title=pr_title, body=pr_body)
    pr_view = gh.pr_view(pr_number, fields=["url"])
    pr_url = str(pr_view.get("url", ""))

    return PrRoutedResult(
        branch=branch,
        commit_sha=sha,
        pr_number=pr_number,
        pr_url=pr_url,
    )


__all__ = ["open_pr_for_file_change", "PrRoutedResult"]
