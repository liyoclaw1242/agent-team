"""Tests for `.rlm/` walk-up discovery."""

from __future__ import annotations

from pathlib import Path

import pytest

from rlm.discover import find_rlm_root
from rlm.errors import NoRlmRootError


def test_finds_rlm_when_cwd_is_root(tmp_rlm_repo: Path) -> None:
    found = find_rlm_root(start=tmp_rlm_repo)
    assert found == tmp_rlm_repo.resolve()


def test_finds_rlm_when_cwd_is_subdir(tmp_rlm_repo: Path) -> None:
    deep = tmp_rlm_repo / "a" / "b" / "c"
    deep.mkdir(parents=True)
    found = find_rlm_root(start=deep)
    assert found == tmp_rlm_repo.resolve()


def test_raises_when_no_rlm_anywhere(tmp_path: Path) -> None:
    with pytest.raises(NoRlmRootError):
        find_rlm_root(start=tmp_path)


def test_override_with_valid_root(tmp_rlm_repo: Path) -> None:
    found = find_rlm_root(override=tmp_rlm_repo)
    assert found == tmp_rlm_repo.resolve()


def test_override_with_invalid_root(tmp_path: Path) -> None:
    with pytest.raises(NoRlmRootError):
        find_rlm_root(override=tmp_path)
