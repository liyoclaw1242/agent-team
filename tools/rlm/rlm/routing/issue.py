"""Issue-routed operations: create Issues, flip labels, add comments.

Used by `commit-spec`, `confirm-spec`, `commit-workpackage`, `approve-workpackage`,
`record-signal`, `mark-superseded`, `mark-in-progress`, `mark-delivered`,
`enqueue-message`.

This module is thin — most of the work is in `adapters.gh`. The wrappers here
exist to enforce contract-level invariants (label combinations, validation).
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any

from rlm.adapters import gh
from rlm.errors import PreconditionFailedError, ValidationError


@dataclass
class IssueCreatedResult:
    number: int
    labels: list[str]


def create_workflow_issue(
    *,
    title: str,
    body: str,
    item_type: str,  # signal | spec | workpackage | supervision-alert
    initial_status: str = "draft",
    extra_labels: list[str] | None = None,
) -> IssueCreatedResult:
    """Create a workflow Issue with `type:<item_type>` and `status:<initial_status>` labels."""
    labels = [f"type:{item_type}", f"status:{initial_status}"]
    labels.extend(extra_labels or [])
    number = gh.issue_create(title=title, body=body, labels=labels)
    return IssueCreatedResult(number=number, labels=labels)


def flip_status(
    *,
    issue_number: int,
    from_status: str,
    to_status: str,
    require_type: str | None = None,
    extra_add_labels: list[str] | None = None,
    extra_remove_labels: list[str] | None = None,
) -> None:
    """Atomically flip an Issue's status label.

    Verifies current state matches `from_status` before flipping. Idempotency:
    if Issue is already at `to_status`, no-op (success).
    """
    data = gh.issue_view(issue_number, fields=["labels"])
    label_names = {entry["name"] for entry in data.get("labels", []) if "name" in entry}

    if require_type and f"type:{require_type}" not in label_names:
        raise PreconditionFailedError(
            f"Issue #{issue_number} is not type:{require_type}",
            details={"actual_labels": sorted(label_names)},
        )

    if f"status:{to_status}" in label_names:
        # Already at target — idempotent no-op
        return

    if f"status:{from_status}" not in label_names:
        raise PreconditionFailedError(
            f"Issue #{issue_number} not at status:{from_status} (cannot flip to {to_status})",
            details={"actual_labels": sorted(label_names)},
        )

    add = [f"status:{to_status}", *(extra_add_labels or [])]
    remove = [f"status:{from_status}", *(extra_remove_labels or [])]
    gh.issue_edit(issue_number, add_labels=add, remove_labels=remove)


def add_comment(issue_number: int, body: str) -> None:
    gh.issue_comment(issue_number, body)


def verify_issue_exists(issue_number: int, *, expected_type: str) -> dict[str, Any]:
    """Read an Issue and verify it carries `type:<expected_type>`. Returns the data."""
    data = gh.issue_view(issue_number, fields=["number", "title", "body", "labels", "state"])
    label_names = {entry["name"] for entry in data.get("labels", []) if "name" in entry}
    if f"type:{expected_type}" not in label_names:
        raise ValidationError(
            f"Issue #{issue_number} is not type:{expected_type}",
            details={"actual_labels": sorted(label_names)},
        )
    return data


__all__ = [
    "create_workflow_issue",
    "flip_status",
    "add_comment",
    "verify_issue_exists",
    "IssueCreatedResult",
]
