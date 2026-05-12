"""Layer 5 PR-routed: propose-adr / add-contract / propose-context-change.

Real git on tmp dir; push mocked; PR creation via fake_github.
"""

from __future__ import annotations

import json
import subprocess as sp
from pathlib import Path

import pytest
from click.testing import CliRunner

from rlm.cli import main


def _write(p: Path, content: str) -> Path:
    p.write_text(content, encoding="utf-8")
    return p


def _list_branches(repo: Path) -> list[str]:
    result = sp.run(
        ["git", "branch", "--list"],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )
    return [line.strip().lstrip("*").strip() for line in result.stdout.splitlines() if line.strip()]


def test_propose_adr_opens_pr_with_frontmatter(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    fake_gh = git_runner_env["github"]
    pushes: list[dict] = git_runner_env["pushes"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_adr")

    body = _write(
        repo / "adr_body.md",
        "# Use single-region deployment\n\n"
        "All v1 traffic served from Tokyo region.\n\n"
        "## Why\n\nLatency budget...\n",
    )

    result = runner.invoke(
        main,
        [
            "--json",
            "propose-adr",
            "--slug",
            "0001-single-region-deploy",
            "--title",
            "Use single-region deployment",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"propose-adr failed: stderr={result.stderr}"
    out = json.loads(result.output)
    assert out["adr_number"] == 1
    assert out["slug"] == "0001-single-region-deploy"
    assert out["branch"] == "adr/0001-single-region-deploy"
    pr_num = out["pr_number"]

    # File written on the adr branch
    adr_file = repo / ".rlm" / "adr" / "0001-single-region-deploy.md"
    assert adr_file.exists()
    content = adr_file.read_text(encoding="utf-8")
    assert "type: adr" in content
    assert "adr_number: 1" in content
    assert "status: proposed" in content
    assert "# Use single-region deployment" in content

    # Branch exists locally
    branches = _list_branches(repo)
    assert "adr/0001-single-region-deploy" in branches

    # Push was called once
    assert any(p["branch"] == "adr/0001-single-region-deploy" for p in pushes)

    # PR exists in fake_github
    pr = fake_gh.prs[pr_num]
    assert pr.head == "adr/0001-single-region-deploy"
    assert pr.base == "main"
    assert "ADR-0001" in pr.title


def test_propose_adr_rejects_non_monotonic_slug(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_skip")

    body = _write(repo / "b.md", "# Title\n\nbody\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "propose-adr",
            "--slug",
            "0005-skipped-numbers",
            "--title",
            "T",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 2
    err = json.loads(result.stderr)
    assert err["error"] == "validation-error"
    assert err["details"]["expected"] == "0001"


def test_propose_adr_rejects_body_without_h1(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_no_h1")

    body = _write(repo / "b.md", "## Subsection only\n\nbody without h1\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "propose-adr",
            "--slug",
            "0001-foo",
            "--title",
            "T",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 2
    err = json.loads(result.stderr)
    assert err["error"] == "validation-error"


def test_add_contract_opens_pr(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    fake_gh = git_runner_env["github"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_contract")

    body = _write(
        repo / "contract.md",
        "# Household API\n\nREST endpoints for household management.\n\n"
        "## Shape\n\nPOST /api/household\n\n"
        "## Invariants\n\nAll endpoints require auth\n\n"
        "## Error modes\n\n401 / 404 / 500\n\n"
        "## Versioning policy\n\nadditive-only\n",
    )

    result = runner.invoke(
        main,
        [
            "--json",
            "add-contract",
            "--slug",
            "household-api",
            "--contract-kind",
            "api",
            "--title",
            "Household API",
            "--versioning",
            "semver",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"add-contract failed: stderr={result.stderr}"
    out = json.loads(result.output)
    assert out["slug"] == "household-api"
    assert out["contract_kind"] == "api"

    contract_path = repo / ".rlm" / "contracts" / "household-api.md"
    assert contract_path.exists()
    content = contract_path.read_text(encoding="utf-8")
    assert "type: contract" in content
    assert "contract_kind: api" in content
    assert "versioning: semver" in content

    pr = fake_gh.prs[out["pr_number"]]
    assert pr.head == "contract/household-api"
    assert "household-api" in pr.title
    assert "(api)" in pr.title


def test_propose_context_change_edits_existing_file(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    fake_gh = git_runner_env["github"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_ctx")

    # tmp_rlm_repo fixture already wrote .rlm/bc/intake/CONTEXT.md with "# Intake\n"
    new_content = _write(
        repo / "new_ctx.md",
        "# Intake\n\nUpdated body — added Household term.\n",
    )

    result = runner.invoke(
        main,
        [
            "--json",
            "propose-context-change",
            "--target",
            "bc/intake/CONTEXT.md",
            "--new-content-file",
            str(new_content),
            "--reason",
            "add Household term",
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"propose-context-change failed: stderr={result.stderr}"
    out = json.loads(result.output)
    assert out["target"] == "bc/intake/CONTEXT.md"
    assert "add-household-term" in out["branch"]

    # File was actually edited on the PR branch
    edited = repo / ".rlm" / "bc" / "intake" / "CONTEXT.md"
    assert "Updated body — added Household term." in edited.read_text(encoding="utf-8")

    # PR opened
    pr = fake_gh.prs[out["pr_number"]]
    assert "context-change/add-household-term" in pr.head


def test_propose_context_change_rejects_unchanged_content(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_noop")

    # Read current content from fixture
    target = repo / ".rlm" / "bc" / "intake" / "CONTEXT.md"
    same_content = _write(repo / "same.md", target.read_text(encoding="utf-8"))

    result = runner.invoke(
        main,
        [
            "--json",
            "propose-context-change",
            "--target",
            "bc/intake/CONTEXT.md",
            "--new-content-file",
            str(same_content),
            "--reason",
            "noop",
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 2
    err = json.loads(result.stderr)
    assert err["error"] == "validation-error"
    assert "identical" in err["message"]


def test_propose_context_change_rejects_bad_target(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_bad_target")

    new = _write(repo / "x.md", "anything")
    result = runner.invoke(
        main,
        [
            "--json",
            "propose-context-change",
            "--target",
            "adr/0001-foo.md",  # not a valid context target
            "--new-content-file",
            str(new),
            "--reason",
            "x",
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 2
    err = json.loads(result.stderr)
    assert err["error"] == "validation-error"
