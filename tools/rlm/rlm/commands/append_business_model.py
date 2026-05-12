"""append-business-model — direct-commit a business-model snapshot.

See .rlm/contracts/rlm-cli.md § Detailed: append-business-model.

Hermes is typically on `main`; this commits the snapshot file and pushes.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path

import click

from rlm.errors import PreconditionFailedError, ValidationError
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.routing import commit as commit_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg

_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")


def _resolve_date(snapshot_date: str | None) -> str:
    if snapshot_date is None:
        return datetime.now(timezone.utc).date().isoformat()
    if not _DATE_RE.match(snapshot_date):
        raise ValidationError(
            f"--snapshot-date must be YYYY-MM-DD; got {snapshot_date!r}",
            field="snapshot_date",
        )
    today = datetime.now(timezone.utc).date().isoformat()
    if snapshot_date > today:
        raise ValidationError(
            f"--snapshot-date {snapshot_date} is in the future (today: {today})",
            field="snapshot_date",
        )
    return snapshot_date


@click.command("append-business-model")
@click.option("--snapshot-date", help="YYYY-MM-DD; defaults to today")
@click.option("--signal-ref", required=True, type=int, help="originating Signal Issue number")
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body — wedge / target / status quo / demand reality / future fit",
)
@click.option("--body", help="inline markdown body")
@click.pass_context
def cmd(
    ctx: click.Context,
    snapshot_date: str | None,
    signal_ref: int,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write business-model snapshot to .rlm/business/. Caller: hermes (or hermes-design)."""
    with SubcommandRun(ctx, "append-business-model") as run:
        body_content = read_body_arg(body_file, body)
        date = _resolve_date(snapshot_date)

        # Idempotency: by (type, snapshot_date)
        key = ("type", "business-model", "snapshot_date", date)
        ch = content_hash(date, str(signal_ref), body_content)
        if run.cache_get(key, ch):
            return

        target = run.repo_root / ".rlm" / "business" / f"business-model-{date}.md"
        if target.exists():
            raise PreconditionFailedError(
                f"Snapshot file {target.relative_to(run.repo_root)} already exists; "
                "use a different --snapshot-date to capture an update",
                subcommand="append-business-model",
            )

        fm: dict = {
            "type": "business-model",
            "snapshot_date": date,
            "signal_ref": signal_ref,
        }
        if run.caller.invocation_id:
            fm["author_invocation"] = run.caller.invocation_id

        full_body = serialize_frontmatter(fm, body_content.lstrip())

        run.add_basis("issue", f"#{signal_ref}")
        run.reasoning = f"snapshotting business-model from Signal #{signal_ref} on {date}"

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
            commit_message=f"business: snapshot {date}",
            push=True,  # Hermes-on-main: publish snapshot
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
