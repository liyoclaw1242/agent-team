"""Targeted test for mark-in-progress (not covered by scenarios)."""

from __future__ import annotations

import json
from pathlib import Path  # noqa: F401

import pytest
from click.testing import CliRunner

from rlm.cli import main


def test_mark_in_progress_flips_approved_wp(
    runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = runner_env["github"]

    wp_num = fake_gh.add_issue(
        title="WP",
        body="",
        labels=["type:workpackage", "status:approved"],
    )

    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_dispatch")

    result = runner.invoke(
        main,
        ["--json", "mark-in-progress", "--issue", str(wp_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"failed: stderr={result.stderr}"
    out = json.loads(result.output)
    assert out["status"] == "in_progress"
    assert out["agent"] == "worker"

    wp = fake_gh.issues[wp_num]
    assert "status:in_progress" in wp.labels
    assert "status:approved" not in wp.labels
    assert "agent:worker" in wp.labels


def test_mark_in_progress_rejects_non_workpackage(
    runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = runner_env["github"]

    # A Spec instead of WP
    spec_num = fake_gh.add_issue(
        title="Spec",
        body="",
        labels=["type:spec", "status:approved"],
    )

    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_reject_type")

    result = runner.invoke(
        main,
        ["--json", "mark-in-progress", "--issue", str(spec_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 6
    err = json.loads(result.stderr)
    assert err["error"] == "precondition-failed"


def test_mark_in_progress_idempotent(
    runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Calling twice on the same WP returns the cached/idempotent result."""
    runner = CliRunner()
    fake_gh = runner_env["github"]

    wp_num = fake_gh.add_issue(
        title="WP",
        body="",
        labels=["type:workpackage", "status:approved"],
    )

    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_idempotent")

    result1 = runner.invoke(
        main, ["--json", "mark-in-progress", "--issue", str(wp_num)], catch_exceptions=False
    )
    assert result1.exit_code == 0

    result2 = runner.invoke(
        main, ["--json", "mark-in-progress", "--issue", str(wp_num)], catch_exceptions=False
    )
    assert result2.exit_code == 0
    out = json.loads(result2.output)
    # Second call returns cached result
    assert out.get("idempotent") is True
