"""Direct-commit writes: facts, business-model snapshots, deployment-constraints.

Pattern depends on which branch is active:
  - Worker on `wp/*`: commit on current branch (eventually included in PR)
  - Hermes typically on `main`: commit + push to main immediately

The branch decision is left to the caller (subcommands inspect
`git.current_branch()` and pass `push=True/False`).
"""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from rlm.adapters import git
from rlm.errors import ValidationError


@dataclass
class DirectCommitResult:
    branch: str
    commit_sha: str
    pushed: bool


def commit_file(
    *,
    repo_root: Path,
    file_path: Path,
    file_content: str,
    commit_message: str,
    push: bool,
    additional_files: list[tuple[Path, str]] | None = None,
) -> DirectCommitResult:
    """Write file (and optional additional files), commit, optionally push.

    `additional_files` is a list of (path, content) tuples for atomic
    multi-file commits (e.g., `supersede-fact` writes the new fact + edits
    the old fact's frontmatter).
    """
    file_path = file_path.resolve()
    if not str(file_path).startswith(str(repo_root.resolve())):
        raise ValidationError(
            f"file_path {file_path} is outside repo_root {repo_root}",
            field="file_path",
        )

    file_path.parent.mkdir(parents=True, exist_ok=True)
    file_path.write_text(file_content, encoding="utf-8", newline="\n")
    rels = [str(file_path.relative_to(repo_root))]

    for extra_path, extra_content in additional_files or []:
        extra_path = extra_path.resolve()
        if not str(extra_path).startswith(str(repo_root.resolve())):
            raise ValidationError(
                f"additional file {extra_path} is outside repo_root {repo_root}",
                field="additional_files",
            )
        extra_path.parent.mkdir(parents=True, exist_ok=True)
        extra_path.write_text(extra_content, encoding="utf-8", newline="\n")
        rels.append(str(extra_path.relative_to(repo_root)))

    git.add(rels, cwd=repo_root)
    sha = git.commit(commit_message, cwd=repo_root)
    branch = git.current_branch(cwd=repo_root)

    if push:
        git.push(branch, cwd=repo_root)

    return DirectCommitResult(branch=branch, commit_sha=sha, pushed=push)


__all__ = ["commit_file", "DirectCommitResult"]
