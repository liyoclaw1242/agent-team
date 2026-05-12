"""Tests for YAML frontmatter parse / serialize / validate."""

from __future__ import annotations

import pytest

from rlm.errors import ValidationError
from rlm.frontmatter import assert_required, assert_type, parse, serialize


def test_parse_no_frontmatter() -> None:
    body = "# Hello\n\nNo frontmatter here.\n"
    fm, parsed_body = parse(body)
    assert fm == {}
    assert parsed_body == body


def test_parse_with_frontmatter() -> None:
    content = "---\ntype: spec\nstatus: draft\n---\n\n# Title\n\nBody here.\n"
    fm, body = parse(content)
    assert fm == {"type": "spec", "status": "draft"}
    assert body == "# Title\n\nBody here.\n"


def test_parse_empty_frontmatter_block() -> None:
    content = "---\n---\n# Title\n"
    fm, body = parse(content)
    assert fm == {}
    assert body == "# Title\n"


def test_parse_malformed_yaml_raises() -> None:
    content = "---\nthis is: : not valid\n---\nbody\n"
    with pytest.raises(ValidationError):
        parse(content)


def test_parse_unterminated_frontmatter_raises() -> None:
    content = "---\ntype: spec\nbody but no closing\n"
    with pytest.raises(ValidationError):
        parse(content)


def test_parse_non_mapping_frontmatter_raises() -> None:
    content = "---\n- just\n- a\n- list\n---\nbody\n"
    with pytest.raises(ValidationError):
        parse(content)


def test_serialize_with_frontmatter() -> None:
    fm = {"type": "fact", "fact_id": "2026-05-12-foo"}
    body = "# Fact body\n"
    out = serialize(fm, body)
    assert out.startswith("---\n")
    assert "type: fact" in out
    assert "fact_id: 2026-05-12-foo" in out
    assert out.endswith("# Fact body\n")
    # Round-trip
    fm_back, body_back = parse(out)
    assert fm_back == fm
    assert body_back == body


def test_serialize_no_frontmatter_returns_body() -> None:
    assert serialize({}, "just body") == "just body"


def test_assert_required_passes() -> None:
    assert_required({"a": 1, "b": 2}, ["a", "b"])


def test_assert_required_missing_raises() -> None:
    with pytest.raises(ValidationError) as excinfo:
        assert_required({"a": 1}, ["a", "b"], file_kind="fact")
    assert "b" in excinfo.value.message
    assert "fact" in excinfo.value.message


def test_assert_required_none_value_raises() -> None:
    with pytest.raises(ValidationError):
        assert_required({"a": 1, "b": None}, ["a", "b"])


def test_assert_type_passes() -> None:
    assert_type({"type": "spec"}, "spec")


def test_assert_type_mismatch_raises() -> None:
    with pytest.raises(ValidationError) as excinfo:
        assert_type({"type": "fact"}, "spec")
    assert "spec" in excinfo.value.message
    assert "fact" in excinfo.value.message
