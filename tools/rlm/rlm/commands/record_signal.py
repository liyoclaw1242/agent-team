"""record-signal — create a type:signal Issue.

See .rlm/contracts/rlm-cli.md § Detailed: record-signal.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("record-signal")
@click.option(
    "--source",
    required=True,
    type=click.Choice(["human", "production-monitor", "hermes"]),
)
@click.option("--title", required=True, help="Signal title")
@click.option("--related-thread", help="Discord thread id (optional)")
@click.option(
    "--dedup-key",
    help="optional dedup key; skips creation if open Signal w/ same key < 24h",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="Signal body markdown",
)
@click.option("--body", help="inline Signal body")
@click.pass_context
def cmd(
    ctx: click.Context,
    source: str,
    title: str,
    related_thread: str | None,
    dedup_key: str | None,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Create a Signal Issue. Caller: hermes."""
    raise NotImplementedError(
        "record-signal not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: record-signal"
    )
