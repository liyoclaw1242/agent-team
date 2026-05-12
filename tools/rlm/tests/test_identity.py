"""Tests for caller identity + permission table."""

from __future__ import annotations

import pytest

from rlm.errors import PermissionError
from rlm.identity import SUBCOMMAND_PERMISSIONS, VALID_ROLES, Caller


def test_from_env_without_role(clean_env: None) -> None:
    caller = Caller.from_env()
    assert caller.role == ""
    assert caller.invocation_id is None
    assert caller.skill_name is None


def test_from_env_with_role(as_worker: None) -> None:
    caller = Caller.from_env()
    assert caller.role == "worker"
    assert caller.invocation_id == "inv_test_worker_001"


def test_assert_can_missing_role_rejects(clean_env: None) -> None:
    caller = Caller.from_env()
    with pytest.raises(PermissionError) as excinfo:
        caller.assert_can("commit-spec")
    assert excinfo.value.exit_code == 3
    assert "RLM_AGENT_ROLE" in excinfo.value.message


def test_assert_can_invalid_role_rejects(clean_env: None, monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("RLM_AGENT_ROLE", "stranger")
    caller = Caller.from_env()
    with pytest.raises(PermissionError) as excinfo:
        caller.assert_can("commit-spec")
    assert excinfo.value.exit_code == 3


def test_worker_can_call_append_fact(as_worker: None) -> None:
    caller = Caller.from_env()
    caller.assert_can("append-fact")  # no raise
    caller.assert_can("open-pr")
    caller.assert_can("supersede-fact")


def test_worker_cannot_call_commit_spec(as_worker: None) -> None:
    caller = Caller.from_env()
    with pytest.raises(PermissionError):
        caller.assert_can("commit-spec")


def test_hermes_can_call_commit_spec(as_hermes: None) -> None:
    caller = Caller.from_env()
    caller.assert_can("commit-spec")
    caller.assert_can("confirm-spec")


def test_hermes_cannot_call_propose_adr(as_hermes: None) -> None:
    """Only hermes-design (with code-read) may propose ADRs."""
    caller = Caller.from_env()
    with pytest.raises(PermissionError):
        caller.assert_can("propose-adr")


def test_hermes_design_can_propose_adr(as_hermes_design: None) -> None:
    caller = Caller.from_env()
    caller.assert_can("propose-adr")
    caller.assert_can("commit-workpackage")
    caller.assert_can("approve-workpackage")


def test_dispatch_can_mark_in_progress(as_dispatch: None) -> None:
    caller = Caller.from_env()
    caller.assert_can("mark-in-progress")
    caller.assert_can("mark-delivered")


def test_dispatch_cannot_open_pr(as_dispatch: None) -> None:
    caller = Caller.from_env()
    with pytest.raises(PermissionError):
        caller.assert_can("open-pr")


def test_unknown_subcommand_is_fail_closed(as_worker: None) -> None:
    caller = Caller.from_env()
    with pytest.raises(PermissionError):
        caller.assert_can("totally-fake-subcommand")


def test_permission_table_covers_all_17() -> None:
    """Every subcommand referenced in the contract should be in the permission table."""
    expected = {
        "propose-adr",
        "propose-context-change",
        "add-contract",
        "append-fact",
        "supersede-fact",
        "append-business-model",
        "append-deployment-constraints",
        "commit-spec",
        "confirm-spec",
        "commit-workpackage",
        "approve-workpackage",
        "record-signal",
        "mark-superseded",
        "mark-in-progress",
        "mark-delivered",
        "open-pr",
        "enqueue-message",
    }
    assert expected == set(SUBCOMMAND_PERMISSIONS.keys()), (
        "Permission table does not cover exactly the 17 contract subcommands"
    )


def test_all_permission_table_roles_valid() -> None:
    for subcommand, roles in SUBCOMMAND_PERMISSIONS.items():
        for role in roles:
            assert role in VALID_ROLES, f"{subcommand!r} references invalid role {role!r}"
