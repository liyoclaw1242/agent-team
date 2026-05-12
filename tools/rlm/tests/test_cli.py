"""High-level CLI tests via Click's CliRunner."""

from __future__ import annotations

from click.testing import CliRunner

from rlm.cli import main


def test_help_lists_all_17_subcommands() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["--help"])
    assert result.exit_code == 0

    expected = [
        "propose-adr",
        "propose-context-change",
        "add-contract",
        "append-fact",
        "supersede-fact",
        "append-business-model",
        "append-deployment-constraints",
        "commit-spec",
        "confirm-spec",
        "commit-workpackage",
        "approve-workpackage",
        "record-signal",
        "mark-superseded",
        "mark-in-progress",
        "mark-delivered",
        "open-pr",
        "enqueue-message",
    ]
    for name in expected:
        assert name in result.output, f"--help missing {name!r}"


def test_version_flag() -> None:
    runner = CliRunner()
    result = runner.invoke(main, ["--version"])
    assert result.exit_code == 0
    assert "rlm" in result.output


def test_subcommand_help_renders() -> None:
    """Each subcommand should respond to --help without error."""
    runner = CliRunner()
    for name in [
        "propose-adr",
        "commit-spec",
        "confirm-spec",
        "approve-workpackage",
        "open-pr",
        "enqueue-message",
    ]:
        result = runner.invoke(main, [name, "--help"])
        assert result.exit_code == 0, f"{name} --help failed: {result.output}"
        assert name in result.output
