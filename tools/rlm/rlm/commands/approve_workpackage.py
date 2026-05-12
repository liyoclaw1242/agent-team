"""approve-workpackage — flip status:draft → status:approved on a WorkPackage Issue.

Mechanically verifies all adr_refs are merged to main before allowing the flip.

See .rlm/contracts/rlm-cli.md § Detailed: approve-workpackage.
"""

from __future__ import annotations

import click


@click.command("approve-workpackage")
@click.option("--issue", required=True, type=int, help="WorkPackage Issue number")
@click.option(
    "--auto-approved",
    is_flag=True,
    help="set if fired via auto-approve timeout (per ADR-0005)",
)
@click.pass_context
def cmd(ctx: click.Context, issue: int, auto_approved: bool) -> None:
    """Flip WP status:draft → status:approved. Verifies adr_refs merged. Caller: hermes-design."""
    raise NotImplementedError(
        "approve-workpackage not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: approve-workpackage"
    )
