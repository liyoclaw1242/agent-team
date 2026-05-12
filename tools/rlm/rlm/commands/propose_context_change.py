"""propose-context-change — open a PR editing CONTEXT.md or CONTEXT-MAP.md.

See .rlm/contracts/rlm-cli.md § Detailed: propose-context-change.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("propose-context-change")
@click.option(
    "--target",
    required=True,
    help="path relative to .rlm/ (e.g., bc/intake/CONTEXT.md or CONTEXT-MAP.md)",
)
@click.option(
    "--diff-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="unified diff file (single file)",
)
@click.option(
    "--new-content-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="complete replacement content for the target file",
)
@click.option("--reason", required=True, help="short summary used in PR title")
@click.pass_context
def cmd(
    ctx: click.Context,
    target: str,
    diff_file: Path | None,
    new_content_file: Path | None,
    reason: str,
) -> None:
    """Open a PR editing a CONTEXT.md or CONTEXT-MAP.md. Caller: hermes-design only."""
    raise NotImplementedError(
        "propose-context-change not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: propose-context-change"
    )
