"""Layer 4 facts: append-fact + supersede-fact on a `wp/*` branch (Worker context).

Real git on tmp dir; no push (Worker's open-pr would push later).
"""

from __future__ import annotations

import json
import subprocess as sp
from datetime import datetime, timezone
from pathlib import Path

import pytest
from click.testing import CliRunner

from rlm.cli import main


def _checkout_wp_branch(repo: Path, branch: str) -> None:
    sp.run(["git", "checkout", "-b", branch], cwd=repo, check=True, capture_output=True)


def _write(p: Path, content: str) -> Path:
    p.write_text(content, encoding="utf-8")
    return p


def test_append_fact_writes_committed_fact_on_wp_branch(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Worker on wp/144-revert-calendar runs append-fact → commit on current branch."""
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    pushes: list[dict] = git_runner_env["pushes"]

    _checkout_wp_branch(repo, "wp/144-revert-calendar")

    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_worker_fact")

    today = datetime.now(timezone.utc).date().isoformat()
    slug = f"{today}-calendar-widget-version"
    body = _write(
        repo / "fact_body.md",
        "Calendar widget reverted to v1.2 server-rendered snapshot.\n",
    )

    result = runner.invoke(
        main,
        [
            "--json",
            "append-fact",
            "--slug",
            slug,
            "--about",
            "code:src/calendar-widget/index.tsx:1-50,code:src/calendar-widget/v12-state.ts",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"failed: stderr={result.stderr}"
    out = json.loads(result.output)
    assert out["fact_id"] == slug

    # File written + committed
    fact_path = repo / ".rlm" / "facts" / f"{slug}.md"
    assert fact_path.exists()
    content = fact_path.read_text(encoding="utf-8")
    assert "type: fact" in content
    assert f"fact_id: {slug}" in content
    assert "status: active" in content
    assert "Calendar widget reverted to v1.2" in content

    # Committed on the wp/* branch (not main)
    log = sp.run(
        ["git", "log", "--oneline", "wp/144-revert-calendar"],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )
    assert f"fact: {slug}" in log.stdout

    # No push happened (Worker doesn't push; open-pr will)
    assert pushes == []


def test_supersede_fact_atomically_edits_old_writes_new(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """First append-fact, then supersede-fact (same day, different slug)."""
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]

    _checkout_wp_branch(repo, "wp/200-scaffold-bump")
    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_super")

    today = datetime.now(timezone.utc).date().isoformat()
    old_slug = f"{today}-scaffold-v1"
    new_slug = f"{today}-scaffold-v2"

    # Step 1: append the old fact
    body_old = _write(repo / "old.md", "Next.js 13 scaffold.\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "append-fact",
            "--slug",
            old_slug,
            "--about",
            "code:package.json:1-30",
            "--body-file",
            str(body_old),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"append-fact failed: {result.stderr}"

    # Step 2: supersede with the new fact
    body_new = _write(repo / "new.md", "Next.js 14 scaffold (upgraded from v13).\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "supersede-fact",
            "--slug",
            new_slug,
            "--supersedes",
            old_slug,
            "--about",
            "code:package.json:1-30",
            "--body-file",
            str(body_new),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"supersede-fact failed: {result.stderr}"
    out = json.loads(result.output)
    assert out["fact_id"] == new_slug
    assert out["supersedes"] == old_slug

    # New fact exists, references old
    new_path = repo / ".rlm" / "facts" / f"{new_slug}.md"
    old_path = repo / ".rlm" / "facts" / f"{old_slug}.md"
    new_content = new_path.read_text(encoding="utf-8")
    old_content = old_path.read_text(encoding="utf-8")

    assert f"supersedes: {old_slug}" in new_content
    assert new_content.count("status: active") == 1  # new is active

    # Old fact's frontmatter updated
    assert f"superseded_by: {new_slug}" in old_content
    assert "status: superseded" in old_content
    assert "status: active" not in old_content  # old no longer active

    # Both changes in one commit
    log = sp.run(
        ["git", "log", "-1", "--name-only", "--format=%s"],
        cwd=repo,
        check=True,
        capture_output=True,
        text=True,
    )
    assert f"fact: {new_slug} (supersedes {old_slug})" in log.stdout
    assert f".rlm/facts/{new_slug}.md" in log.stdout
    assert f".rlm/facts/{old_slug}.md" in log.stdout


def test_supersede_fact_refuses_already_superseded(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    repo: Path = git_runner_env["repo"]
    _checkout_wp_branch(repo, "wp/300-cleanup")
    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_double_supersede")

    today = datetime.now(timezone.utc).date().isoformat()

    # First chain: A → B
    body = _write(repo / "b.md", "First.\n")
    runner.invoke(
        main,
        [
            "--json",
            "append-fact",
            "--slug",
            f"{today}-a",
            "--about",
            "code:foo",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    runner.invoke(
        main,
        [
            "--json",
            "supersede-fact",
            "--slug",
            f"{today}-b",
            "--supersedes",
            f"{today}-a",
            "--about",
            "code:foo",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )

    # Now attempt to supersede A again (with C) — should fail
    body_c = _write(repo / "c.md", "Third.\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "supersede-fact",
            "--slug",
            f"{today}-c",
            "--supersedes",
            f"{today}-a",
            "--about",
            "code:foo",
            "--body-file",
            str(body_c),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 6  # precondition-failed
    err = json.loads(result.stderr)
    assert "already superseded" in err["message"]
