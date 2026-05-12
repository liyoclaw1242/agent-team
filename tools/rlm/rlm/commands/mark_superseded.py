"""mark-superseded — flip an Issue to status:superseded (terminal).

See .rlm/contracts/rlm-cli.md § Detailed: mark-superseded.
"""

from __future__ import annotations

import click


@click.command("mark-superseded")
@click.option("--issue", required=True, type=int, help="Issue to be superseded")
@click.option(
    "--by",
    required=True,
    type=int,
    help="superseding Issue number (must exist + share type:* with --issue)",
)
@click.pass_context
def cmd(ctx: click.Context, issue: int, by: int) -> None:
    """Flip Issue to status:superseded + cross-reference. Caller: hermes."""
    raise NotImplementedError(
        "mark-superseded not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: mark-superseded"
    )
