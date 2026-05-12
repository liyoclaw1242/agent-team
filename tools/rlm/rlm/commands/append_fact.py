"""append-fact — write a new fact file via direct commit.

See .rlm/contracts/rlm-cli.md § Detailed: append-fact.

Worker context: commits on the current branch (typically `wp/<num>-<slug>`)
without push. The commit becomes part of the PR that Worker opens later via
`open-pr`.
"""

from __future__ import annotations

import re
from datetime import datetime, timezone
from pathlib import Path

import click

from rlm.adapters import git
from rlm.errors import PreconditionFailedError, ValidationError
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.routing import commit as commit_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg

_SLUG_RE = re.compile(r"^(\d{4}-\d{2}-\d{2})-[a-z0-9][a-z0-9-]*$")


def _validate_slug_today(slug: str) -> str:
    """Return the date portion if valid + today; raise ValidationError otherwise."""
    m = _SLUG_RE.match(slug)
    if not m:
        raise ValidationError(
            f"--slug must match YYYY-MM-DD-kebab (e.g., 2026-05-12-foo); got {slug!r}",
            field="slug",
        )
    date_str = m.group(1)
    today = datetime.now(timezone.utc).date().isoformat()
    if date_str != today:
        raise ValidationError(
            f"--slug date {date_str} is not today ({today}); facts must use today's date",
            field="slug",
            details={"slug_date": date_str, "today": today},
        )
    return date_str


def _parse_about(about: str) -> list[dict[str, str]]:
    """Parse `kind:ref,kind:ref` into [{kind, ref}, ...].

    Tolerates colons in the ref (e.g., `code:src/foo.ts:1-50`).
    """
    out: list[dict[str, str]] = []
    for part in [s.strip() for s in about.split(",") if s.strip()]:
        if ":" not in part:
            raise ValidationError(
                f"--about entry {part!r} missing 'kind:' prefix",
                field="about",
            )
        kind, _, ref = part.partition(":")
        out.append({"kind": kind.strip(), "ref": ref.strip()})
    if not out:
        raise ValidationError("--about cannot be empty", field="about")
    return out


def _build_fact_body(
    body_content: str,
    *,
    fact_id: str,
    verified_by_commit: str,
    about: list[dict[str, str]],
    supersedes: str | None = None,
) -> str:
    now_iso = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    fm: dict = {
        "type": "fact",
        "fact_id": fact_id,
        "last_verified": now_iso,
        "verified_by_commit": verified_by_commit,
        "about": about,
        "supersedes": supersedes,
        "superseded_by": None,
        "status": "active",
    }
    return serialize_frontmatter(fm, body_content.lstrip())


@click.command("append-fact")
@click.option("--slug", required=True, help="YYYY-MM-DD-kebab; date must be today")
@click.option(
    "--about",
    required=True,
    help="comma-separated refs: kind:ref (e.g., code:src/foo.ts:1-50,code:src/bar.ts)",
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
    about: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Write a new fact file on the current branch (no push). Caller: worker only."""
    with SubcommandRun(ctx, "append-fact") as run:
        body_content = read_body_arg(body_file, body)
        _validate_slug_today(slug)
        about_list = _parse_about(about)

        # Idempotency: by slug
        key = ("slug", slug)
        ch = content_hash(slug, about, body_content)
        if run.cache_get(key, ch):
            return

        # Check for existing fact file on disk — refuse (must use supersede-fact)
        target = run.repo_root / ".rlm" / "facts" / f"{slug}.md"
        if target.exists():
            raise PreconditionFailedError(
                f"Fact file {target.relative_to(run.repo_root)} already exists; "
                "use `rlm supersede-fact` to replace it",
                subcommand="append-fact",
                details={"existing_path": str(target.relative_to(run.repo_root))},
            )

        # Capture HEAD before writing — this is what the fact verifies against
        verified_by_commit = git.head_sha(cwd=run.repo_root, short=True)

        full_body = _build_fact_body(
            body_content,
            fact_id=slug,
            verified_by_commit=verified_by_commit,
            about=about_list,
        )

        run.add_basis("commit", verified_by_commit)
        for entry in about_list:
            run.add_basis(entry["kind"], entry["ref"])
        run.reasoning = f"appending fact {slug!r} verified against {verified_by_commit}"

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_write_fact_id=slug,
                file=str(target.relative_to(run.repo_root)),
            )
            return

        result = commit_route.commit_file(
            repo_root=run.repo_root,
            file_path=target,
            file_content=full_body,
            commit_message=f"fact: {slug}",
            push=False,  # Worker context: no push; open-pr will push the whole branch
        )

        run.add_affected("rlm", str(target.relative_to(run.repo_root)), "created")
        run.add_affected("commit", result.commit_sha, "created")
        run.set_result(
            ok=True,
            fact_id=slug,
            file=str(target.relative_to(run.repo_root)),
            commit_sha=result.commit_sha,
            branch=result.branch,
        )
