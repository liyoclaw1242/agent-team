"""commit-workpackage — create a type:workpackage Issue at status:draft.

See .rlm/contracts/rlm-cli.md § Detailed: commit-workpackage.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("commit-workpackage")
@click.option("--parent-spec", required=True, type=int, help="parent Spec Issue number")
@click.option("--title", required=True, help="imperative title")
@click.option(
    "--worker-class",
    default="web-stack",
    type=click.Choice(["web-stack"]),
    help="v1 only web-stack is valid",
)
@click.option(
    "--adr-refs",
    default="",
    help="comma-separated ADR numbers (e.g., 1,2)",
)
@click.option(
    "--depends-on",
    default="",
    help="comma-separated WP Issue numbers this WP depends on",
)
@click.option(
    "--impact-scope-file",
    required=True,
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="YAML file with impact_scope: field (from compute-impact-scope skill)",
)
@click.option(
    "--slice-type",
    default="AFK",
    type=click.Choice(["AFK", "HITL"]),
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="Issue body; MUST contain `## AcceptanceCriteria` with checkboxes",
)
@click.option("--body", help="inline Issue body")
@click.pass_context
def cmd(
    ctx: click.Context,
    parent_spec: int,
    title: str,
    worker_class: str,
    adr_refs: str,
    depends_on: str,
    impact_scope_file: Path,
    slice_type: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Create a WorkPackage Issue. Caller: hermes-design."""
    raise NotImplementedError(
        "commit-workpackage not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: commit-workpackage"
    )
