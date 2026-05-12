"""mark-delivered — flip WorkPackage to status:delivered after PR merged + CI check passed.

See .rlm/contracts/rlm-cli.md § Detailed: mark-delivered.
"""

from __future__ import annotations

import click

from rlm.adapters import gh
from rlm.errors import PreconditionFailedError
from rlm.runner import SubcommandRun

CI_CHECK_NAME = "rlm/fact-commit-required"


def _find_closing_pr(issue_num: int) -> int:
    """Return the PR number that closes this Issue. Raises if none / multiple."""
    data = gh.issue_view(issue_num, fields=["number", "labels", "closedByPullRequestsReferences"])
    refs = data.get("closedByPullRequestsReferences", []) or []
    if not refs:
        raise PreconditionFailedError(
            f"Issue #{issue_num} has no closing PR yet — cannot mark-delivered",
            subcommand="mark-delivered",
        )
    if len(refs) > 1:
        # Use the most recent (highest number) — Dispatch should never see this
        # in v1 since one WP → one PR, but be defensive.
        return max(int(r["number"]) for r in refs if "number" in r)
    return int(refs[0]["number"])


def _verify_pr_merged_and_check_passed(pr_num: int) -> None:
    pr = gh.pr_view(pr_num, fields=["number", "mergedAt", "state", "statusCheckRollup"])
    merged_at = pr.get("mergedAt")
    if not merged_at:
        raise PreconditionFailedError(
            f"PR #{pr_num} is not merged yet — mark-delivered requires PR merge first",
            subcommand="mark-delivered",
            details={"pr_state": pr.get("state")},
        )

    rollup = pr.get("statusCheckRollup") or []
    matched: list[dict] = []
    for entry in rollup:
        name = entry.get("name", "")
        if name == CI_CHECK_NAME or name.replace(" ", "") == CI_CHECK_NAME:
            matched.append(entry)

    if not matched:
        raise PreconditionFailedError(
            f"PR #{pr_num} is missing the required CI check {CI_CHECK_NAME!r} "
            "(see .github/workflows/fact-commit-check.yml)",
            subcommand="mark-delivered",
            details={
                "required_check": CI_CHECK_NAME,
                "rollup_names": [e.get("name") for e in rollup],
            },
        )

    for entry in matched:
        conclusion = (entry.get("conclusion") or "").upper()
        if conclusion != "SUCCESS":
            raise PreconditionFailedError(
                f"CI check {CI_CHECK_NAME!r} did not pass on PR #{pr_num}: conclusion={conclusion!r}",
                subcommand="mark-delivered",
                details={"check": entry},
            )


@click.command("mark-delivered")
@click.option("--issue", "issue_num", required=True, type=int, help="WorkPackage Issue number")
@click.pass_context
def cmd(ctx: click.Context, issue_num: int) -> None:
    """Flip WP status:in_progress → status:delivered. Caller: dispatch."""
    with SubcommandRun(ctx, "mark-delivered") as run:
        key = ("issue", issue_num, "to", "delivered")
        if run.cache_get(key):
            return

        # Verify Issue is type:workpackage status:in_progress
        data = gh.issue_view(issue_num, fields=["number", "labels"])
        labels = {entry["name"] for entry in data.get("labels", []) if "name" in entry}
        if "type:workpackage" not in labels:
            raise PreconditionFailedError(
                f"Issue #{issue_num} is not type:workpackage",
                subcommand="mark-delivered",
                details={"actual_labels": sorted(labels)},
            )

        # Idempotent: if already delivered, no-op via runner cache
        if "status:delivered" in labels:
            run.set_result(ok=True, issue=issue_num, status="delivered", idempotent=True)
            return

        # PR must be merged + CI check passed
        pr_num = _find_closing_pr(issue_num)
        _verify_pr_merged_and_check_passed(pr_num)

        run.add_basis("issue", f"#{issue_num}")
        run.add_basis("pr", f"#{pr_num}")
        run.reasoning = (
            f"delivering WP #{issue_num} after PR #{pr_num} merged + CI {CI_CHECK_NAME!r} passed"
        )

        if run.dry_run:
            run.set_result(ok=True, dry_run=True, would_deliver_issue=issue_num, closing_pr=pr_num)
            return

        # Remove status:in_progress + all agent:* labels; add status:delivered
        agent_labels = [label for label in labels if label.startswith("agent:")]
        remove = ["status:in_progress", *agent_labels]
        # If somehow not at in_progress (manual relabel?), tolerate but log
        if "status:in_progress" not in labels:
            remove = [label for label in remove if label != "status:in_progress"]
            # Also remove any other status:* the issue currently carries (except delivered)
            for label in labels:
                if (
                    label.startswith("status:")
                    and label != "status:delivered"
                    and label not in remove
                ):
                    remove.append(label)

        gh.issue_edit(issue_num, add_labels=["status:delivered"], remove_labels=remove)

        run.add_affected("issue", f"#{issue_num}", "relabeled")
        run.set_result(
            ok=True,
            issue=issue_num,
            status="delivered",
            closing_pr=pr_num,
        )
