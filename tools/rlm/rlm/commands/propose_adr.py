"""propose-adr — open a PR adding a new ADR file.

See .rlm/contracts/rlm-cli.md § Detailed: propose-adr.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path

import click

from rlm.errors import PreconditionFailedError, ValidationError
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.routing import pr as pr_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg

_SLUG_RE = re.compile(r"^(\d{4})-[a-z0-9][a-z0-9-]*$")
_ADR_FILE_RE = re.compile(r"^(\d{4})-")


def _next_adr_number(adr_dir: Path) -> int:
    nums = []
    for f in adr_dir.glob("*.md"):
        m = _ADR_FILE_RE.match(f.name)
        if m:
            nums.append(int(m.group(1)))
    return (max(nums) + 1) if nums else 1


def _validate_slug_is_next(slug: str, adr_dir: Path) -> tuple[int, int]:
    """Return (provided_n, next_n) if matching; raise otherwise."""
    m = _SLUG_RE.match(slug)
    if not m:
        raise ValidationError(
            f"--slug must match NNNN-kebab (e.g., 0018-rlm-cli-spec); got {slug!r}",
            field="slug",
        )
    provided_n = int(m.group(1))
    next_n = _next_adr_number(adr_dir)
    if provided_n != next_n:
        raise ValidationError(
            f"--slug NNNN must be the next monotonic number {next_n:04d}; got {provided_n:04d}",
            field="slug",
            details={"expected": f"{next_n:04d}", "got": f"{provided_n:04d}"},
        )
    return provided_n, next_n


def _validate_body_has_h1(body: str) -> str:
    for line in body.splitlines():
        line = line.strip()
        if not line:
            continue
        if line.startswith("# "):
            return line.lstrip("# ").strip()
        # First non-blank wasn't H1 → reject
        raise ValidationError(
            "ADR body must start with an H1 title line (`# Title`)",
            field="body",
        )
    raise ValidationError("ADR body is empty", field="body")


def _parse_related(raw: str) -> list[int]:
    if not raw.strip():
        return []
    out = []
    for part in raw.split(","):
        part = part.strip()
        if not part:
            continue
        try:
            out.append(int(part))
        except ValueError as e:
            raise ValidationError(
                f"--related-adrs entry {part!r} is not an integer",
                field="related_adrs",
            ) from e
    return out


@click.command("propose-adr")
@click.option("--slug", required=True, help="NNNN-kebab-slug (e.g., 0018-rlm-cli-spec)")
@click.option("--title", required=True, help="H1 title; populates PR title")
@click.option(
    "--related-adrs",
    default="",
    help="comma-separated list of related ADR numbers (e.g., 0004,0011)",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body (frontmatter is CLI-generated; do NOT include it)",
)
@click.option("--body", help="inline markdown body (prefer --body-file or stdin)")
@click.pass_context
def cmd(
    ctx: click.Context,
    slug: str,
    title: str,
    related_adrs: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Open a PR adding a new ADR file. Caller: hermes-design only."""
    with SubcommandRun(ctx, "propose-adr") as run:
        body_content = read_body_arg(body_file, body)
        _validate_body_has_h1(body_content)
        related = _parse_related(related_adrs)

        adr_dir = run.repo_root / ".rlm" / "adr"
        provided_n, _ = _validate_slug_is_next(slug, adr_dir)

        # Idempotency: by slug
        key = ("slug", slug)
        ch = content_hash(slug, title, body_content)
        if run.cache_get(key, ch):
            return

        target = adr_dir / f"{slug}.md"
        if target.exists():
            raise PreconditionFailedError(
                f"ADR file {target.relative_to(run.repo_root)} already exists in working tree",
                subcommand="propose-adr",
            )

        fm: dict = {
            "type": "adr",
            "adr_number": provided_n,
            "slug": slug,
            "status": "proposed",
            "created": datetime.now(timezone.utc).date().isoformat(),
            "deciders": [],
            "supersedes": None,
            "superseded_by": None,
            "related_adrs": related,
        }
        full_body = serialize_frontmatter(fm, body_content.lstrip())

        branch = f"adr/{slug}"
        pr_body = (
            f"ADR-{provided_n:04d}: {title}\n\n"
            f"<!-- CLI-generated. Body below. -->\n\n"
            f"{body_content.strip()}\n"
        )

        run.reasoning = f"opening PR for ADR-{provided_n:04d} ({slug})"

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_create_adr_number=provided_n,
                would_branch=branch,
            )
            return

        result = pr_route.open_pr_for_file_change(
            repo_root=run.repo_root,
            branch=branch,
            file_path=target,
            file_content=full_body,
            commit_message=f"adr: {slug}",
            pr_title=f"ADR-{provided_n:04d}: {title}",
            pr_body=pr_body,
        )

        run.add_affected("rlm", str(target.relative_to(run.repo_root)), "created")
        run.add_affected("pr", f"#{result.pr_number}", "opened")
        run.set_result(
            ok=True,
            adr_number=provided_n,
            slug=slug,
            branch=result.branch,
            pr_number=result.pr_number,
            pr_url=result.pr_url,
            commit_sha=result.commit_sha,
        )
