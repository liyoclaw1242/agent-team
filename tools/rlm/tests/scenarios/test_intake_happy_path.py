"""Scenario 1: Hermes intake happy path — Signal → Spec → confirmed.

Mirrors conversion-drop Phase 1 from .rlm/flow-visualization.html, minus the
business-model snapshot (Layer 4 not yet implemented). Verifies the full CLI
chain produces correct Issue states and a coherent triple chain.
"""

from __future__ import annotations

import json
from pathlib import Path

import pytest
from click.testing import CliRunner

from rlm.cli import main


def _write(path: Path, content: str) -> Path:
    path.write_text(content, encoding="utf-8")
    return path


def test_phase1_signal_to_confirmed_spec(
    runner_env: dict,  # noqa: ARG001 (fixture has side effects)
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = runner_env["github"]
    repo: Path = runner_env["repo"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_scenario1")
    monkeypatch.setenv("RLM_SKILL_NAME", "signal-to-spec")

    # ===== Step 1: record-signal (production-monitor flow) =====
    signal_body = _write(
        repo / "tmp-signal.md",
        "Mobile conversion 7d-avg dropped from 8.2% to 7.0%.\nThreshold: 0.082. Window: 7d.\n",
    )
    result = runner.invoke(
        main,
        [
            "--json",
            "record-signal",
            "--source",
            "production-monitor",
            "--title",
            "mobile_conversion crossed threshold",
            "--body-file",
            str(signal_body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"record-signal failed: stderr={result.stderr}"
    out = json.loads(result.output)
    signal_num = out["issue_number"]
    assert signal_num == 1

    assert fake_gh.issues[signal_num].labels == {"type:signal", "status:draft"}

    # ===== Step 2: commit-spec =====
    spec_body = _write(
        repo / "tmp-spec.md",
        (
            "# Recover mobile booking conversion to ≥ 8.2%\n\n"
            "Restore mobile booking conversion to baseline.\n\n"
            "## AcceptanceCriteria\n\n"
            "- [ ] Mobile booking conversion ≥ 8.2% (ProductionMonitor 7d avg, EoS)\n"
            "- [ ] No regression in desktop conversion\n"
            "- [ ] No regression in fraud-block rate\n\n"
            "## Refs\n\n"
            "- Originating Signal: #1\n"
        ),
    )
    result = runner.invoke(
        main,
        [
            "--json",
            "commit-spec",
            "--signal-ref",
            str(signal_num),
            "--title",
            "Recover mobile booking conversion to ≥ 8.2%",
            "--body-file",
            str(spec_body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"commit-spec failed: stderr={result.stderr}"
    out = json.loads(result.output)
    spec_num = out["issue_number"]
    assert spec_num == 2
    assert out["acceptance_criteria_count"] == 3

    spec_issue = fake_gh.issues[spec_num]
    assert "type:spec" in spec_issue.labels
    assert "status:draft" in spec_issue.labels
    assert "signal_ref: 1" in spec_issue.body  # frontmatter was generated

    # ===== Step 3: confirm-spec =====
    result = runner.invoke(
        main,
        ["--json", "confirm-spec", "--issue", str(spec_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"confirm-spec failed: stderr={result.stderr}"
    out = json.loads(result.output)
    assert out["status"] == "confirmed"

    spec_issue = fake_gh.issues[spec_num]
    assert "status:confirmed" in spec_issue.labels
    assert "status:draft" not in spec_issue.labels

    # ===== Event log: three triples emitted in order =====
    events_path = repo / ".local" / "events.jsonl"
    assert events_path.exists()
    lines = [json.loads(line) for line in events_path.read_text(encoding="utf-8").splitlines()]
    actions = [e["action"] for e in lines]
    assert actions == ["rlm.record-signal", "rlm.commit-spec", "rlm.confirm-spec"]

    # Each triple carries agent_id + invocation_id from env
    for event in lines:
        assert event["agent_id"] == "hermes"
        assert event["invocation_id"] == "inv_scenario1"
        assert event["exit_code"] == 0


def test_record_signal_dedup(
    runner_env: dict,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Two record-signal calls with the same dedup_key within 24h → second is deduped."""
    runner = CliRunner()
    fake_gh = runner_env["github"]
    repo: Path = runner_env["repo"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_dedup")

    body = _write(repo / "sig.md", "Anomaly: latency spike.\n")

    # First call: creates
    result = runner.invoke(
        main,
        [
            "--json",
            "record-signal",
            "--source",
            "production-monitor",
            "--title",
            "latency anomaly",
            "--dedup-key",
            "latency-p95-anomaly",
            "--body-file",
            str(body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0
    out = json.loads(result.output)
    assert out["deduplicated"] is False
    first_num = out["issue_number"]

    # Second call with same dedup_key: should not create a duplicate
    # (Note: with our idempotency cache, this would be cache-hit; we also test
    # the gh-list-based dedup by clearing the cache via a different body.)
    body2 = _write(repo / "sig2.md", "Anomaly: latency spike (resampled).\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "record-signal",
            "--source",
            "production-monitor",
            "--title",
            "latency anomaly v2",
            "--dedup-key",
            "latency-p95-anomaly",
            "--body-file",
            str(body2),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0
    out = json.loads(result.output)
    assert out["deduplicated"] is True
    assert out["issue_number"] == first_num
    # Only one Signal Issue in fake_gh
    assert len([i for i in fake_gh.issues.values() if "type:signal" in i.labels]) == 1
