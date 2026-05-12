"""append-deployment-constraints — direct-commit a deployment-constraints snapshot.

See .rlm/contracts/rlm-cli.md § Detailed: append-deployment-constraints.
"""

from __future__ import annotations

from pathlib import Path

import click

from rlm.commands.append_business_model import _resolve_date
from rlm.errors import PreconditionFailedError
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.routing import commit as commit_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg


def _parse_compliance(value: str) -> list[str]:
    return [s.strip() for s in value.split(",") if s.strip()]


@click.command("append-deployment-constraints")
@click.option("--snapshot-date", help="YYYY-MM-DD; defaults to today")
@click.option("--signal-ref", required=True, type=int, help="originating Signal Issue number")
@click.option("--budget-monthly-cap", type=float, help="USD monthly cap")
@click.option("--budget-free-tier-required", is_flag=True, help="free-tier required at v1 load")
@click.option("--region", help="region or 'global'")
@click.option(
    "--compliance",
    default="",
    help="comma-separated compliance flags (e.g., GDPR,SOC2); empty = none",
)
@click.option("--vendor-preferences", default="open", help="text describing vendor constraints")
@click.option(
    "--operations",
    type=click.Choice(["managed_only", "self_hosted", "hybrid"]),
    help="operations posture",
)
@click.option("--notes", default="", help="free-text notes")
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="optional narrative body",
)
@click.option("--body", help="inline markdown body")
@click.pass_context
def cmd(
    ctx: click.Context,
    snapshot_date: str | None,
    signal_ref: int,
    budget_monthly_cap: float | None,
    budget_free_tier_required: bool,
    region: str | None,
    compliance: str,
    vendor_preferences: str,
    operations: str | None,
    notes: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write deployment-constraints snapshot. Caller: hermes (or hermes-design)."""
    with SubcommandRun(ctx, "append-deployment-constraints") as run:
        # Body is optional here — frontmatter carries the structured fields
        try:
            body_content = read_body_arg(body_file, body)
        except Exception:
            body_content = ""

        date = _resolve_date(snapshot_date)

        # Idempotency: by (type, snapshot_date)
        key = ("type", "deployment-constraints", "snapshot_date", date)
        ch = content_hash(
            date, str(signal_ref), body_content, region or "", compliance, operations or ""
        )
        if run.cache_get(key, ch):
            return

        target = run.repo_root / ".rlm" / "business" / f"deployment-constraints-{date}.md"
        if target.exists():
            raise PreconditionFailedError(
                f"Snapshot file {target.relative_to(run.repo_root)} already exists",
                subcommand="append-deployment-constraints",
            )

        fm: dict = {
            "type": "deployment-constraints",
            "snapshot_date": date,
            "signal_ref": signal_ref,
            "budget": {
                "monthly_cap_usd": budget_monthly_cap,
                "free_tier_required": budget_free_tier_required,
            },
            "region": region,
            "compliance": _parse_compliance(compliance),
            "vendor_preferences": vendor_preferences,
            "operations": operations,
            "notes": notes,
        }

        full_body = serialize_frontmatter(fm, body_content.lstrip())

        run.add_basis("issue", f"#{signal_ref}")
        run.reasoning = (
            f"snapshotting deployment-constraints from Signal #{signal_ref} on {date} "
            f"(region={region}, ops={operations})"
        )

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_write=str(target.relative_to(run.repo_root)),
            )
            return

        result = commit_route.commit_file(
            repo_root=run.repo_root,
            file_path=target,
            file_content=full_body,
            commit_message=f"deployment-constraints: snapshot {date}",
            push=True,
        )
        run.add_affected("rlm", str(target.relative_to(run.repo_root)), "created")
        run.add_affected("commit", result.commit_sha, "created")
        run.set_result(
            ok=True,
            file=str(target.relative_to(run.repo_root)),
            snapshot_date=date,
            commit_sha=result.commit_sha,
            branch=result.branch,
        )
