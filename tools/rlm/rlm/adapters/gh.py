"""Thin subprocess wrapper around the `gh` CLI.

We shell out rather than use PyGithub:
  - `gh` is already required to be installed (per Worker / Hermes env)
  - Auth flows through `gh auth` (or GH_TOKEN env) — single source
  - Output is JSON via `--json` flag for parsing
"""

from __future__ import annotations

import json
import shutil
import subprocess
from typing import Any

from rlm.errors import ExternalServiceDownError, StateWriteError


def _ensure_gh_available() -> None:
    if shutil.which("gh") is None:
        raise ExternalServiceDownError(
            "gh CLI not on PATH — install GitHub CLI to use Issue/PR subcommands",
            details={"hint": "https://cli.github.com/"},
        )


def _run_gh(args: list[str], *, json_fields: list[str] | None = None) -> Any:
    """Execute `gh` with args; return parsed JSON if json_fields supplied, else stdout str.

    Raises:
        StateWriteError on non-zero exit
        ExternalServiceDownError on transient (subprocess can't reach gh) issues
    """
    _ensure_gh_available()
    full_args = ["gh", *args]
    if json_fields is not None:
        full_args.extend(["--json", ",".join(json_fields)])

    try:
        result = subprocess.run(
            full_args,
            capture_output=True,
            text=True,
            check=False,
            timeout=30,
        )
    except subprocess.TimeoutExpired as e:
        raise ExternalServiceDownError(
            f"gh command timed out after 30s: {' '.join(full_args)}",
            details={"args": full_args},
        ) from e
    except OSError as e:
        raise ExternalServiceDownError(
            f"Failed to invoke gh: {e}",
            details={"args": full_args, "error": str(e)},
        ) from e

    if result.returncode != 0:
        # Classify common failure shapes
        stderr = result.stderr.strip()
        if "could not resolve" in stderr.lower() or "connection" in stderr.lower():
            raise ExternalServiceDownError(
                f"gh transient failure: {stderr}",
                details={"args": full_args, "stderr": stderr},
            )
        raise StateWriteError(
            f"gh exited {result.returncode}: {stderr}",
            details={"args": full_args, "stderr": stderr, "stdout": result.stdout},
        )

    if json_fields is not None:
        try:
            return json.loads(result.stdout)
        except json.JSONDecodeError as e:
            raise StateWriteError(
                f"gh returned invalid JSON: {e}",
                details={"args": full_args, "stdout": result.stdout},
            ) from e

    return result.stdout


# ---- Issue operations ----


def issue_create(
    title: str,
    body: str,
    labels: list[str],
    *,
    assignees: list[str] | None = None,
) -> int:
    """Create a GitHub Issue. Return its number."""
    args = ["issue", "create", "--title", title, "--body", body]
    for label in labels:
        args.extend(["--label", label])
    for assignee in assignees or []:
        args.extend(["--assignee", assignee])

    # `gh issue create` prints the issue URL on stdout, e.g. https://github.com/owner/repo/issues/143
    url = _run_gh(args).strip()
    # Parse last segment as int
    try:
        return int(url.rsplit("/", 1)[-1])
    except (ValueError, IndexError) as e:
        raise StateWriteError(
            f"Could not parse issue number from gh output: {url!r}",
            details={"url": url},
        ) from e


def issue_view(number: int, *, fields: list[str]) -> dict[str, Any]:
    """Fetch Issue data. Common fields: number, title, body, labels, state,
    comments, closedByPullRequestsReferences."""
    return _run_gh(["issue", "view", str(number)], json_fields=fields)


def issue_edit(
    number: int,
    *,
    add_labels: list[str] | None = None,
    remove_labels: list[str] | None = None,
    body: str | None = None,
) -> None:
    args = ["issue", "edit", str(number)]
    for label in add_labels or []:
        args.extend(["--add-label", label])
    for label in remove_labels or []:
        args.extend(["--remove-label", label])
    if body is not None:
        args.extend(["--body", body])
    _run_gh(args)


def issue_comment(number: int, body: str) -> None:
    _run_gh(["issue", "comment", str(number), "--body", body])


def issue_list(
    *,
    labels: list[str] | None = None,
    state: str = "open",
    search: str | None = None,
    fields: list[str] | None = None,
) -> list[dict[str, Any]]:
    args = ["issue", "list", "--state", state]
    for label in labels or []:
        args.extend(["--label", label])
    if search:
        args.extend(["--search", search])
    result = _run_gh(args, json_fields=fields or ["number", "title", "labels"])
    if not isinstance(result, list):
        raise StateWriteError(
            "gh issue list returned non-list JSON",
            details={"got": str(type(result).__name__)},
        )
    return result


# ---- PR operations ----


def pr_create(
    *,
    head: str,
    base: str,
    title: str,
    body: str,
) -> int:
    """Create a PR. Return its number."""
    url = _run_gh(
        [
            "pr",
            "create",
            "--head",
            head,
            "--base",
            base,
            "--title",
            title,
            "--body",
            body,
        ]
    ).strip()
    try:
        return int(url.rsplit("/", 1)[-1])
    except (ValueError, IndexError) as e:
        raise StateWriteError(
            f"Could not parse PR number from gh output: {url!r}",
            details={"url": url},
        ) from e


def pr_view(number: int, *, fields: list[str]) -> dict[str, Any]:
    return _run_gh(["pr", "view", str(number)], json_fields=fields)


__all__ = [
    "issue_create",
    "issue_view",
    "issue_edit",
    "issue_comment",
    "issue_list",
    "pr_create",
    "pr_view",
]


# Note on label management:
#   `gh issue edit` requires labels to already exist on the repo. Initial setup
#   is a separate bootstrap concern (e.g., a small Bash script that does
#   `gh label create type:spec --color ...` for every label in our scheme).
#   That bootstrap is out of scope for v0.1.0 and tracked in v2-todo / repo
#   setup docs.
def _label_management_note() -> None:
    """See module docstring's note on label bootstrap."""
    pass
