"""mark-in-progress — flip WorkPackage to status:in_progress + agent:worker.

See .rlm/contracts/rlm-cli.md § Detailed: mark-in-progress.
"""

from __future__ import annotations

import click


@click.command("mark-in-progress")
@click.option("--issue", required=True, type=int, help="WorkPackage Issue number")
@click.pass_context
def cmd(ctx: click.Context, issue: int) -> None:
    """Flip WP status:approved → status:in_progress + add agent:worker. Caller: dispatch."""
    raise NotImplementedError(
        "mark-in-progress not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: mark-in-progress"
    )
