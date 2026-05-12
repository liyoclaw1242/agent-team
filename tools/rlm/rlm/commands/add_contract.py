"""add-contract — open a PR adding a new contract file.

See .rlm/contracts/rlm-cli.md § Detailed: add-contract.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("add-contract")
@click.option("--slug", required=True, help="kebab-case slug (e.g., household-api)")
@click.option(
    "--contract-kind",
    required=True,
    type=click.Choice(["api", "event", "schema", "integration"]),
)
@click.option("--title", required=True, help="used in PR title")
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body (frontmatter is CLI-generated)",
)
@click.option("--body", help="inline markdown body (prefer --body-file or stdin)")
@click.pass_context
def cmd(
    ctx: click.Context,
    slug: str,
    contract_kind: str,
    title: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Open a PR adding a new contract file. Caller: hermes-design only."""
    raise NotImplementedError(
        "add-contract not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: add-contract"
    )
