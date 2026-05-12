"""open-pr — Worker opens the PR for its WorkPackage branch.

See .rlm/contracts/rlm-cli.md § Detailed: open-pr.

Worker preconditions (verified by this CLI):
  - branch matches `wp/<num>-<slug>` pattern
  - branch exists locally
  - branch contains ≥1 `fact: ...` commit (from append-fact / supersede-fact)
"""

from __future__ import annotations

import re
from pathlib import Path

import click

from rlm.adapters import gh, git
from rlm.errors import PreconditionFailedError, ValidationError
from rlm.routing import issue as issue_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg

_WP_BRANCH_RE = re.compile(r"^wp/(\d+)-[a-z0-9][a-z0-9-]*$")


def _validate_branch_for_issue(branch: str, issue_num: int) -> None:
    m = _WP_BRANCH_RE.match(branch)
    if not m:
        raise ValidationError(
            f"--branch must match wp/<num>-<slug> (e.g., wp/144-revert-calendar); got {branch!r}",
            field="branch",
        )
    branch_issue = int(m.group(1))
    if branch_issue != issue_num:
        raise ValidationError(
            f"branch encodes WP #{branch_issue} but --issue is #{issue_num}",
            field="branch",
            details={"branch_issue": branch_issue, "flag_issue": issue_num},
        )


def _ensure_branch_has_fact_commit(branch: str, repo_root: Path) -> None:
    if not git.branch_exists(branch, cwd=repo_root):
        raise PreconditionFailedError(
            f"Branch {branch!r} does not exist locally",
            subcommand="open-pr",
        )
    messages = git.list_branch_commits(branch, base="main", cwd=repo_root)
    if not messages:
        raise PreconditionFailedError(
            f"Branch {branch!r} has no commits ahead of main",
            subcommand="open-pr",
        )
    if not any(msg.startswith("fact:") for msg in messages):
        raise PreconditionFailedError(
            f"Branch {branch!r} has no `fact:` commit — Worker must call rlm append-fact "
            "(or supersede-fact) before open-pr",
            subcommand="open-pr",
            details={"commit_messages": messages},
        )


@click.command("open-pr")
@click.option("--issue", "issue_num", required=True, type=int, help="WorkPackage Issue number")
@click.option("--branch", required=True, help="branch name (must match wp/<num>-<slug> pattern)")
@click.option("--title", required=True, help="PR title (Worker's summary)")
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="PR body markdown",
)
@click.option("--body", help="inline PR body")
@click.pass_context
def cmd(
    ctx: click.Context,
    issue_num: int,
    branch: str,
    title: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Push branch + open PR + comment on WP Issue. Caller: worker."""
    with SubcommandRun(ctx, "open-pr") as run:
        body_content = read_body_arg(body_file, body)
        _validate_branch_for_issue(branch, issue_num)

        # Idempotency: by branch
        key = ("branch", branch)
        ch = content_hash(branch, str(issue_num), title, body_content)
        if run.cache_get(key, ch):
            return

        # Verify Issue is type:workpackage status:in_progress
        data = issue_route.verify_issue_exists(issue_num, expected_type="workpackage")
        labels = {entry["name"] for entry in data.get("labels", []) if "name" in entry}
        if "status:in_progress" not in labels:
            raise PreconditionFailedError(
                f"WP #{issue_num} is not status:in_progress",
                subcommand="open-pr",
                details={"actual_labels": sorted(labels)},
            )

        _ensure_branch_has_fact_commit(branch, run.repo_root)

        # Ensure body contains the closing reference
        full_body = body_content
        closes_marker = f"closes #{issue_num}"
        if closes_marker not in full_body:
            full_body = f"{full_body.rstrip()}\n\n{closes_marker}\n"

        run.add_basis("issue", f"#{issue_num}")
        run.add_basis("commit", "branch-fact-commits")
        run.reasoning = f"opening Worker PR for WP #{issue_num} from branch {branch}"

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_open_pr_for_branch=branch,
                issue=issue_num,
            )
            return

        # Push the branch
        git.push(branch, cwd=run.repo_root)

        # Open the PR
        pr_num = gh.pr_create(head=branch, base="main", title=title, body=full_body)
        pr_view = gh.pr_view(pr_num, fields=["url"])
        pr_url = str(pr_view.get("url", ""))

        # Comment on the WP Issue
        gh.issue_comment(issue_num, f"PR #{pr_num} opened by Worker from `{branch}`.")

        run.add_affected("pr", f"#{pr_num}", "opened")
        run.add_affected("issue", f"#{issue_num}", "commented")
        run.set_result(
            ok=True,
            issue=issue_num,
            branch=branch,
            pr_number=pr_num,
            pr_url=pr_url,
        )
