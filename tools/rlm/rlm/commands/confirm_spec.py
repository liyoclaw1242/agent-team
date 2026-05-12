"""confirm-spec — flip status:draft → status:confirmed on a Spec Issue.

See .rlm/contracts/rlm-cli.md § Detailed: confirm-spec.
"""

from __future__ import annotations

import click


@click.command("confirm-spec")
@click.option("--issue", required=True, type=int, help="Spec Issue number")
@click.option(
    "--auto-confirmed",
    is_flag=True,
    help="set if fired via auto-confirm timeout (per ADR-0005)",
)
@click.pass_context
def cmd(ctx: click.Context, issue: int, auto_confirmed: bool) -> None:
    """Flip Spec status:draft → status:confirmed (body becomes immutable). Caller: hermes."""
    raise NotImplementedError(
        "confirm-spec not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: confirm-spec"
    )
