"""supersede-fact — write a new fact file that supersedes an older one.

See .rlm/contracts/rlm-cli.md § Detailed: supersede-fact.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("supersede-fact")
@click.option("--slug", required=True, help="YYYY-MM-DD-kebab; date must be today")
@click.option(
    "--supersedes",
    required=True,
    help="old fact_id (e.g., 2026-04-12-old-scaffold); must exist + be status:active",
)
@click.option(
    "--about",
    required=True,
    help="comma-separated refs: kind:ref",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body",
)
@click.option("--body", help="inline markdown body")
@click.pass_context
def cmd(
    ctx: click.Context,
    slug: str,
    supersedes: str,
    about: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write a new fact + mark old fact as superseded. Caller: worker only."""
    raise NotImplementedError(
        "supersede-fact not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: supersede-fact"
    )
