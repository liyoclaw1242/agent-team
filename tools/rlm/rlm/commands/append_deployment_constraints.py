"""append-deployment-constraints — write a deployment-constraints snapshot.

See .rlm/contracts/rlm-cli.md § Detailed: append-business-model / append-deployment-constraints.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("append-deployment-constraints")
@click.option("--snapshot-date", help="YYYY-MM-DD; defaults to today")
@click.option("--signal-ref", required=True, type=int, help="originating Signal Issue number")
@click.option("--budget-monthly-cap", type=float, help="USD monthly cap (frontmatter field)")
@click.option("--region", help="region or 'global'")
@click.option(
    "--compliance",
    default="",
    help="comma-separated compliance flags (e.g., GDPR,SOC2); empty = none",
)
@click.option("--vendor-preferences", help="text describing vendor constraints")
@click.option(
    "--operations",
    type=click.Choice(["managed_only", "self_hosted", "hybrid"]),
    help="operations posture",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="optional narrative body",
)
@click.option("--body", help="inline markdown body")
@click.pass_context
def cmd(
    ctx: click.Context,
    snapshot_date: str | None,
    signal_ref: int,
    budget_monthly_cap: float | None,
    region: str | None,
    compliance: str,
    vendor_preferences: str | None,
    operations: str | None,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write deployment-constraints snapshot. Caller: hermes (or hermes-design)."""
    raise NotImplementedError(
        "append-deployment-constraints not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: append-deployment-constraints"
    )
