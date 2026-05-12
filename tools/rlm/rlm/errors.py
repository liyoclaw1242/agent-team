"""Exception types mapped to exit codes per contract § Error model.

Every error path raises one of these. The CLI entrypoint catches RlmError,
serialises to single-line JSON on stderr, and exits with the matched code.
"""

from __future__ import annotations

from typing import Any


class RlmError(Exception):
    """Base for all CLI errors. Defaults map to exit-code 99 (internal-error)."""

    exit_code: int = 99
    error_name: str = "internal-error"

    def __init__(
        self,
        message: str,
        *,
        field: str | None = None,
        details: dict[str, Any] | None = None,
        subcommand: str | None = None,
    ) -> None:
        super().__init__(message)
        self.message = message
        self.field = field
        self.details = details or {}
        self.subcommand = subcommand

    def to_dict(self) -> dict[str, Any]:
        out: dict[str, Any] = {
            "error": self.error_name,
            "exit_code": self.exit_code,
            "message": self.message,
        }
        if self.subcommand:
            out["subcommand"] = self.subcommand
        if self.field:
            out["field"] = self.field
        if self.details:
            out["details"] = self.details
        return out


class UsageError(RlmError):
    """Exit 1 — bad CLI invocation (unknown flag, conflicting flags)."""

    exit_code = 1
    error_name = "usage-error"


class ValidationError(RlmError):
    """Exit 2 — body / frontmatter / labels failed schema check."""

    exit_code = 2
    error_name = "validation-error"


class PermissionError(RlmError):
    """Exit 3 — caller RLM_AGENT_ROLE not allowed for this subcommand."""

    exit_code = 3
    error_name = "permission-error"


class NoRlmRootError(RlmError):
    """Exit 4 — walk-up from CWD never found a `.rlm/` directory."""

    exit_code = 4
    error_name = "no-rlm-root"


class StateWriteError(RlmError):
    """Exit 5 — external write failed (git, gh, redis, JSONL)."""

    exit_code = 5
    error_name = "state-write-error"


class PreconditionFailedError(RlmError):
    """Exit 6 — subcommand-specific gate failed (e.g., unmerged adr_refs)."""

    exit_code = 6
    error_name = "precondition-failed"


class ConflictError(RlmError):
    """Exit 7 — concurrent-write conflict (rare)."""

    exit_code = 7
    error_name = "conflict"


class ExternalServiceDownError(RlmError):
    """Exit 8 — GitHub / Redis / git remote unreachable (transient)."""

    exit_code = 8
    error_name = "external-service-down"


__all__ = [
    "RlmError",
    "UsageError",
    "ValidationError",
    "PermissionError",
    "NoRlmRootError",
    "StateWriteError",
    "PreconditionFailedError",
    "ConflictError",
    "ExternalServiceDownError",
]
