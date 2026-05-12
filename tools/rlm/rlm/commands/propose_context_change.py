"""propose-context-change — open a PR editing CONTEXT.md or CONTEXT-MAP.md.

See .rlm/contracts/rlm-cli.md § Detailed: propose-context-change.

v0.1 supports --new-content-file (full replacement) only. --diff-file
(unified diff application) is deferred to a later version — captured in
contract open questions.
"""

from __future__ import annotations

import re
from pathlib import Path

import click

from rlm.errors import PreconditionFailedError, ValidationError
from rlm.routing import pr as pr_route
from rlm.runner import SubcommandRun, content_hash

_SLUG_RE = re.compile(r"[^a-z0-9-]")
_VALID_TARGETS = re.compile(r"^(CONTEXT-MAP\.md|bc/[a-z0-9_-]+/CONTEXT\.md)$")


def _slug_from_reason(reason: str) -> str:
    """Convert free-form reason text into a kebab-case branch suffix.

    Truncated to 40 chars. Empty after normalization → 'edit'.
    """
    s = reason.lower().strip()
    s = _SLUG_RE.sub("-", s)
    s = re.sub(r"-+", "-", s).strip("-")
    return s[:40] or "edit"


@click.command("propose-context-change")
@click.option(
    "--target",
    required=True,
    help="path relative to .rlm/ (e.g., bc/intake/CONTEXT.md or CONTEXT-MAP.md)",
)
@click.option(
    "--diff-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="unified diff file (NOT YET IMPLEMENTED in v0.1; use --new-content-file)",
)
@click.option(
    "--new-content-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="complete replacement content for the target file",
)
@click.option("--reason", required=True, help="short summary used in PR title")
@click.pass_context
def cmd(
    ctx: click.Context,
    target: str,
    diff_file: Path | None,
    new_content_file: Path | None,
    reason: str,
) -> None:
    """Open a PR editing a CONTEXT.md or CONTEXT-MAP.md. Caller: hermes-design only."""
    with SubcommandRun(ctx, "propose-context-change") as run:
        # Validate target
        if not _VALID_TARGETS.match(target):
            raise ValidationError(
                f"--target must be CONTEXT-MAP.md or bc/<bc>/CONTEXT.md; got {target!r}",
                field="target",
            )

        if diff_file is not None and new_content_file is None:
            raise ValidationError(
                "--diff-file is not yet implemented in v0.1; use --new-content-file",
                field="diff_file",
            )
        if new_content_file is None:
            raise ValidationError(
                "--new-content-file is required (use full replacement; --diff-file deferred)",
                field="new_content_file",
            )

        target_path = run.repo_root / ".rlm" / target
        if not target_path.exists():
            raise PreconditionFailedError(
                f"--target {target!r} does not exist in .rlm/",
                subcommand="propose-context-change",
                details={"target": target},
            )

        new_content = new_content_file.read_text(encoding="utf-8")

        # Idempotency: by (target, content hash) — re-running with same content is a no-op
        key = ("target", target)
        ch = content_hash(target, new_content)
        if run.cache_get(key, ch):
            return

        existing = target_path.read_text(encoding="utf-8")
        if existing == new_content:
            raise ValidationError(
                "--new-content-file is identical to current file content; no change to propose",
                field="new_content_file",
            )

        slug = _slug_from_reason(reason)
        branch = f"context-change/{slug}"

        pr_body = (
            f"Context change: {reason}\n\n"
            f"Target: `{target}`\n\n"
            f"<!-- CLI-routed via propose-context-change (full-content replacement). -->\n"
        )

        run.reasoning = f"opening PR to edit {target!r}: {reason!r}"

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_branch=branch,
                target=target,
            )
            return

        result = pr_route.open_pr_for_file_change(
            repo_root=run.repo_root,
            branch=branch,
            file_path=target_path,
            file_content=new_content,
            commit_message=f"context: {reason}",
            pr_title=f"Context change: {reason}",
            pr_body=pr_body,
        )

        run.add_affected("rlm", str(target_path.relative_to(run.repo_root)), "edited")
        run.add_affected("pr", f"#{result.pr_number}", "opened")
        run.set_result(
            ok=True,
            target=target,
            branch=result.branch,
            pr_number=result.pr_number,
            pr_url=result.pr_url,
            commit_sha=result.commit_sha,
        )
