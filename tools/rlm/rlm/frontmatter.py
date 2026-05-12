"""YAML frontmatter parse / serialize / validate.

Markdown files written by the CLI have YAML frontmatter delimited by `---`
lines. The CLI generates frontmatter; agents author the body below it.

Per contract § Frontmatter schemas — supports ADR / contract / fact /
business-model / deployment-constraints / supervision-alert.
"""

from __future__ import annotations

from typing import Any

import yaml

from rlm.errors import ValidationError

DELIMITER = "---"


def parse(content: str) -> tuple[dict[str, Any], str]:
    """Split a markdown document into (frontmatter_dict, body).

    If no frontmatter block is present, returns ({}, content).
    Frontmatter block: starts with `---\\n` at the very first line; ends with
    a second `---\\n` line.

    Raises:
        ValidationError if a frontmatter delimiter is present but malformed
        (e.g., unterminated, non-YAML content).
    """
    if not content.startswith(DELIMITER + "\n") and not content.startswith(DELIMITER + "\r\n"):
        return {}, content

    # Find the closing delimiter
    lines = content.splitlines(keepends=True)
    # lines[0] is the opening "---\n"; find next "---\n"
    closing_idx: int | None = None
    for i in range(1, len(lines)):
        if lines[i].strip() == DELIMITER:
            closing_idx = i
            break

    if closing_idx is None:
        raise ValidationError(
            "Frontmatter opened with '---' but no closing '---' delimiter found",
            field="frontmatter",
        )

    fm_text = "".join(lines[1:closing_idx])
    body = "".join(lines[closing_idx + 1 :])
    # Strip a single leading newline from body (after `---\n`) for cleanliness
    if body.startswith("\n"):
        body = body[1:]
    elif body.startswith("\r\n"):
        body = body[2:]

    try:
        fm_data = yaml.safe_load(fm_text)
    except yaml.YAMLError as e:
        raise ValidationError(
            f"Frontmatter is not valid YAML: {e}",
            field="frontmatter",
        ) from e

    if fm_data is None:
        return {}, body

    if not isinstance(fm_data, dict):
        raise ValidationError(
            f"Frontmatter must be a YAML mapping, got {type(fm_data).__name__}",
            field="frontmatter",
        )

    return fm_data, body


def serialize(frontmatter: dict[str, Any], body: str) -> str:
    """Build a markdown document from frontmatter dict + body string.

    Always uses LF line endings (\\n). If body does not start with a blank
    line, one is inserted after the closing `---`.
    """
    if not frontmatter:
        return body

    fm_yaml = yaml.safe_dump(
        frontmatter,
        sort_keys=False,
        default_flow_style=False,
        allow_unicode=True,
    )
    # safe_dump ends with \n; ensure body separated by exactly one blank line
    sep = "" if body.startswith("\n") else "\n"
    return f"{DELIMITER}\n{fm_yaml}{DELIMITER}\n{sep}{body}"


def assert_required(fm: dict[str, Any], required: list[str], *, file_kind: str = "file") -> None:
    """Raise ValidationError if any required key is missing or None-valued.

    The `file_kind` is included in the error message for context.
    """
    missing = [k for k in required if k not in fm or fm[k] is None]
    if missing:
        raise ValidationError(
            f"Required frontmatter field(s) missing on {file_kind}: {', '.join(missing)}",
            field="frontmatter",
            details={"missing": missing},
        )


def assert_type(fm: dict[str, Any], expected_type: str) -> None:
    """Assert frontmatter `type` field matches expected (e.g., 'spec', 'adr')."""
    actual = fm.get("type")
    if actual != expected_type:
        raise ValidationError(
            f"Expected frontmatter type {expected_type!r}, got {actual!r}",
            field="type",
            details={"expected": expected_type, "actual": actual},
        )


__all__ = ["parse", "serialize", "assert_required", "assert_type", "DELIMITER"]
