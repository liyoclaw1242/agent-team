"""append-business-model — write a business-model snapshot via direct commit to main.

See .rlm/contracts/rlm-cli.md § Detailed: append-business-model / append-deployment-constraints.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("append-business-model")
@click.option("--snapshot-date", help="YYYY-MM-DD; defaults to today")
@click.option("--signal-ref", required=True, type=int, help="originating Signal Issue number")
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body — wedge / target / status quo / demand reality / future fit",
)
@click.option("--body", help="inline markdown body")
@click.pass_context
def cmd(
    ctx: click.Context,
    snapshot_date: str | None,
    signal_ref: int,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write business-model snapshot to .rlm/business/. Caller: hermes (or hermes-design)."""
    raise NotImplementedError(
        "append-business-model not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: append-business-model"
    )
