"""propose-adr — open a PR adding a new ADR file.

See .rlm/contracts/rlm-cli.md § Detailed: propose-adr.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("propose-adr")
@click.option("--slug", required=True, help="NNNN-kebab-slug (e.g., 0018-rlm-cli-spec)")
@click.option("--title", required=True, help="H1 title; populates PR title")
@click.option(
    "--related-adrs",
    default="",
    help="comma-separated list of related ADR numbers (e.g., 0004,0011)",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body (frontmatter is CLI-generated; do NOT include it)",
)
@click.option("--body", help="inline markdown body (prefer --body-file or stdin)")
@click.pass_context
def cmd(
    ctx: click.Context,
    slug: str,
    title: str,
    related_adrs: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Open a PR adding a new ADR file. Caller: hermes-design only."""
    raise NotImplementedError(
        "propose-adr not yet implemented; see .rlm/contracts/rlm-cli.md § Detailed: propose-adr"
    )
