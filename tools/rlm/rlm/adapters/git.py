"""Thin subprocess wrapper around `git`.

Used for direct-commit + PR-routed flows. Reads/writes only — no
auth bootstrapping (uses ambient git credentials).
"""

from __future__ import annotations

import subprocess
from pathlib import Path

from rlm.errors import ExternalServiceDownError, StateWriteError


def _run_git(
    args: list[str],
    *,
    cwd: Path | None = None,
    check: bool = True,
    capture: bool = True,
    timeout: int = 30,
) -> subprocess.CompletedProcess[str]:
    full = ["git", *args]
    try:
        result = subprocess.run(
            full,
            cwd=cwd,
            capture_output=capture,
            text=True,
            timeout=timeout,
            check=False,
        )
    except subprocess.TimeoutExpired as e:
        raise ExternalServiceDownError(
            f"git command timed out: {' '.join(full)}",
            details={"args": full},
        ) from e
    except OSError as e:
        raise ExternalServiceDownError(
            f"Failed to invoke git: {e}",
            details={"args": full, "error": str(e)},
        ) from e

    if check and result.returncode != 0:
        stderr = (result.stderr or "").strip()
        raise StateWriteError(
            f"git exited {result.returncode}: {stderr}",
            details={"args": full, "stderr": stderr, "stdout": result.stdout},
        )
    return result


def current_branch(cwd: Path | None = None) -> str:
    """Return the current branch name (or empty string if detached HEAD)."""
    result = _run_git(["branch", "--show-current"], cwd=cwd)
    return result.stdout.strip()


def repo_toplevel(cwd: Path | None = None) -> Path:
    result = _run_git(["rev-parse", "--show-toplevel"], cwd=cwd)
    return Path(result.stdout.strip())


def head_sha(cwd: Path | None = None, *, short: bool = True) -> str:
    arg = "--short" if short else ""
    args = ["rev-parse"]
    if arg:
        args.append(arg)
    args.append("HEAD")
    result = _run_git(args, cwd=cwd)
    return result.stdout.strip()


def checkout_new_branch(branch: str, *, base: str = "main", cwd: Path | None = None) -> None:
    # Ensure base exists locally + is current
    _run_git(["fetch", "origin", base], cwd=cwd, check=False)  # tolerate offline fetch fail
    _run_git(["checkout", "-B", branch, f"origin/{base}"], cwd=cwd)


def add(paths: list[str], cwd: Path | None = None) -> None:
    _run_git(["add", "--", *paths], cwd=cwd)


def commit(message: str, cwd: Path | None = None) -> str:
    """Create a commit. Returns the short SHA."""
    _run_git(["commit", "-m", message], cwd=cwd)
    return head_sha(cwd=cwd)


def push(branch: str, *, remote: str = "origin", cwd: Path | None = None) -> None:
    _run_git(["push", remote, branch], cwd=cwd)


def list_tree_main_paths(cwd: Path | None = None) -> list[str]:
    """Return list of file paths tracked on `main` (read-only inspection).

    Used by `approve-workpackage` to verify `adr_refs` files exist on main.
    """
    result = _run_git(["ls-tree", "-r", "--name-only", "main"], cwd=cwd)
    return [line for line in result.stdout.splitlines() if line]


def list_branch_commits(
    branch: str,
    *,
    base: str = "main",
    cwd: Path | None = None,
) -> list[str]:
    """Return commit messages on `branch` not yet on `base` (newest first).

    Used by `open-pr` to verify a fact commit exists on the Worker's branch.
    """
    result = _run_git(["log", "--format=%s", f"{base}..{branch}"], cwd=cwd)
    return [line for line in result.stdout.splitlines() if line]


def branch_exists(branch: str, cwd: Path | None = None) -> bool:
    """Return True if `branch` exists locally."""
    result = _run_git(
        ["rev-parse", "--verify", "--quiet", branch],
        cwd=cwd,
        check=False,
    )
    return result.returncode == 0


__all__ = [
    "current_branch",
    "repo_toplevel",
    "head_sha",
    "checkout_new_branch",
    "add",
    "commit",
    "push",
    "list_tree_main_paths",
    "list_branch_commits",
    "branch_exists",
]
