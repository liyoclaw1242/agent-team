"""Scenario 2: Spec supersession — draft Spec replaced by a new one.

Tests mark-superseded as the lifecycle bridge when an edit needs to happen
after a Spec is committed. Verifies cross-references via comments.
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


SPEC_BODY_A = """# Reduce signup friction

Reduce signup form length.

## AcceptanceCriteria

- [ ] Signup form has ≤ 3 fields
- [ ] No regression in spam-block rate
"""

SPEC_BODY_B = """# Reduce signup friction — payment-step first

Reorder signup to put payment before email confirmation.

## AcceptanceCriteria

- [ ] Signup completes in ≤ 30s on iOS Safari
- [ ] No regression in spam-block rate
- [ ] Payment captured before account creation
"""


def test_supersede_draft_spec_with_new(
    runner_env: dict,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    runner = CliRunner()
    fake_gh = runner_env["github"]
    repo: Path = runner_env["repo"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_supersede")

    # Setup: a Signal
    sig_body = _write(repo / "sig.md", "Signup friction.\n")
    result = runner.invoke(
        main,
        [
            "--json",
            "record-signal",
            "--source",
            "human",
            "--title",
            "Signup friction reduction",
            "--body-file",
            str(sig_body),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0
    signal_num = json.loads(result.output)["issue_number"]

    # Commit first Spec
    spec_a = _write(repo / "spec_a.md", SPEC_BODY_A)
    result = runner.invoke(
        main,
        [
            "--json",
            "commit-spec",
            "--signal-ref",
            str(signal_num),
            "--title",
            "Reduce signup friction",
            "--body-file",
            str(spec_a),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0
    spec_a_num = json.loads(result.output)["issue_number"]
    assert "type:spec" in fake_gh.issues[spec_a_num].labels
    assert "status:draft" in fake_gh.issues[spec_a_num].labels

    # A second commit-spec for same signal should FAIL with precondition (Spec already exists)
    # — to commit a new spec, we must supersede first.
    spec_a_dup = _write(repo / "spec_a_dup.md", SPEC_BODY_A)
    result = runner.invoke(
        main,
        [
            "--json",
            "commit-spec",
            "--signal-ref",
            str(signal_num),
            "--title",
            "Different title same signal",
            "--body-file",
            str(spec_a_dup),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 6  # precondition-failed
    err = json.loads(result.stderr)
    assert err["error"] == "precondition-failed"
    assert err["details"]["existing_spec_issue"] == spec_a_num

    # Now: rewind by superseding the draft. First, create the new Spec Issue
    # — but commit-spec refuses while #spec_a_num still exists. We must
    # supersede it FIRST so the new commit-spec can succeed.
    #
    # Actually order: supersede-by needs the NEW spec to exist already. But
    # commit-spec refuses while the OLD spec exists. So:
    #   Option 1: directly inject the new spec issue via fake_gh (test fixture)
    #   Option 2: relabel the old spec out of `type:spec` first (not allowed)
    #
    # The contract's intended flow is: redraft + confirm a NEW spec via a NEW
    # signal_ref, then supersede. Or: supersede-fact-style — the supersede
    # CLI takes care of marking the old. For workflow Issues, the discipline
    # in ADR-0013 is "create a new Issue with `Supersedes #<old>` in its body,
    # and label the old one `status:superseded`". So the rewind order should be:
    #   1. Pre-mark the old spec as superseded (use mark-superseded with the
    #      target referencing the future-new-issue number). But we don't have
    #      that yet.
    #
    # For this test scenario, we exercise the cross-reference comment path by
    # directly injecting the new spec via the fake_gh test API, then call
    # mark-superseded to verify the label flip + cross-references.

    spec_b_num = fake_gh.add_issue(
        title="Reduce signup friction — payment-step first",
        body=SPEC_BODY_B,
        labels=["type:spec", "status:draft"],
    )

    # mark-superseded
    result = runner.invoke(
        main,
        [
            "--json",
            "mark-superseded",
            "--issue",
            str(spec_a_num),
            "--by",
            str(spec_b_num),
        ],
        catch_exceptions=False,
    )
    assert result.exit_code == 0, f"mark-superseded failed: stderr={result.stderr}"
    out = json.loads(result.output)
    assert out["status"] == "superseded"
    assert out["by"] == spec_b_num

    # Assertions
    old = fake_gh.issues[spec_a_num]
    new = fake_gh.issues[spec_b_num]

    assert "status:superseded" in old.labels
    assert "status:draft" not in old.labels  # got removed
    assert "status:draft" in new.labels  # new is still draft

    # Cross-reference comments
    assert any(f"Superseded by #{spec_b_num}" in c for c in old.comments)
    assert any(f"Supersedes #{spec_a_num}" in c for c in new.comments)

    # Now we can confirm the new spec
    result = runner.invoke(
        main,
        ["--json", "confirm-spec", "--issue", str(spec_b_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 0
    assert "status:confirmed" in fake_gh.issues[spec_b_num].labels


def test_mark_superseded_rejects_type_mismatch(
    runner_env: dict,  # noqa: ARG001
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Superseding requires both Issues share the same type:* label."""
    runner = CliRunner()
    fake_gh = runner_env["github"]

    monkeypatch.setenv("RLM_AGENT_ROLE", "hermes")
    monkeypatch.setenv("RLM_AGENT_INVOCATION", "inv_typecheck")

    spec_num = fake_gh.add_issue(title="A spec", body="", labels=["type:spec", "status:draft"])
    signal_num = fake_gh.add_issue(
        title="A signal", body="", labels=["type:signal", "status:draft"]
    )

    result = runner.invoke(
        main,
        ["--json", "mark-superseded", "--issue", str(spec_num), "--by", str(signal_num)],
        catch_exceptions=False,
    )
    assert result.exit_code == 6
    err = json.loads(result.stderr)
    assert err["error"] == "precondition-failed"
