"""commit-workpackage — create a type:workpackage Issue at status:draft.

See .rlm/contracts/rlm-cli.md § Detailed: commit-workpackage.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Any

import click
import yaml

from rlm.adapters import gh
from rlm.errors import PreconditionFailedError, ValidationError
from rlm.frontmatter import parse as parse_frontmatter
from rlm.frontmatter import serialize as serialize_frontmatter
from rlm.runner import SubcommandRun, content_hash, read_body_arg

_AC_HEADER = re.compile(r"^##\s+AcceptanceCriteria\b", re.MULTILINE | re.IGNORECASE)
_AC_ITEM = re.compile(r"^\s*-\s+\[[ x]\]\s+\S", re.MULTILINE)

_REQUIRED_IMPACT_SCOPE_KEYS = {
    "files",
    "modules",
    "seams",
    "contracts",
    "external_systems",
    "estimated_complexity",
}


def _parse_csv_ints(value: str) -> list[int]:
    """Parse a comma-separated list of ints (empty string → empty list)."""
    if not value.strip():
        return []
    try:
        return [int(x.strip()) for x in value.split(",") if x.strip()]
    except ValueError as e:
        raise ValidationError(
            f"Cannot parse as comma-separated ints: {value!r}",
            field="csv",
        ) from e


def _validate_body_has_acs(body: str) -> int:
    """Same shape as commit-spec's: WP body must have ## AcceptanceCriteria."""
    header_match = _AC_HEADER.search(body)
    if not header_match:
        raise ValidationError(
            "WorkPackage body must contain a `## AcceptanceCriteria` section",
            field="body",
        )
    after_header = body[header_match.end() :]
    next_header = re.search(r"^##?\s", after_header, re.MULTILINE)
    section = after_header[: next_header.start()] if next_header else after_header
    items = _AC_ITEM.findall(section)
    if not items:
        raise ValidationError(
            "AcceptanceCriteria section must contain at least one `- [ ]` item",
            field="body",
        )
    return len(items)


def _load_impact_scope(path: Path) -> dict[str, Any]:
    try:
        raw = yaml.safe_load(path.read_text(encoding="utf-8"))
    except yaml.YAMLError as e:
        raise ValidationError(
            f"--impact-scope-file is not valid YAML: {e}",
            field="impact_scope",
        ) from e

    if not isinstance(raw, dict):
        raise ValidationError(
            "--impact-scope-file must be a YAML mapping",
            field="impact_scope",
        )

    # Accept either a flat dict (the fields) or one wrapped under `impact_scope:`
    if "impact_scope" in raw and isinstance(raw["impact_scope"], dict):
        scope = raw["impact_scope"]
    else:
        scope = raw

    missing = _REQUIRED_IMPACT_SCOPE_KEYS - set(scope.keys())
    if missing:
        raise ValidationError(
            f"impact_scope missing required key(s): {sorted(missing)}",
            field="impact_scope",
            details={"missing": sorted(missing)},
        )

    return scope


def _verify_parent_spec(parent_spec: int) -> None:
    data = gh.issue_view(parent_spec, fields=["labels"])
    labels = {entry["name"] for entry in data.get("labels", []) if "name" in entry}
    if "type:spec" not in labels:
        raise PreconditionFailedError(
            f"--parent-spec #{parent_spec} is not a type:spec Issue",
            subcommand="commit-workpackage",
            details={"actual_labels": sorted(labels)},
        )
    if "status:confirmed" not in labels:
        raise PreconditionFailedError(
            f"--parent-spec #{parent_spec} is not status:confirmed "
            f"(got {sorted(label for label in labels if label.startswith('status:'))})",
            subcommand="commit-workpackage",
            details={"actual_labels": sorted(labels)},
        )


def _verify_depends_on_are_wps(depends_on: list[int]) -> None:
    for dep in depends_on:
        data = gh.issue_view(dep, fields=["labels"])
        labels = {entry["name"] for entry in data.get("labels", []) if "name" in entry}
        if "type:workpackage" not in labels:
            raise PreconditionFailedError(
                f"--depends-on references #{dep} which is not a type:workpackage",
                subcommand="commit-workpackage",
                details={"dep": dep, "actual_labels": sorted(labels)},
            )


def _find_existing_wp_for_parent_and_title(parent_spec: int, title: str) -> int | None:
    """Return existing WP Issue # with the same (parent_spec, title), or None."""
    matches = gh.issue_list(
        labels=["type:workpackage"],
        state="all",
        search=f"parent_spec: {parent_spec}",
        fields=["number", "title", "body"],
    )
    for entry in matches:
        body = entry.get("body", "") or ""
        fm, _ = parse_frontmatter(body)
        if fm.get("parent_spec") == parent_spec and entry.get("title") == title:
            return int(entry["number"])
    return None


def _build_full_body(
    body_content: str,
    *,
    parent_spec: int,
    worker_class: str,
    adr_refs: list[int],
    depends_on: list[int],
    impact_scope: dict[str, Any],
    slice_type: str,
    ac_count: int,
) -> str:
    fm: dict[str, Any] = {
        "type": "workpackage",
        "status": "draft",
        "parent_spec": parent_spec,
        "worker_class": worker_class,
        "adr_refs": adr_refs,
        "depends_on": depends_on,
        "impact_scope": impact_scope,
        "acceptance_criteria_count": ac_count,
        "slice_type": slice_type,
    }
    return serialize_frontmatter(fm, body_content.lstrip())


@click.command("commit-workpackage")
@click.option("--parent-spec", required=True, type=int, help="parent Spec Issue number")
@click.option("--title", required=True, help="imperative title")
@click.option(
    "--worker-class",
    default="web-stack",
    type=click.Choice(["web-stack"]),
    help="v1 only web-stack is valid",
)
@click.option("--adr-refs", default="", help="comma-separated ADR numbers (e.g., 1,2)")
@click.option(
    "--depends-on",
    "depends_on_str",
    default="",
    help="comma-separated WP Issue numbers this WP depends on",
)
@click.option(
    "--impact-scope-file",
    required=True,
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="YAML with impact_scope: field (from compute-impact-scope skill)",
)
@click.option(
    "--slice-type",
    default="AFK",
    type=click.Choice(["AFK", "HITL"]),
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="Issue body; MUST contain `## AcceptanceCriteria` with checkboxes",
)
@click.option("--body", help="inline Issue body")
@click.pass_context
def cmd(
    ctx: click.Context,
    parent_spec: int,
    title: str,
    worker_class: str,
    adr_refs: str,
    depends_on_str: str,
    impact_scope_file: Path,
    slice_type: str,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Create a WorkPackage Issue. Caller: hermes-design."""
    with SubcommandRun(ctx, "commit-workpackage") as run:
        body_content = read_body_arg(body_file, body)
        ac_count = _validate_body_has_acs(body_content)

        adr_refs_list = _parse_csv_ints(adr_refs)
        depends_on_list = _parse_csv_ints(depends_on_str)
        impact_scope = _load_impact_scope(impact_scope_file)

        # Idempotency: by (parent_spec, title)
        key = ("parent_spec", parent_spec, "title", title)
        ch = content_hash(str(parent_spec), title, body_content)
        cached = run.cache_get(key, ch)
        if cached:
            return

        _verify_parent_spec(parent_spec)
        _verify_depends_on_are_wps(depends_on_list)

        existing = _find_existing_wp_for_parent_and_title(parent_spec, title)
        if existing is not None:
            raise PreconditionFailedError(
                f"WP with same (parent_spec={parent_spec}, title={title!r}) already exists: #{existing}",
                subcommand="commit-workpackage",
                details={"existing_wp_issue": existing},
            )

        full_body = _build_full_body(
            body_content,
            parent_spec=parent_spec,
            worker_class=worker_class,
            adr_refs=adr_refs_list,
            depends_on=depends_on_list,
            impact_scope=impact_scope,
            slice_type=slice_type,
            ac_count=ac_count,
        )

        run.add_basis("issue", f"#{parent_spec}")
        run.add_basis("rlm", str(impact_scope_file))
        run.reasoning = (
            f"committing draft WorkPackage under Spec #{parent_spec}: {title!r} "
            f"(depends_on={depends_on_list}, adr_refs={adr_refs_list})"
        )

        if run.dry_run:
            run.set_result(
                ok=True,
                dry_run=True,
                would_create_wp_title=title,
                parent_spec=parent_spec,
                ac_count=ac_count,
            )
            return

        issue_number = gh.issue_create(
            title=title,
            body=full_body,
            labels=["type:workpackage", "status:draft"],
        )
        run.add_affected("issue", f"#{issue_number}", "created")
        run.set_result(
            ok=True,
            issue_number=issue_number,
            status="draft",
            parent_spec=parent_spec,
            adr_refs=adr_refs_list,
            depends_on=depends_on_list,
            slice_type=slice_type,
        )
