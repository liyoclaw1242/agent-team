"""mark-in-progress — flip WorkPackage to status:in_progress + agent:worker.

See .rlm/contracts/rlm-cli.md § Detailed: mark-in-progress.
"""

from __future__ import annotations

import click

from rlm.errors import PreconditionFailedError, ValidationError
from rlm.routing import issue as issue_route
from rlm.runner import SubcommandRun


@click.command("mark-in-progress")
@click.option("--issue", "issue_num", required=True, type=int, help="WorkPackage Issue number")
@click.pass_context
def cmd(ctx: click.Context, issue_num: int) -> None:
    """Flip WP status:approved → status:in_progress + add agent:worker. Caller: dispatch."""
    with SubcommandRun(ctx, "mark-in-progress") as run:
        key = ("issue", issue_num, "to", "in_progress")
        cached = run.cache_get(key)
        if cached:
            return

        try:
            issue_route.verify_issue_exists(issue_num, expected_type="workpackage")
        except ValidationError as e:
            raise PreconditionFailedError(
                e.message, subcommand="mark-in-progress", details=e.details
            ) from e

        run.add_basis("issue", f"#{issue_num}")
        run.reasoning = f"Dispatch picking up WP #{issue_num} for Worker"

        if run.dry_run:
            run.set_result(ok=True, dry_run=True, would_advance_issue=issue_num)
            return

        issue_route.flip_status(
            issue_number=issue_num,
            from_status="approved",
            to_status="in_progress",
            require_type="workpackage",
            extra_add_labels=["agent:worker"],
        )

        run.add_affected("issue", f"#{issue_num}", "relabeled")
        run.set_result(
            ok=True,
            issue=issue_num,
            status="in_progress",
            agent="worker",
        )
