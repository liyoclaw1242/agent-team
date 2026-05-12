"""open-pr — Worker opens the PR for its WorkPackage branch.

See .rlm/contracts/rlm-cli.md § Detailed: open-pr.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("open-pr")
@click.option("--issue", required=True, type=int, help="WorkPackage Issue number")
@click.option(
    "--branch",
    required=True,
    help="branch name (must match wp/<num>-<slug> pattern)",
)
@click.option("--title", required=True, help="PR title (Worker's summary)")
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="PR body markdown",
)
@click.option("--body", help="inline PR body")
@click.pass_context
def cmd(
    ctx: click.Context,
    issue: int,
    branch: str,
    title: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Push branch + open PR + comment on WP Issue. Caller: worker."""
    raise NotImplementedError(
        "open-pr not yet implemented; see .rlm/contracts/rlm-cli.md § Detailed: open-pr"
    )
