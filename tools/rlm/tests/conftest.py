"""Test fixtures for rlm-cli."""

from __future__ import annotations

import dataclasses
from collections.abc import Generator
from pathlib import Path
from typing import Any

import pytest

# ---- Repo fixtures ----


@pytest.fixture
def tmp_rlm_repo(tmp_path: Path) -> Path:
    """A temporary repo root with a minimal `.rlm/` skeleton.

    Mirrors `D:/darfts/.rlm/` shape enough for subcommand tests.
    """
    rlm = tmp_path / ".rlm"
    rlm.mkdir()
    (rlm / "adr").mkdir()
    (rlm / "contracts").mkdir()
    (rlm / "facts").mkdir()
    (rlm / "business").mkdir()
    (rlm / "bc" / "intake").mkdir(parents=True)
    (rlm / "bc" / "design").mkdir()
    (rlm / "bc" / "delivery").mkdir()

    (rlm / "CONTEXT-MAP.md").write_text("# Test CONTEXT-MAP\n", encoding="utf-8")
    (rlm / "bc" / "intake" / "CONTEXT.md").write_text("# Intake\n", encoding="utf-8")

    return tmp_path


# ---- Env-var fixtures ----


@pytest.fixture
def clean_env(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    """Strip RLM_* and REDIS_URL env vars."""
    for k in ("RLM_AGENT_ROLE", "RLM_AGENT_INVOCATION", "RLM_SKILL_NAME", "REDIS_URL"):
        monkeypatch.delenv(k, raising=False)
    yield


@pytest.fixture
def as_worker(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_worker_001")


@pytest.fixture
def as_hermes(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_hermes_001")
    monkeypatch.setenv("RLM_SKILL_NAME", "signal-to-spec")


@pytest.fixture
def as_hermes_design(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_design_001")
    monkeypatch.setenv("RLM_SKILL_NAME", "decompose-spec")


@pytest.fixture
def as_dispatch(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_dispatch_001")


# ---- FakeGitHub fixture ----
#
# Replaces `rlm.adapters.gh._run_gh` with an in-memory implementation. Tests
# inject via the `fake_github` fixture which auto-monkeypatches.


@dataclasses.dataclass
class FakeIssue:
    number: int
    title: str
    body: str
    labels: set[str]
    comments: list[str] = dataclasses.field(default_factory=list)
    state: str = "open"


@dataclasses.dataclass
class FakePR:
    number: int
    head: str
    base: str
    title: str
    body: str
    state: str = "open"
    merged: bool = False


def _parse_flag_args(args: list[str], single: set[str], repeatable: set[str]) -> dict[str, Any]:
    """Parse `--name value` style flags. Single flags overwrite; repeatable accumulate."""
    out: dict[str, Any] = {k: None for k in single}
    for k in repeatable:
        out[k] = []
    it = iter(args)
    for arg in it:
        if arg in single:
            out[arg] = next(it)
        elif arg in repeatable:
            out[arg].append(next(it))
    return out


class FakeGitHub:
    """In-memory mock of `gh issue/pr` operations. Inject via monkeypatch.

    Test usage:

        def test_thing(fake_github):
            # pre-populate if needed
            fake_github.add_issue(title="...", labels=["type:spec", "status:confirmed"])
            # run subcommand
            ...
            # assert
            assert fake_github.issues[1].labels == {"type:spec", "status:confirmed"}
    """

    def __init__(self) -> None:
        self.issues: dict[int, FakeIssue] = {}
        self.prs: dict[int, FakePR] = {}
        self._next_issue = 1
        self._next_pr = 1

    # ---- Test helpers ----

    def add_issue(
        self,
        *,
        title: str,
        body: str = "",
        labels: list[str] | None = None,
        state: str = "open",
    ) -> int:
        num = self._next_issue
        self._next_issue += 1
        self.issues[num] = FakeIssue(
            number=num,
            title=title,
            body=body,
            labels=set(labels or []),
            state=state,
        )
        return num

    def add_pr(
        self,
        *,
        head: str,
        base: str = "main",
        title: str,
        body: str = "",
        merged: bool = False,
    ) -> int:
        num = self._next_pr
        self._next_pr += 1
        self.prs[num] = FakePR(
            number=num,
            head=head,
            base=base,
            title=title,
            body=body,
            merged=merged,
            state="merged" if merged else "open",
        )
        return num

    # ---- The dispatch entry point — used by monkeypatch ----

    def dispatch(self, args: list[str], *, json_fields: list[str] | None = None) -> Any:
        """Mirrors rlm.adapters.gh._run_gh signature."""
        if len(args) < 2:
            raise RuntimeError(f"FakeGitHub: short args {args}")
        cmd = (args[0], args[1])

        if cmd == ("issue", "create"):
            return self._issue_create(args[2:])
        if cmd == ("issue", "view"):
            return self._issue_view(args[2:], json_fields)
        if cmd == ("issue", "edit"):
            return self._issue_edit(args[2:])
        if cmd == ("issue", "comment"):
            return self._issue_comment(args[2:])
        if cmd == ("issue", "list"):
            return self._issue_list(args[2:], json_fields)
        if cmd == ("pr", "create"):
            return self._pr_create(args[2:])
        if cmd == ("pr", "view"):
            return self._pr_view(args[2:], json_fields)

        raise RuntimeError(f"FakeGitHub: unhandled args {args}")

    # ---- issue create ----

    def _issue_create(self, args: list[str]) -> str:
        parsed = _parse_flag_args(
            args,
            single={"--title", "--body"},
            repeatable={"--label", "--assignee"},
        )
        num = self.add_issue(
            title=parsed["--title"] or "",
            body=parsed["--body"] or "",
            labels=parsed["--label"],
        )
        return f"https://github.com/fake/fake/issues/{num}"

    # ---- issue view ----

    def _issue_view(self, args: list[str], json_fields: list[str] | None) -> dict[str, Any]:
        number = int(args[0])
        if number not in self.issues:
            raise RuntimeError(f"FakeGitHub: issue #{number} not found")
        issue = self.issues[number]
        out: dict[str, Any] = {}
        fields = set(json_fields or [])
        if "number" in fields:
            out["number"] = issue.number
        if "title" in fields:
            out["title"] = issue.title
        if "body" in fields:
            out["body"] = issue.body
        if "state" in fields:
            out["state"] = issue.state
        if "labels" in fields:
            out["labels"] = [{"name": name} for name in sorted(issue.labels)]
        if "comments" in fields:
            out["comments"] = [{"body": c} for c in issue.comments]
        if "closedByPullRequestsReferences" in fields:
            # Simple heuristic for tests: PR head branch contains the issue number
            out["closedByPullRequestsReferences"] = [
                {"number": pr.number}
                for pr in self.prs.values()
                if f"-{number}-" in pr.head or pr.head.endswith(f"-{number}")
            ]
        return out

    # ---- issue edit ----

    def _issue_edit(self, args: list[str]) -> str:
        number = int(args[0])
        if number not in self.issues:
            raise RuntimeError(f"FakeGitHub: issue #{number} not found")
        issue = self.issues[number]
        parsed = _parse_flag_args(
            args[1:],
            single={"--body"},
            repeatable={"--add-label", "--remove-label"},
        )
        for label in parsed["--add-label"]:
            issue.labels.add(label)
        for label in parsed["--remove-label"]:
            issue.labels.discard(label)
        if parsed["--body"] is not None:
            issue.body = parsed["--body"]
        return ""

    # ---- issue comment ----

    def _issue_comment(self, args: list[str]) -> str:
        number = int(args[0])
        if number not in self.issues:
            raise RuntimeError(f"FakeGitHub: issue #{number} not found")
        parsed = _parse_flag_args(args[1:], single={"--body"}, repeatable=set())
        body = parsed["--body"] or ""
        self.issues[number].comments.append(body)
        return ""

    # ---- issue list ----

    def _issue_list(self, args: list[str], json_fields: list[str] | None) -> list[dict[str, Any]]:
        parsed = _parse_flag_args(
            args,
            single={"--state", "--search"},
            repeatable={"--label"},
        )
        state_filter = parsed["--state"] or "open"
        label_filter = set(parsed["--label"])
        search = (parsed["--search"] or "").lower()

        results: list[dict[str, Any]] = []
        for issue in self.issues.values():
            if state_filter != "all" and issue.state != state_filter:
                continue
            if label_filter and not label_filter.issubset(issue.labels):
                continue
            if search and search not in (issue.title.lower() + " " + issue.body.lower()):
                continue
            results.append(
                self._issue_view([str(issue.number)], json_fields or ["number", "title", "labels"])
            )
        return results

    # ---- PR create / view ----

    def _pr_create(self, args: list[str]) -> str:
        parsed = _parse_flag_args(
            args,
            single={"--title", "--body", "--head", "--base"},
            repeatable=set(),
        )
        num = self.add_pr(
            head=parsed["--head"] or "",
            base=parsed["--base"] or "main",
            title=parsed["--title"] or "",
            body=parsed["--body"] or "",
        )
        return f"https://github.com/fake/fake/pull/{num}"

    def _pr_view(self, args: list[str], json_fields: list[str] | None) -> dict[str, Any]:
        number = int(args[0])
        if number not in self.prs:
            raise RuntimeError(f"FakeGitHub: PR #{number} not found")
        pr = self.prs[number]
        out: dict[str, Any] = {}
        fields = set(json_fields or [])
        if "number" in fields:
            out["number"] = pr.number
        if "title" in fields:
            out["title"] = pr.title
        if "body" in fields:
            out["body"] = pr.body
        if "state" in fields:
            out["state"] = pr.state
        if "merged" in fields or "mergedAt" in fields:
            out["mergedAt"] = "2026-05-12T10:00:00Z" if pr.merged else None
        if "url" in fields:
            out["url"] = f"https://github.com/fake/fake/pull/{pr.number}"
        if "statusCheckRollup" in fields:
            out["statusCheckRollup"] = [
                {
                    "name": "rlm/fact-commit-required",
                    "conclusion": "SUCCESS" if pr.merged else "NEUTRAL",
                }
            ]
        return out


@pytest.fixture
def fake_github(monkeypatch: pytest.MonkeyPatch) -> FakeGitHub:
    """In-memory GitHub backend. Auto-patches `rlm.adapters.gh._run_gh`."""
    fake = FakeGitHub()

    def _patched(args: list[str], *, json_fields: list[str] | None = None) -> Any:
        # Also patch shutil.which("gh") side: skip the availability check by stubbing
        return fake.dispatch(args, json_fields=json_fields)

    # Patch the underlying subprocess wrapper
    monkeypatch.setattr("rlm.adapters.gh._run_gh", _patched)
    # And patch shutil.which so the availability check passes
    monkeypatch.setattr("rlm.adapters.gh._ensure_gh_available", lambda: None)

    return fake


# ---- Combined fixture: a temp repo + fake_github + a clean env ----


@pytest.fixture
def runner_env(
    tmp_rlm_repo: Path,
    fake_github: FakeGitHub,
    clean_env: None,
    monkeypatch: pytest.MonkeyPatch,
) -> Generator[dict[str, Any], None, None]:
    """Bundles tmp_rlm_repo + fake_github + clean env. Tests that exercise
    multiple subcommand chains use this."""
    # Chdir into the tmp repo so walk-up works
    monkeypatch.chdir(tmp_rlm_repo)
    yield {"repo": tmp_rlm_repo, "github": fake_github}


# ---- Real-git fixtures (for Layer 4 direct-commit + Layer 5 PR-routed) ----
#
# Strategy (Path 3 hybrid): real git on tmp dir + mocked push + fake gh.
# This way `git add` / `git commit` / `git checkout` really run, but `git push`
# is intercepted (no real remote needed).


@pytest.fixture
def tmp_git_repo(tmp_rlm_repo: Path) -> Path:
    """Init a real git repo on top of tmp_rlm_repo:
      - main branch with an initial commit containing the .rlm/ skeleton
      - bare origin remote (so `origin/main` exists as a local ref;
        checkout -B branch origin/main works without a real GitHub)
    Push to origin is mocked separately by `captured_pushes`.
    """
    import subprocess as sp

    repo = tmp_rlm_repo
    sp.run(["git", "init", "-b", "main"], cwd=repo, check=True, capture_output=True)
    sp.run(
        ["git", "config", "user.email", "test@rlm.local"],
        cwd=repo,
        check=True,
        capture_output=True,
    )
    sp.run(
        ["git", "config", "user.name", "Test"],
        cwd=repo,
        check=True,
        capture_output=True,
    )
    sp.run(
        ["git", "config", "commit.gpgsign", "false"],
        cwd=repo,
        check=True,
        capture_output=True,
    )
    sp.run(["git", "add", "-A"], cwd=repo, check=True, capture_output=True)
    sp.run(
        ["git", "commit", "-m", "init"],
        cwd=repo,
        check=True,
        capture_output=True,
    )

    # Create a bare clone next to the repo to serve as `origin`.
    # This makes `origin/main` exist as a local remote-tracking ref so that
    # `git checkout -B foo origin/main` succeeds without hitting any network.
    # Use a per-test name (repo.name) so concurrent / sequential tests don't
    # collide on the shared pytest tmp-parent.
    bare = repo.parent / f"origin-{repo.name}.git"
    sp.run(
        ["git", "clone", "--bare", str(repo), str(bare)],
        check=True,
        capture_output=True,
    )
    sp.run(
        ["git", "remote", "add", "origin", str(bare)],
        cwd=repo,
        check=True,
        capture_output=True,
    )
    sp.run(
        ["git", "fetch", "origin"],
        cwd=repo,
        check=True,
        capture_output=True,
    )
    return repo


@pytest.fixture
def captured_pushes(monkeypatch: pytest.MonkeyPatch) -> list[dict[str, Any]]:
    """Monkeypatch git.push to record calls instead of actually pushing.

    The bare origin in `tmp_git_repo` does not need pushed updates — tests
    inspect the local tmp_git_repo's branches + the recorded push calls.
    """
    pushes: list[dict[str, Any]] = []

    def fake_push(branch: str, *, remote: str = "origin", cwd: Path | None = None) -> None:
        pushes.append({"branch": branch, "remote": remote, "cwd": str(cwd) if cwd else None})

    monkeypatch.setattr("rlm.adapters.git.push", fake_push)
    return pushes


@pytest.fixture
def git_runner_env(
    tmp_git_repo: Path,
    fake_github: FakeGitHub,
    captured_pushes: list[dict[str, Any]],
    clean_env: None,
    monkeypatch: pytest.MonkeyPatch,
) -> Generator[dict[str, Any], None, None]:
    """Real-git + fake_github + push-mocked. Used by Layer 4 / 5 tests."""
    monkeypatch.chdir(tmp_git_repo)
    yield {"repo": tmp_git_repo, "github": fake_github, "pushes": captured_pushes}
