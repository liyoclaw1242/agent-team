"""Caller identity + permission table.

Per contract § Caller identity:
  - env var RLM_AGENT_ROLE is required on every write subcommand
  - 8 valid role values; missing or invalid → exit 3 (permission-error)
  - Per-subcommand permission table mirrors ADR-0009
"""

from __future__ import annotations

import os
from dataclasses import dataclass

from rlm.errors import PermissionError

VALID_ROLES: frozenset[str] = frozenset(
    {
        "hermes",
        "hermes-design",
        "worker",
        "dispatch",
        "whitebox-validator",
        "blackbox-validator",
        "arbiter",
        "supervision",
    }
)


# Subcommand → set of roles allowed to call it.
# Mirrors ADR-0009 access matrix + contract § Caller identity / Permission table.
SUBCOMMAND_PERMISSIONS: dict[str, frozenset[str]] = {
    # PR-routed (design-domain Hermes only)
    "propose-adr": frozenset({"hermes-design"}),
    "propose-context-change": frozenset({"hermes-design"}),
    "add-contract": frozenset({"hermes-design"}),
    # Direct-commit
    "append-fact": frozenset({"worker"}),
    "supersede-fact": frozenset({"worker"}),
    "append-business-model": frozenset({"hermes", "hermes-design"}),
    "append-deployment-constraints": frozenset({"hermes", "hermes-design"}),
    # Issue create/relabel — Hermes side
    "commit-spec": frozenset({"hermes"}),
    "confirm-spec": frozenset({"hermes"}),
    "commit-workpackage": frozenset({"hermes-design"}),
    "approve-workpackage": frozenset({"hermes-design"}),
    "record-signal": frozenset({"hermes"}),
    "mark-superseded": frozenset({"hermes", "hermes-design"}),
    # Delivery lifecycle
    "mark-in-progress": frozenset({"dispatch"}),
    "mark-delivered": frozenset({"dispatch"}),
    # Worker outputs
    "open-pr": frozenset({"worker"}),
    # Cross-cutting outbound messaging
    "enqueue-message": frozenset(
        {"hermes", "hermes-design", "dispatch", "supervision", "worker", "arbiter"}
    ),
}


# Subcommands that are read-only and require no role (any caller permitted).
# Currently empty — v1 has no read subcommands in the CLI (use `gh` directly).
READ_ONLY_SUBCOMMANDS: frozenset[str] = frozenset()


@dataclass(frozen=True)
class Caller:
    """The identity of the agent invoking the CLI, derived from env vars."""

    role: str
    invocation_id: str | None = None
    skill_name: str | None = None

    @classmethod
    def from_env(cls) -> Caller:
        """Build a Caller from the standard env vars. No validation of role
        membership here — see `assert_can` for per-subcommand checks.

        Returns a Caller even if RLM_AGENT_ROLE is unset (role = "" then),
        so read-only flows / `--help` work.
        """
        return cls(
            role=os.environ.get("RLM_AGENT_ROLE", "").strip(),
            invocation_id=os.environ.get("RLM_AGENT_INVOCATION") or None,
            skill_name=os.environ.get("RLM_SKILL_NAME") or None,
        )

    def assert_can(self, subcommand: str) -> None:
        """Raise PermissionError if this caller may not invoke `subcommand`.

        Read-only subcommands are permitted regardless of role.
        """
        if subcommand in READ_ONLY_SUBCOMMANDS:
            return

        if not self.role:
            raise PermissionError(
                "RLM_AGENT_ROLE env var is required for write subcommands",
                subcommand=subcommand,
                details={"valid_roles": sorted(VALID_ROLES)},
            )

        if self.role not in VALID_ROLES:
            raise PermissionError(
                f"Unknown RLM_AGENT_ROLE: {self.role!r}",
                subcommand=subcommand,
                details={"valid_roles": sorted(VALID_ROLES)},
            )

        allowed = SUBCOMMAND_PERMISSIONS.get(subcommand)
        if allowed is None:
            # Subcommand not in our permission map — defensive fail-closed.
            raise PermissionError(
                f"Subcommand {subcommand!r} has no permission table entry",
                subcommand=subcommand,
            )

        if self.role not in allowed:
            raise PermissionError(
                f"Role {self.role!r} not allowed to call {subcommand!r}",
                subcommand=subcommand,
                details={"role": self.role, "allowed_roles": sorted(allowed)},
            )


__all__ = [
    "Caller",
    "VALID_ROLES",
    "SUBCOMMAND_PERMISSIONS",
    "READ_ONLY_SUBCOMMANDS",
]
