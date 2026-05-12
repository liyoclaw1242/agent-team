"""enqueue-message — queue an outbound message for Hermes to route to Discord.

See .rlm/contracts/rlm-cli.md § Detailed: enqueue-message and ADR-0015.
"""

from __future__ import annotations

from pathlib import Path

import click

VALID_KINDS = [
    "retry-exhausted",
    "ac-ambiguity",
    "supervision-alert",
    "intake-confirmation",
    "design-approval",
    "worker-self-decline",
    "production-anomaly",
]


@click.command("enqueue-message")
@click.option(
    "--kind",
    required=True,
    type=click.Choice(VALID_KINDS),
    help="message kind (per ADR-0015)",
)
@click.option(
    "--parent-issue",
    type=int,
    help="parent Issue number (required for all kinds except supervision-alert)",
)
@click.option(
    "--severity",
    type=click.Choice(["low", "mid", "high"]),
    help="for supervision-alert only",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="message body markdown",
)
@click.option("--body", help="inline message body")
@click.pass_context
def cmd(
    ctx: click.Context,
    kind: str,
    parent_issue: int | None,
    severity: str | None,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Enqueue a message. Routing: parent Issue comment+label OR new supervision-alert Issue."""
    raise NotImplementedError(
        "enqueue-message not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: enqueue-message"
    )
