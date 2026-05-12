"""confirm-spec — flip status:draft → status:confirmed on a Spec Issue.

See .rlm/contracts/rlm-cli.md § Detailed: confirm-spec.
"""

from __future__ import annotations

import click

from rlm.adapters import gh
from rlm.errors import PreconditionFailedError, ValidationError
from rlm.routing import issue as issue_route
from rlm.runner import SubcommandRun


@click.command("confirm-spec")
@click.option("--issue", "issue_num", required=True, type=int, help="Spec Issue number")
@click.option(
    "--auto-confirmed",
    is_flag=True,
    help="set if fired via auto-confirm timeout (per ADR-0005)",
)
@click.pass_context
def cmd(ctx: click.Context, issue_num: int, auto_confirmed: bool) -> None:
    """Flip Spec status:draft → status:confirmed (body becomes immutable). Caller: hermes."""
    with SubcommandRun(ctx, "confirm-spec") as run:
        # Idempotency: keyed by (issue, target-status)
        key = ("issue", issue_num, "to", "confirmed")
        cached = run.cache_get(key)
        if cached:
            return

        # Verify Issue is type:spec
        try:
            issue_route.verify_issue_exists(issue_num, expected_type="spec")
        except ValidationError as e:
            # Promote validation issue to precondition for clearer semantics
            raise PreconditionFailedError(
                e.message, subcommand="confirm-spec", details=e.details
            ) from e

        run.add_basis("issue", f"#{issue_num}")
        run.reasoning = f"confirming Spec #{issue_num}" + (
            " (auto-confirmed via timeout)" if auto_confirmed else ""
        )

        if run.dry_run:
            run.set_result(ok=True, dry_run=True, would_confirm_issue=issue_num)
            return

        # If auto-confirmed: stamp the frontmatter via body edit
        if auto_confirmed:
            data = gh.issue_view(issue_num, fields=["body"])
            new_body = _stamp_auto_confirmed(data.get("body", ""))
            gh.issue_edit(issue_num, body=new_body)

        # Flip the label (idempotent — if already confirmed, no-op)
        issue_route.flip_status(
            issue_number=issue_num,
            from_status="draft",
            to_status="confirmed",
            require_type="spec",
        )

        run.add_affected("issue", f"#{issue_num}", "relabeled")
        run.set_result(
            ok=True,
            issue=issue_num,
            status="confirmed",
            auto_confirmed=auto_confirmed,
        )


def _stamp_auto_confirmed(body: str) -> str:
    """Set or insert `auto_confirmed: true` in the Issue body's frontmatter.

    If no frontmatter block exists, the body is returned unchanged (we don't
    invent frontmatter on issues that don't have it — those predate the spec).
    """
    from rlm.frontmatter import parse, serialize

    fm, body_text = parse(body)
    if not fm:
        return body
    fm["auto_confirmed"] = True
    return serialize(fm, body_text)
