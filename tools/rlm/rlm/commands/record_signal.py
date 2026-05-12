"""record-signal — create a type:signal Issue.

See .rlm/contracts/rlm-cli.md § Detailed: record-signal.
"""

from __future__ import annotations

from datetime import datetime, timezone
from pathlib import Path

import click

from rlm.adapters import gh
from rlm.runner import SubcommandRun, content_hash, read_body_arg


def _is_recent(iso_ts: str, hours: int = 24) -> bool:
    """Return True if `iso_ts` is within the last `hours` hours."""
    try:
        # Tolerate both Z-suffix and offset forms
        ts = iso_ts.replace("Z", "+00:00")
        dt = datetime.fromisoformat(ts)
    except ValueError:
        return False
    delta = datetime.now(timezone.utc) - dt
    return delta.total_seconds() < hours * 3600


def _find_recent_open_signal(dedup_key: str) -> int | None:
    """Search open type:signal Issues whose body contains the dedup key."""
    matches = gh.issue_list(
        labels=["type:signal"],
        state="open",
        search=dedup_key,
        fields=["number", "body", "createdAt"],
    )
    for entry in matches:
        body = entry.get("body", "") or ""
        if dedup_key not in body:
            continue
        created = entry.get("createdAt", "")
        if created and not _is_recent(created, hours=24):
            continue
        return int(entry["number"])
    return None


@click.command("record-signal")
@click.option(
    "--source",
    required=True,
    type=click.Choice(["human", "production-monitor", "hermes"]),
)
@click.option("--title", required=True, help="Signal title")
@click.option("--related-thread", help="Discord thread id (optional)")
@click.option("--dedup-key", help="optional dedup key; skips if open signal with same key < 24h")
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
    with SubcommandRun(ctx, "record-signal") as run:
        body_content = read_body_arg(body_file, body)
        # Dedup-key needs to be inside the body so issue_list --search can find it
        if dedup_key and dedup_key not in body_content:
            body_content = f"{body_content}\n\n---\ndedup_key: {dedup_key}\n"

        # Idempotency
        key = ("source", source, "dedup_key", dedup_key or "")
        ch = content_hash(source, title, dedup_key or "", body_content)
        cached = run.cache_get(key, ch)
        if cached:
            return

        # Dedup against open Signal Issues
        if dedup_key:
            existing = _find_recent_open_signal(dedup_key)
            if existing is not None:
                run.add_basis("issue", f"#{existing}")
                run.reasoning = f"dedup hit: open signal #{existing} with same dedup_key within 24h"
                run.set_result(
                    ok=True,
                    issue_number=existing,
                    deduplicated=True,
                    reason="open signal with same dedup_key < 24h ago",
                )
                return

        # Build full body with refs section if related_thread provided
        if related_thread:
            body_content = (
                f"{body_content.rstrip()}\n\n## Refs\n\n- Discord thread: {related_thread}\n"
            )

        # Compose labels
        labels = ["type:signal", "status:draft"]

        # Compose run metadata
        run.reasoning = f"recorded {source} signal: {title!r}"
        run.add_basis("source", source)

        if run.dry_run:
            run.set_result(ok=True, dry_run=True, would_create_signal_title=title)
            return

        issue_number = gh.issue_create(title=title, body=body_content, labels=labels)
        run.add_affected("issue", f"#{issue_number}", "created")
        run.set_result(
            ok=True,
            issue_number=issue_number,
            deduplicated=False,
        )
