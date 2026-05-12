"""mark-delivered — flip WorkPackage to status:delivered.

Requires the closing PR to be merged AND the CI fact-commit check (named
`rlm/fact-commit-required`) to have passed.

See .rlm/contracts/rlm-cli.md § Detailed: mark-delivered.
"""

from __future__ import annotations

import click


@click.command("mark-delivered")
@click.option("--issue", required=True, type=int, help="WorkPackage Issue number")
@click.pass_context
def cmd(ctx: click.Context, issue: int) -> None:
    """Flip WP status:in_progress → status:delivered. Caller: dispatch."""
    raise NotImplementedError(
        "mark-delivered not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: mark-delivered"
    )
