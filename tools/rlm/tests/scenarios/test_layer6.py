"""Layer 6 (hardest) scenarios:
  - approve-workpackage with adr_refs mechanical verification
  - mark-delivered with PR-merge + CI-check verification
  - open-pr with branch + fact-commit verification

All tests use git_runner_env (real git on tmp dir + fake_github + mocked push).
"""

from __future__ import annotations

import json
import subprocess as sp
from datetime import datetime, timezone
from pathlib import Path

import pytest
from click.testing import CliRunner

from rlm.cli import main


def _write(p: Path, content: str) -> Path:
    p.write_text(content, encoding="utf-8")
    return p


def _commit_adr_to_main(repo: Path, n: int, slug: str) -> None:
    """Stage + commit an ADR file directly on main of the tmp git repo."""
    adr_dir = repo / ".rlm" / "adr"
    adr_dir.mkdir(parents=True, exist_ok=True)
    (adr_dir / f"{n:04d}-{slug}.md").write_text(
        f"# ADR-{n:04d} {slug}\n\nDecision.\n", encoding="utf-8"
    )
    sp.run(["git", "add", "-A"], cwd=repo, check=True, capture_output=True)
    sp.run(
        ["git", "commit", "-m", f"adr: {n:04d}-{slug}"],
        cwd=repo,
        check=True,
        capture_output=True,
    )


# =========================================================================
# approve-workpackage
# =========================================================================


def _wp_body_with_adr_refs(adr_refs: list[int]) -> str:
    """Build a minimal WP Issue body with frontmatter carrying adr_refs."""
    refs_yaml = "[]" if not adr_refs else "[" + ", ".join(str(n) for n in adr_refs) + "]"
    return (
        f"---\n"
        f"type: workpackage\n"
        f"status: draft\n"
        f"parent_spec: 1\n"
        f"adr_refs: {refs_yaml}\n"
        f"depends_on: []\n"
        f"---\n\n"
        f"# X\n\n## AcceptanceCriteria\n\n- [ ] something\n"
    )


def test_approve_workpackage_happy_path(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = git_runner_env["github"]
    repo: Path = git_runner_env["repo"]

    # Stage both ADRs on main of tmp_git_repo
    _commit_adr_to_main(repo, 1, "foo")
    _commit_adr_to_main(repo, 2, "bar")

    wp_num = fake_gh.add_issue(
        title="WP referencing both ADRs",
        body=_wp_body_with_adr_refs([1, 2]),
        labels=["type:workpackage", "status:draft"],
    )

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_approve_happy")

    result = runner.invoke(
        main,
        ["--json", "approve-workpackage", "--issue", str(wp_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"approve failed: {result.stderr}"
    out = json.loads(result.output)
    assert out["status"] == "approved"
    assert out["adr_refs_verified"] == [1, 2]

    wp = fake_gh.issues[wp_num]
    assert "status:approved" in wp.labels
    assert "status:draft" not in wp.labels


def test_approve_workpackage_blocks_on_unmerged_adr(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = git_runner_env["github"]
    repo: Path = git_runner_env["repo"]

    # Only commit ADR #1 to main; #3 is "still in a PR" (unmerged)
    _commit_adr_to_main(repo, 1, "foo")

    wp_num = fake_gh.add_issue(
        title="WP referencing unmerged ADR",
        body=_wp_body_with_adr_refs([1, 3]),
        labels=["type:workpackage", "status:draft"],
    )

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_approve_block")

    result = runner.invoke(
        main,
        ["--json", "approve-workpackage", "--issue", str(wp_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 6, f"expected precondition-failed, got: {result.output}"
    err = json.loads(result.stderr)
    assert err["error"] == "precondition-failed"
    assert err["details"]["unmerged"] == [3]

    # WP still draft — was not flipped
    wp = fake_gh.issues[wp_num]
    assert "status:draft" in wp.labels
    assert "status:approved" not in wp.labels


def test_approve_workpackage_no_adr_refs_works(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """A WP with empty adr_refs approves without any ADR check."""
    runner = CliRunner()
    fake_gh = git_runner_env["github"]

    wp_num = fake_gh.add_issue(
        title="WP no ADRs",
        body=_wp_body_with_adr_refs([]),
        labels=["type:workpackage", "status:draft"],
    )

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_approve_empty")

    result = runner.invoke(
        main,
        ["--json", "approve-workpackage", "--issue", str(wp_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 0
    assert "status:approved" in fake_gh.issues[wp_num].labels


# =========================================================================
# mark-delivered
# =========================================================================


def test_mark_delivered_happy(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = git_runner_env["github"]

    wp_num = fake_gh.add_issue(
        title="WP in progress",
        body="x",
        labels=["type:workpackage", "status:in_progress", "agent:human-review"],
    )
    # Closing PR with our exact head-branch naming convention so fake_github's
    # heuristic links them (head contains "-<wp_num>" or ends with "-<wp_num>").
    pr_num = fake_gh.add_pr(head=f"wp/{wp_num}-revert", title="X", merged=True)

    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_deliver")

    result = runner.invoke(
        main,
        ["--json", "mark-delivered", "--issue", str(wp_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"mark-delivered failed: {result.stderr}"
    out = json.loads(result.output)
    assert out["status"] == "delivered"
    assert out["closing_pr"] == pr_num

    wp = fake_gh.issues[wp_num]
    assert "status:delivered" in wp.labels
    assert "status:in_progress" not in wp.labels
    assert "agent:human-review" not in wp.labels  # all agent:* removed


def test_mark_delivered_blocks_if_pr_not_merged(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = git_runner_env["github"]

    wp_num = fake_gh.add_issue(
        title="WP", body="", labels=["type:workpackage", "status:in_progress"]
    )
    fake_gh.add_pr(head=f"wp/{wp_num}-foo", title="X", merged=False)

    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_deliver_unmerged")

    result = runner.invoke(
        main, ["--json", "mark-delivered", "--issue", str(wp_num)], catch_exceptions=False
    )
    assert result.exit_code == 6
    err = json.loads(result.stderr)
    assert err["error"] == "precondition-failed"
    assert "not merged" in err["message"]


def test_mark_delivered_blocks_if_no_closing_pr(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = git_runner_env["github"]

    wp_num = fake_gh.add_issue(
        title="WP", body="", labels=["type:workpackage", "status:in_progress"]
    )
    # No PR created — closing PR lookup returns empty

    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_deliver_no_pr")

    result = runner.invoke(
        main, ["--json", "mark-delivered", "--issue", str(wp_num)], catch_exceptions=False
    )
    assert result.exit_code == 6
    err = json.loads(result.stderr)
    assert "no closing PR" in err["message"]


# =========================================================================
# open-pr
# =========================================================================


def _checkout_wp_branch(repo: Path, branch: str) -> None:
    sp.run(["git", "checkout", "-b", branch], cwd=repo, check=True, capture_output=True)


def _today_slug(suffix: str = "x") -> str:
    return f"{datetime.now(timezone.utc).date().isoformat()}-{suffix}"


def test_open_pr_happy(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = git_runner_env["github"]
    repo: Path = git_runner_env["repo"]
    pushes: list[dict] = git_runner_env["pushes"]

    wp_num = fake_gh.add_issue(
        title="Revert calendar widget",
        body="x",
        labels=["type:workpackage", "status:in_progress", "agent:worker"],
    )
    branch = f"wp/{wp_num}-revert-calendar"
    _checkout_wp_branch(repo, branch)

    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_worker_open_pr")

    # First: write a fact commit on the branch
    fact_body = _write(repo / "fact.md", "Calendar widget reverted.\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "append-fact",
            "--slug",
            _today_slug("calendar-revert"),
            "--about",
            "code:src/calendar-widget/",
            "--body-file",
            str(fact_body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0

    # Then: open the PR
    pr_body = _write(repo / "pr.md", "Reverts widget to v1.2.\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "open-pr",
            "--issue",
            str(wp_num),
            "--branch",
            branch,
            "--title",
            "Revert calendar widget to v1.2",
            "--body-file",
            str(pr_body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"open-pr failed: {result.stderr}"
    out = json.loads(result.output)
    pr_num = out["pr_number"]

    # Branch pushed
    assert any(p["branch"] == branch for p in pushes)

    # PR exists + body has `closes #N`
    pr = fake_gh.prs[pr_num]
    assert pr.head == branch
    assert pr.base == "main"
    assert f"closes #{wp_num}" in pr.body

    # Comment posted on WP issue
    wp = fake_gh.issues[wp_num]
    assert any(f"PR #{pr_num} opened by Worker" in c for c in wp.comments)


def test_open_pr_blocks_without_fact_commit(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = git_runner_env["github"]
    repo: Path = git_runner_env["repo"]

    wp_num = fake_gh.add_issue(
        title="WP",
        body="",
        labels=["type:workpackage", "status:in_progress", "agent:worker"],
    )
    branch = f"wp/{wp_num}-something"
    _checkout_wp_branch(repo, branch)

    # Make a commit that ISN'T a fact: commit
    (repo / "src.txt").write_text("code\n", encoding="utf-8")
    sp.run(["git", "add", "-A"], cwd=repo, check=True, capture_output=True)
    sp.run(
        ["git", "commit", "-m", "feat: something not a fact"],
        cwd=repo,
        check=True,
        capture_output=True,
    )

    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_no_fact")

    pr_body = _write(repo / "pr.md", "PR.\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "open-pr",
            "--issue",
            str(wp_num),
            "--branch",
            branch,
            "--title",
            "X",
            "--body-file",
            str(pr_body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 6
    err = json.loads(result.stderr)
    assert err["error"] == "precondition-failed"
    assert "fact:" in err["message"]


def test_open_pr_rejects_branch_mismatch(
    git_runner_env: dict,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """--branch encodes a different WP number than --issue."""
    runner = CliRunner()
    fake_gh = git_runner_env["github"]
    repo: Path = git_runner_env["repo"]

    wp_num = fake_gh.add_issue(
        title="WP",
        body="",
        labels=["type:workpackage", "status:in_progress", "agent:worker"],
    )
    other_num = 999
    branch = f"wp/{other_num}-mismatched"
    _checkout_wp_branch(repo, branch)

    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_mismatch")

    body = _write(repo / "b.md", "x")
    result = runner.invoke(
        main,
        [
            "--json",
            "open-pr",
            "--issue",
            str(wp_num),
            "--branch",
            branch,
            "--title",
            "X",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 2
    err = json.loads(result.stderr)
    assert err["error"] == "validation-error"
