"""approve-workpackage — flip status:draft → status:approved on a WorkPackage.

Mechanically verifies all `adr_refs` are merged to main before allowing the
flip. This is the load-bearing "ADR is a gate" check (per ADR-0013).

See .rlm/contracts/rlm-cli.md § Detailed: approve-workpackage.
"""

from __future__ import annotations

import re

import click

from rlm.adapters import gh, git
from rlm.errors import PreconditionFailedError, ValidationError
from rlm.frontmatter import parse as parse_frontmatter
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.routing import issue as issue_route
from rlm.runner import SubcommandRun

_ADR_FILE_RE = re.compile(r"^\.rlm/adr/(\d{4})-")


def _adr_numbers_on_main(repo_root) -> set[int]:
    """Return the set of ADR numbers that have a corresponding file on main."""
    paths = git.list_tree_main_paths(cwd=repo_root)
    nums: set[int] = set()
    for path in paths:
        m = _ADR_FILE_RE.match(path)
        if m:
            nums.add(int(m.group(1)))
    return nums


def _parse_adr_refs_from_body(body: str) -> list[int]:
    """Extract `adr_refs:` list from the WorkPackage Issue body's frontmatter."""
    fm, _ = parse_frontmatter(body)
    refs = fm.get("adr_refs", [])
    if refs is None:
        return []
    if not isinstance(refs, list):
        raise ValidationError(
            f"WorkPackage frontmatter `adr_refs` must be a list, got {type(refs).__name__}",
            field="adr_refs",
        )
    out: list[int] = []
    for entry in refs:
        if isinstance(entry, int):
            out.append(entry)
        elif isinstance(entry, str):
            # tolerate "0001" string form
            try:
                out.append(int(entry))
            except ValueError as e:
                raise ValidationError(
                    f"adr_refs entry {entry!r} is not an integer",
                    field="adr_refs",
                ) from e
        else:
            raise ValidationError(
                f"adr_refs entry {entry!r} is not int-or-string",
                field="adr_refs",
            )
    return out


def _stamp_auto_approved(body: str) -> str:
    fm, body_text = parse_frontmatter(body)
    if not fm:
        return body
    fm["auto_approved"] = True
    return serialize_frontmatter(fm, body_text)


@click.command("approve-workpackage")
@click.option("--issue", "issue_num", required=True, type=int, help="WorkPackage Issue number")
@click.option(
    "--auto-approved",
    is_flag=True,
    help="set if fired via auto-approve timeout (per ADR-0005)",
)
@click.pass_context
def cmd(ctx: click.Context, issue_num: int, auto_approved: bool) -> None:
    """Flip WP status:draft → status:approved. Verifies adr_refs merged. Caller: hermes-design."""
    with SubcommandRun(ctx, "approve-workpackage") as run:
        key = ("issue", issue_num, "to", "approved")
        if run.cache_get(key):
            return

        # Read WP Issue
        try:
            data = issue_route.verify_issue_exists(issue_num, expected_type="workpackage")
        except ValidationError as e:
            raise PreconditionFailedError(
                e.message, subcommand="approve-workpackage", details=e.details
            ) from e

        body = data.get("body", "") or ""
        adr_refs = _parse_adr_refs_from_body(body)

        # Mechanical verification: every adr_ref must have a file on main
        merged_nums = _adr_numbers_on_main(run.repo_root)
        unmerged = sorted(n for n in adr_refs if n not in merged_nums)
        if unmerged:
            raise PreconditionFailedError(
                f"adr_refs not yet merged on main: {unmerged}",
                subcommand="approve-workpackage",
                field="adr_refs",
                details={"unmerged": unmerged, "required": adr_refs},
            )

        run.add_basis("issue", f"#{issue_num}")
        for n in adr_refs:
            run.add_basis("rlm", f".rlm/adr/{n:04d}-*.md")
        run.reasoning = (
            f"approving WP #{issue_num} after verifying adr_refs {adr_refs} all merged"
            + (" (auto-approved via timeout)" if auto_approved else "")
        )

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_approve_issue=issue_num,
                adr_refs_verified=adr_refs,
            )
            return

        if auto_approved:
            new_body = _stamp_auto_approved(body)
            gh.issue_edit(issue_num, body=new_body)

        issue_route.flip_status(
            issue_number=issue_num,
            from_status="draft",
            to_status="approved",
            require_type="workpackage",
        )

        run.add_affected("issue", f"#{issue_num}", "relabeled")
        run.set_result(
            ok=True,
            issue=issue_num,
            status="approved",
            adr_refs_verified=adr_refs,
            auto_approved=auto_approved,
        )
