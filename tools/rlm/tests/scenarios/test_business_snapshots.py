"""Layer 4 business: append-business-model + append-deployment-constraints.

Hermes on main; commits + pushes. Real git on tmp dir; push mocked.
"""

from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path

import pytest
from click.testing import CliRunner

from rlm.cli import main


def _write(p: Path, content: str) -> Path:
    p.write_text(content, encoding="utf-8")
    return p


def test_append_business_model_writes_pushes(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    pushes: list[dict] = git_runner_env["pushes"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_bm")

    today = datetime.now(timezone.utc).date().isoformat()
    body = _write(
        repo / "bm.md",
        "Wedge: shared household list for roommates.\nTarget: 2-3 person households.\n",
    )

    result = runner.invoke(
        main,
        [
            "--json",
            "append-business-model",
            "--signal-ref",
            "1",
            "--snapshot-date",
            today,
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"failed: stderr={result.stderr}"
    _ = json.loads(result.output)  # validate it parses

    path = repo / ".rlm" / "business" / f"business-model-{today}.md"
    assert path.exists()
    content = path.read_text(encoding="utf-8")
    assert "type: business-model" in content
    assert f"snapshot_date: '{today}'" in content or f"snapshot_date: {today}" in content
    assert "signal_ref: 1" in content
    assert "author_invocation: inv_bm" in content
    assert "Wedge: shared household list" in content

    # Pushed to origin/main
    assert len(pushes) == 1
    assert pushes[0]["branch"] == "main"
    assert pushes[0]["remote"] == "origin"


def test_append_deployment_constraints_with_inline_fields(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    pushes: list[dict] = git_runner_env["pushes"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_dc")

    today = datetime.now(timezone.utc).date().isoformat()

    result = runner.invoke(
        main,
        [
            "--json",
            "append-deployment-constraints",
            "--signal-ref",
            "1",
            "--snapshot-date",
            today,
            "--budget-monthly-cap",
            "10",
            "--budget-free-tier-required",
            "--region",
            "Taiwan",
            "--compliance",
            "",
            "--vendor-preferences",
            "open",
            "--operations",
            "managed_only",
            "--notes",
            "private app, friends only",
            # No --body-file → body content is empty
        ],
        env={"RLM_AGENT_ROLE": "hermes", "RLM_AGENT_INVOCATION": "inv_dc"},
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"failed: stderr={result.stderr}"
    _ = json.loads(result.output)  # validate it parses

    path = repo / ".rlm" / "business" / f"deployment-constraints-{today}.md"
    assert path.exists()
    content = path.read_text(encoding="utf-8")

    assert "type: deployment-constraints" in content
    assert "region: Taiwan" in content
    assert "operations: managed_only" in content
    assert "monthly_cap_usd: 10" in content
    assert "free_tier_required: true" in content
    assert "compliance: []" in content
    assert "private app, friends only" in content

    # Pushed
    assert len(pushes) == 1
    assert pushes[0]["branch"] == "main"


def test_append_business_model_rejects_future_date(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_future")

    body = _write(repo / "bm.md", "x")
    result = runner.invoke(
        main,
        [
            "--json",
            "append-business-model",
            "--signal-ref",
            "1",
            "--snapshot-date",
            "2099-01-01",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 2
    err = json.loads(result.stderr)
    assert err["error"] == "validation-error"
