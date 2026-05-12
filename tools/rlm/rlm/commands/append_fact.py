"""append-fact — write a new fact file via direct commit.

See .rlm/contracts/rlm-cli.md § Detailed: append-fact.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("append-fact")
@click.option(
    "--slug",
    required=True,
    help="YYYY-MM-DD-kebab; date must be today (CLI validates)",
)
@click.option(
    "--about",
    required=True,
    help="comma-separated refs: kind:ref (e.g., code:src/foo.ts:1-50,code:src/bar.ts)",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body",
)
@click.option("--body", help="inline markdown body (prefer --body-file or stdin)")
@click.pass_context
def cmd(
    ctx: click.Context,
    slug: str,
    about: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write a new fact file on the current branch (no push). Caller: worker only."""
    raise NotImplementedError(
        "append-fact not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: append-fact"
    )
