"""mark-superseded — flip an Issue to status:superseded (terminal).

See .rlm/contracts/rlm-cli.md § Detailed: mark-superseded.
"""

from __future__ import annotations

import click

from rlm.adapters import gh
from rlm.errors import PreconditionFailedError
from rlm.runner import SubcommandRun


@click.command("mark-superseded")
@click.option("--issue", "issue_num", required=True, type=int, help="Issue to be superseded")
@click.option(
    "--by",
    "by_issue",
    required=True,
    type=int,
    help="superseding Issue number (must exist + share type:* with --issue)",
)
@click.pass_context
def cmd(ctx: click.Context, issue_num: int, by_issue: int) -> None:
    """Flip Issue to status:superseded + cross-reference. Caller: hermes / hermes-design."""
    with SubcommandRun(ctx, "mark-superseded") as run:
        key = ("issue", issue_num, "by", by_issue)
        cached = run.cache_get(key)
        if cached:
            return

        # Verify both Issues exist + share type
        old = gh.issue_view(issue_num, fields=["labels", "state"])
        new = gh.issue_view(by_issue, fields=["labels"])
        old_labels = {entry["name"] for entry in old.get("labels", []) if "name" in entry}
        new_labels = {entry["name"] for entry in new.get("labels", []) if "name" in entry}

        old_types = {label for label in old_labels if label.startswith("type:")}
        new_types = {label for label in new_labels if label.startswith("type:")}
        if not old_types or old_types != new_types:
            raise PreconditionFailedError(
                f"Issue #{issue_num} and #{by_issue} must share the same type:* label; "
                f"got {old_types} vs {new_types}",
                subcommand="mark-superseded",
                details={"old_types": sorted(old_types), "new_types": sorted(new_types)},
            )

        run.add_basis("issue", f"#{issue_num}")
        run.add_basis("issue", f"#{by_issue}")
        run.reasoning = f"superseding #{issue_num} by #{by_issue}"

        if run.dry_run:
            run.set_result(ok=True, dry_run=True, would_supersede=issue_num, by=by_issue)
            return

        # Idempotency: if already superseded, no-op
        if "status:superseded" not in old_labels:
            # Remove whatever current status:* label exists; add status:superseded
            removed = [label for label in old_labels if label.startswith("status:")]
            gh.issue_edit(
                issue_num,
                add_labels=["status:superseded"],
                remove_labels=removed,
            )

        # Cross-reference comments
        gh.issue_comment(issue_num, f"Superseded by #{by_issue}")
        gh.issue_comment(by_issue, f"Supersedes #{issue_num}")

        run.add_affected("issue", f"#{issue_num}", "relabeled")
        run.add_affected("issue", f"#{by_issue}", "commented")
        run.set_result(
            ok=True,
            issue=issue_num,
            status="superseded",
            by=by_issue,
        )
