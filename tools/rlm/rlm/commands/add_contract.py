"""add-contract — open a PR adding a new contract file.

See .rlm/contracts/rlm-cli.md § Detailed: add-contract.
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

_SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")


def _validate_slug(slug: str) -> None:
    if not _SLUG_RE.match(slug):
        raise ValidationError(
            f"--slug must be kebab-case (e.g., household-api); got {slug!r}",
            field="slug",
        )


@click.command("add-contract")
@click.option("--slug", required=True, help="kebab-case slug (e.g., household-api)")
@click.option(
    "--contract-kind",
    required=True,
    type=click.Choice(["api", "event", "schema", "integration"]),
)
@click.option("--title", required=True, help="used in PR title")
@click.option(
    "--versioning",
    default="additive-only",
    type=click.Choice(["semver", "additive-only", "breaking-allowed"]),
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="markdown body (frontmatter is CLI-generated)",
)
@click.option("--body", help="inline markdown body (prefer --body-file or stdin)")
@click.pass_context
def cmd(
    ctx: click.Context,
    slug: str,
    contract_kind: str,
    title: str,
    versioning: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Open a PR adding a new contract file. Caller: hermes-design only."""
    with SubcommandRun(ctx, "add-contract") as run:
        body_content = read_body_arg(body_file, body)
        _validate_slug(slug)

        # Idempotency: by slug
        key = ("slug", slug)
        ch = content_hash(slug, contract_kind, title, body_content)
        if run.cache_get(key, ch):
            return

        target = run.repo_root / ".rlm" / "contracts" / f"{slug}.md"
        if target.exists():
            raise PreconditionFailedError(
                f"Contract file {target.relative_to(run.repo_root)} already exists in working tree",
                subcommand="add-contract",
            )

        fm: dict = {
            "type": "contract",
            "name": slug,
            "contract_kind": contract_kind,
            "status": "active",
            "versioning": versioning,
            "created": datetime.now(timezone.utc).date().isoformat(),
            "supersedes": None,
            "superseded_by": None,
        }
        full_body = serialize_frontmatter(fm, body_content.lstrip())

        branch = f"contract/{slug}"
        pr_body = (
            f"Contract: {slug} ({contract_kind})\n\n"
            f"<!-- CLI-generated. Body below. -->\n\n"
            f"{body_content.strip()}\n"
        )

        run.reasoning = f"opening PR for new contract {slug!r} ({contract_kind})"

        if run.dry_run:
            run.set_result(ok=True, dry_run=True, would_add_contract=slug)
            return

        result = pr_route.open_pr_for_file_change(
            repo_root=run.repo_root,
            branch=branch,
            file_path=target,
            file_content=full_body,
            commit_message=f"contract: {slug}",
            pr_title=f"Contract: {slug} ({contract_kind})",
            pr_body=pr_body,
        )

        run.add_affected("rlm", str(target.relative_to(run.repo_root)), "created")
        run.add_affected("pr", f"#{result.pr_number}", "opened")
        run.set_result(
            ok=True,
            slug=slug,
            contract_kind=contract_kind,
            branch=result.branch,
            pr_number=result.pr_number,
            pr_url=result.pr_url,
            commit_sha=result.commit_sha,
        )
