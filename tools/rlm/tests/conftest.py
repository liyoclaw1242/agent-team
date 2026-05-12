"""Test fixtures for rlm-cli."""

from __future__ import annotations

from collections.abc import Generator
from pathlib import Path

import pytest


@pytest.fixture
def tmp_rlm_repo(tmp_path: Path) -> Path:
    """A temporary repo root with a minimal `.rlm/` skeleton.

    Mirrors the layout of the real `.rlm/` in `D:/darfts/.rlm/` enough for
    foundation-level tests. Subcommand tests that need richer fixtures should
    add to this skeleton in their own fixture/setup.
    """
    rlm = tmp_path / ".rlm"
    rlm.mkdir()
    (rlm / "adr").mkdir()
    (rlm / "contracts").mkdir()
    (rlm / "facts").mkdir()
    (rlm / "business").mkdir()
    (rlm / "bc" / "intake").mkdir(parents=True)
    (rlm / "bc" / "design").mkdir()
    (rlm / "bc" / "delivery").mkdir()

    # Sentinel files
    (rlm / "CONTEXT-MAP.md").write_text("# Test CONTEXT-MAP\n", encoding="utf-8")
    (rlm / "bc" / "intake" / "CONTEXT.md").write_text("# Intake\n", encoding="utf-8")

    return tmp_path


@pytest.fixture
def clean_env(monkeypatch: pytest.MonkeyPatch) -> Generator[None, None, None]:
    """Strip RLM_AGENT_* and REDIS_URL env vars for the test."""
    for k in ("RLM_AGENT_ROLE", "RLM_AGENT_INVOCATION", "RLM_SKILL_NAME", "REDIS_URL"):
        monkeypatch.delenv(k, raising=False)
    yield


@pytest.fixture
def as_worker(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set caller identity to worker."""
    monkeypatch.setenv("RLM_AGENT_ROLE", "worker")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_worker_001")


@pytest.fixture
def as_hermes(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set caller identity to hermes (intake)."""
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_hermes_001")
    monkeypatch.setenv("RLM_SKILL_NAME", "signal-to-spec")


@pytest.fixture
def as_hermes_design(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set caller identity to hermes-design."""
    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes-design")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_design_001")
    monkeypatch.setenv("RLM_SKILL_NAME", "decompose-spec")


@pytest.fixture
def as_dispatch(monkeypatch: pytest.MonkeyPatch) -> None:
    """Set caller identity to dispatch."""
    monkeypatch.setenv("RLM_AGENT_ROLE", "dispatch")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_test_dispatch_001")
