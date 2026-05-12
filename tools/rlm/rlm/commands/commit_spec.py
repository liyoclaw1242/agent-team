"""commit-spec — create a type:spec Issue at status:draft.

See .rlm/contracts/rlm-cli.md § Detailed: commit-spec.
"""

from __future__ import annotations

from pathlib import Path

import click


@click.command("commit-spec")
@click.option("--signal-ref", required=True, type=int, help="originating Signal Issue number")
@click.option("--title", required=True, help="Issue title (imperative, outcome-focused)")
@click.option(
    "--business-model-ref",
    help="path to business-model snapshot (e.g., .rlm/business/business-model-2026-05-12.md)",
)
@click.option(
    "--deployment-constraints-ref",
    help="path to deployment-constraints snapshot (optional)",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="Issue body markdown; MUST contain `## AcceptanceCriteria` with ≥1 checkbox",
)
@click.option("--body", help="inline Issue body")
@click.pass_context
def cmd(
    ctx: click.Context,
    signal_ref: int,
    title: str,
    business_model_ref: str | None,
    deployment_constraints_ref: str | None,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Create a Spec Issue. Body validated for AcceptanceCriteria. Caller: hermes."""
    raise NotImplementedError(
        "commit-spec not yet implemented; "
        "see .rlm/contracts/rlm-cli.md § Detailed: commit-spec"
    )
