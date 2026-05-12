"""supersede-fact — write a new fact file that supersedes an older one.

See .rlm/contracts/rlm-cli.md § Detailed: supersede-fact.

Worker writes the new fact AND edits the old fact's frontmatter
(superseded_by / status:superseded) atomically in a single commit on the
current branch (no push).
"""

from __future__ import annotations

from pathlib import Path

import click

from rlm.adapters import git
from rlm.commands.append_fact import (
    _build_fact_body,
    _parse_about,
    _validate_slug_today,
)
from rlm.errors import PreconditionFailedError, ValidationError
from rlm.frontmatter import parse as parse_frontmatter
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.routing import commit as commit_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg


def _mark_old_superseded(
    old_path: Path,
    *,
    new_fact_id: str,
) -> str:
    """Read old fact, patch frontmatter to mark superseded_by + status:superseded.

    Returns the new file content (to be written back by the commit_file call).
    """
    if not old_path.exists():
        raise PreconditionFailedError(
            f"--supersedes refers to {old_path.name} which does not exist",
            subcommand="supersede-fact",
            details={"missing_path": str(old_path)},
        )
    old_content = old_path.read_text(encoding="utf-8")
    fm, body = parse_frontmatter(old_content)
    if not fm:
        raise PreconditionFailedError(
            f"Old fact {old_path.name} has no frontmatter — cannot mark superseded",
            subcommand="supersede-fact",
        )
    if fm.get("status") == "superseded":
        raise PreconditionFailedError(
            f"Old fact {old_path.name} is already superseded (by {fm.get('superseded_by')!r})",
            subcommand="supersede-fact",
            details={"already_superseded_by": fm.get("superseded_by")},
        )
    fm["superseded_by"] = new_fact_id
    fm["status"] = "superseded"
    return serialize_frontmatter(fm, body)


@click.command("supersede-fact")
@click.option("--slug", required=True, help="YYYY-MM-DD-kebab; date must be today")
@click.option(
    "--supersedes",
    required=True,
    help="old fact_id (e.g., 2026-04-12-old-scaffold); must exist + be status:active",
)
@click.option(
    "--about",
    required=True,
    help="comma-separated refs: kind:ref",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body",
)
@click.option("--body", help="inline markdown body")
@click.pass_context
def cmd(
    ctx: click.Context,
    slug: str,
    supersedes: str,
    about: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write new fact + mark old fact as superseded. Caller: worker only."""
    with SubcommandRun(ctx, "supersede-fact") as run:
        body_content = read_body_arg(body_file, body)
        _validate_slug_today(slug)
        about_list = _parse_about(about)

        if slug == supersedes:
            raise ValidationError(
                "--slug and --supersedes refer to the same fact_id",
                field="supersedes",
            )

        # Idempotency: by (slug, supersedes)
        key = ("slug", slug, "supersedes", supersedes)
        ch = content_hash(slug, supersedes, about, body_content)
        if run.cache_get(key, ch):
            return

        new_path = run.repo_root / ".rlm" / "facts" / f"{slug}.md"
        old_path = run.repo_root / ".rlm" / "facts" / f"{supersedes}.md"

        if new_path.exists():
            raise PreconditionFailedError(
                f"New fact path {new_path.relative_to(run.repo_root)} already exists",
                subcommand="supersede-fact",
            )

        # Patch the old fact's frontmatter
        old_new_content = _mark_old_superseded(old_path, new_fact_id=slug)

        # Build the new fact's body
        verified_by_commit = git.head_sha(cwd=run.repo_root, short=True)
        full_new_body = _build_fact_body(
            body_content,
            fact_id=slug,
            verified_by_commit=verified_by_commit,
            about=about_list,
            supersedes=supersedes,
        )

        run.add_basis("commit", verified_by_commit)
        run.add_basis("fact", f".rlm/facts/{supersedes}.md")
        run.reasoning = f"superseding fact {supersedes!r} with {slug!r}"

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_create_fact_id=slug,
                would_supersede=supersedes,
            )
            return

        # Atomic commit: new fact + edited old fact
        result = commit_route.commit_file(
            repo_root=run.repo_root,
            file_path=new_path,
            file_content=full_new_body,
            commit_message=f"fact: {slug} (supersedes {supersedes})",
            push=False,
            additional_files=[(old_path, old_new_content)],
        )

        run.add_affected("rlm", str(new_path.relative_to(run.repo_root)), "created")
        run.add_affected("rlm", str(old_path.relative_to(run.repo_root)), "edited")
        run.add_affected("commit", result.commit_sha, "created")
        run.set_result(
            ok=True,
            fact_id=slug,
            supersedes=supersedes,
            file=str(new_path.relative_to(run.repo_root)),
            commit_sha=result.commit_sha,
            branch=result.branch,
        )
