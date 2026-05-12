"""Locate the `.rlm/` directory by walking up from CWD.

Per contract § Invocation conventions / `.rlm/` discovery:
  1. `--rlm-root <path>` if explicitly set
  2. Walk up from $PWD until a parent contains `.rlm/`
  3. Else: raise NoRlmRootError
"""

from __future__ import annotations

from pathlib import Path

from rlm.errors import NoRlmRootError


def find_rlm_root(
    start: Path | None = None,
    override: Path | None = None,
) -> Path:
    """Return the repo root (the parent of `.rlm/`).

    Args:
        start: where to begin the walk-up. Defaults to current working directory.
        override: explicit `--rlm-root` path; if set, must contain `.rlm/`.

    Returns:
        Absolute path to the repo root.

    Raises:
        NoRlmRootError (exit 4) if no `.rlm/` directory is found.
    """
    if override is not None:
        override = override.resolve()
        if (override / ".rlm").is_dir():
            return override
        raise NoRlmRootError(
            f"--rlm-root path {override} does not contain a .rlm/ directory",
            details={"override": str(override)},
        )

    cwd = (start or Path.cwd()).resolve()
    for candidate in (cwd, *cwd.parents):
        if (candidate / ".rlm").is_dir():
            return candidate

    raise NoRlmRootError(
        "No .rlm/ directory found by walking up from CWD",
        details={"cwd": str(cwd)},
    )


__all__ = ["find_rlm_root"]
