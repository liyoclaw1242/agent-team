"""commit-spec — create a type:spec Issue at status:draft.

See .rlm/contracts/rlm-cli.md § Detailed: commit-spec.
"""

from __future__ import annotations

import re
from pathlib import Path

import click

from rlm.adapters import gh
from rlm.errors import PreconditionFailedError, ValidationError
from rlm.frontmatter import parse as parse_frontmatter
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.routing import issue as issue_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg

# Match `## AcceptanceCriteria` (case-insensitive, allow optional decoration)
_AC_HEADER = re.compile(r"^##\s+AcceptanceCriteria\b", re.MULTILINE | re.IGNORECASE)
# Markdown task-list checkbox
_AC_ITEM = re.compile(r"^\s*-\s+\[[ x]\]\s+\S", re.MULTILINE)


def _validate_body_has_acs(body: str) -> int:
    """Verify body has a `## AcceptanceCriteria` section with ≥1 checkbox item.

    Returns the count of ACs found. Raises ValidationError if section missing
    or has zero checkboxes.
    """
    header_match = _AC_HEADER.search(body)
    if not header_match:
        raise ValidationError(
            "Spec body must contain a `## AcceptanceCriteria` section",
            field="body",
        )

    # Search for checkbox items after the AC header
    after_header = body[header_match.end() :]
    # Stop at the next H2/H1
    next_header = re.search(r"^##?\s", after_header, re.MULTILINE)
    section = after_header[: next_header.start()] if next_header else after_header
    items = _AC_ITEM.findall(section)
    if not items:
        raise ValidationError(
            "AcceptanceCriteria section must contain at least one `- [ ]` item",
            field="body",
        )
    return len(items)


def _verify_signal_exists(signal_ref: int) -> None:
    """Verify the signal_ref points to an existing type:signal Issue."""
    try:
        issue_route.verify_issue_exists(signal_ref, expected_type="signal")
    except ValidationError as e:
        raise PreconditionFailedError(
            f"--signal-ref #{signal_ref} is not a type:signal Issue",
            subcommand="commit-spec",
            details=e.details,
        ) from e


def _find_existing_spec_for_signal(signal_ref: int) -> int | None:
    """Return existing Spec Issue # for this signal_ref, or None."""
    matches = gh.issue_list(
        labels=["type:spec"],
        state="all",
        search=f"signal_ref: {signal_ref}",
        fields=["number", "body"],
    )
    for entry in matches:
        body = entry.get("body", "") or ""
        # Check frontmatter signal_ref to avoid false-positive search matches
        fm, _ = parse_frontmatter(body)
        if fm.get("signal_ref") == signal_ref:
            return int(entry["number"])
    return None


def _build_full_body(
    body_content: str,
    *,
    signal_ref: int,
    business_model_ref: str | None,
    deployment_constraints_ref: str | None,
    ac_count: int,
) -> str:
    """Prepend the CLI-generated frontmatter to the body."""
    fm = {
        "type": "spec",
        "status": "draft",
        "signal_ref": signal_ref,
        "acceptance_criteria_count": ac_count,
    }
    if business_model_ref:
        fm["business_model_ref"] = business_model_ref
    if deployment_constraints_ref:
        fm["deployment_constraints_ref"] = deployment_constraints_ref

    return serialize_frontmatter(fm, body_content.lstrip())


@click.command("commit-spec")
@click.option("--signal-ref", required=True, type=int, help="originating Signal Issue number")
@click.option("--title", required=True, help="Issue title (imperative, outcome-focused)")
@click.option(
    "--business-model-ref",
    help="path to business-model snapshot (e.g., .rlm/business/business-model-<date>.md)",
)
@click.option("--deployment-constraints-ref", help="path to deployment-constraints snapshot")
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
    with SubcommandRun(ctx, "commit-spec") as run:
        body_content = read_body_arg(body_file, body)
        ac_count = _validate_body_has_acs(body_content)

        # Idempotency: by signal_ref
        key = ("signal_ref", signal_ref)
        ch = content_hash(str(signal_ref), title, body_content)
        cached = run.cache_get(key, ch)
        if cached:
            return

        # Verify signal exists + is type:signal
        _verify_signal_exists(signal_ref)

        # Dedup against existing Spec for same signal_ref
        existing = _find_existing_spec_for_signal(signal_ref)
        if existing is not None:
            raise PreconditionFailedError(
                f"A Spec already exists for signal_ref={signal_ref}: #{existing}. "
                "Use `rlm mark-superseded --issue <existing> --by <new>` first if you want a new one.",
                subcommand="commit-spec",
                details={"existing_spec_issue": existing},
            )

        # Build the full body with frontmatter
        full_body = _build_full_body(
            body_content,
            signal_ref=signal_ref,
            business_model_ref=business_model_ref,
            deployment_constraints_ref=deployment_constraints_ref,
            ac_count=ac_count,
        )

        run.add_basis("issue", f"#{signal_ref}")
        if business_model_ref:
            run.add_basis("rlm", business_model_ref)
        if deployment_constraints_ref:
            run.add_basis("rlm", deployment_constraints_ref)
        run.reasoning = f"committing draft Spec for signal #{signal_ref}: {title!r}"

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_create_spec_title=title,
                ac_count=ac_count,
            )
            return

        issue_number = gh.issue_create(
            title=title,
            body=full_body,
            labels=["type:spec", "status:draft"],
        )
        run.add_affected("issue", f"#{issue_number}", "created")
        run.set_result(
            ok=True,
            issue_number=issue_number,
            status="draft",
            acceptance_criteria_count=ac_count,
        )
