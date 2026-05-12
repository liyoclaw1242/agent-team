"""Main Click entrypoint.

Defines the top-level `rlm` group with global flags and registers all 17
subcommands. Per contract § Invocation conventions.

Each subcommand lives in `rlm.commands.<subcommand>` and exposes `cmd` as
its Click command.
"""

from __future__ import annotations

import json
import sys
from pathlib import Path
from typing import Any

import click

from rlm import __version__
from rlm.discover import find_rlm_root
from rlm.errors import RlmError
from rlm.identity import Caller
from rlm.triples import TripleEmitter

# Click context object key namespace
CTX_RLM_ROOT = "rlm_root"
CTX_JSON_OUTPUT = "json_output"
CTX_DRY_RUN = "dry_run"
CTX_QUIET = "quiet"
CTX_VERBOSE = "verbose"
CTX_CALLER = "caller"
CTX_EMITTER = "emitter"


@click.group(
    context_settings={"help_option_names": ["--help", "-h"]},
    help="rlm — unified write interface for the AI Agent-Team RLM. See .rlm/contracts/rlm-cli.md.",
)
@click.version_option(version=__version__, prog_name="rlm")
@click.option(
    "--json", "json_output", is_flag=True, help="machine-readable single-line JSON to stdout"
)
@click.option(
    "--rlm-root",
    type=click.Path(file_okay=False, dir_okay=True, path_type=Path),
    default=None,
    help="override .rlm/ walk-up discovery",
)
@click.option(
    "--dry-run",
    is_flag=True,
    help="log what would happen + emit a dry-run triple, but make no external changes",
)
@click.option("--quiet", is_flag=True, help="suppress human-readable progress")
@click.option("--verbose", is_flag=True, help="extra diagnostic to stderr")
@click.pass_context
def main(
    ctx: click.Context,
    json_output: bool,
    rlm_root: Path | None,
    dry_run: bool,
    quiet: bool,
    verbose: bool,
) -> None:
    """Top-level group. Resolves .rlm/ root, builds Caller from env vars,
    and constructs the TripleEmitter. Subcommands read these from ctx.obj.
    """
    ctx.ensure_object(dict)
    ctx.obj[CTX_JSON_OUTPUT] = json_output
    ctx.obj[CTX_DRY_RUN] = dry_run
    ctx.obj[CTX_QUIET] = quiet
    ctx.obj[CTX_VERBOSE] = verbose

    # Resolve repo root (subcommands may need it; --help should still work without one)
    try:
        repo_root = find_rlm_root(override=rlm_root)
        ctx.obj[CTX_RLM_ROOT] = repo_root
        ctx.obj[CTX_EMITTER] = TripleEmitter(rlm_root=repo_root)
    except RlmError:
        # --help and --version paths don't need a repo root.
        # Subcommands that need it will re-attempt and raise.
        ctx.obj[CTX_RLM_ROOT] = None
        ctx.obj[CTX_EMITTER] = None

    ctx.obj[CTX_CALLER] = Caller.from_env()


# ---- Result rendering helpers (used by subcommands) ----


def emit_result(ctx: click.Context, payload: dict[str, Any]) -> None:
    """Print a subcommand's success result to stdout per --json setting."""
    if ctx.obj.get(CTX_JSON_OUTPUT):
        click.echo(json.dumps(payload, separators=(",", ":"), ensure_ascii=False))
    else:
        if not ctx.obj.get(CTX_QUIET):
            # Human-readable rendering. Subcommands may print extra prose
            # before calling emit_result; here we summarise key fields.
            summary_lines = []
            for key in ("issue_number", "pr_number", "fact_id", "file", "commit_sha", "triple_id"):
                if key in payload:
                    summary_lines.append(f"  {key}: {payload[key]}")
            if summary_lines:
                click.echo("✓ ok")
                for line in summary_lines:
                    click.echo(line)
            else:
                click.echo(f"✓ ok: {json.dumps(payload, separators=(',', ':'))}")


# ---- Error handling wrapper used by subcommands ----


def handle_rlm_error(ctx: click.Context, exc: RlmError) -> None:
    """Print the error JSON to stderr and exit with the matched code."""
    err = exc.to_dict()
    click.echo(json.dumps(err, separators=(",", ":"), ensure_ascii=False), err=True)
    ctx.exit(exc.exit_code)


# ---- Subcommand registration ----
#
# Done at module import time so `rlm --help` lists everything. Each subcommand
# module exposes `cmd` (a click.Command). New subcommands: add an import + a
# main.add_command call below.

from rlm.commands import (  # noqa: E402  (intentional: register on import)
    add_contract,
    append_business_model,
    append_deployment_constraints,
    append_fact,
    approve_workpackage,
    commit_spec,
    commit_workpackage,
    confirm_spec,
    enqueue_message,
    mark_delivered,
    mark_in_progress,
    mark_superseded,
    open_pr,
    propose_adr,
    propose_context_change,
    record_signal,
    supersede_fact,
)

for module in (
    propose_adr,
    propose_context_change,
    add_contract,
    append_fact,
    supersede_fact,
    append_business_model,
    append_deployment_constraints,
    commit_spec,
    confirm_spec,
    commit_workpackage,
    approve_workpackage,
    record_signal,
    mark_superseded,
    mark_in_progress,
    mark_delivered,
    open_pr,
    enqueue_message,
):
    main.add_command(module.cmd)


# Entry point for `rlm` console script + `python -m rlm`
def _entrypoint() -> None:
    try:
        main(prog_name="rlm")
    except RlmError as exc:
        # If a subcommand raised RlmError but didn't catch it via handle_rlm_error,
        # this fallback ensures the JSON-on-stderr contract.
        err = exc.to_dict()
        click.echo(json.dumps(err, separators=(",", ":"), ensure_ascii=False), err=True)
        sys.exit(exc.exit_code)


# `pyproject.toml` script points to `rlm.cli:main`; we also support `_entrypoint` for tests.
# Click's `main` already handles SystemExit; the fallback above is for non-Click code paths.


__all__ = [
    "main",
    "emit_result",
    "handle_rlm_error",
    "CTX_RLM_ROOT",
    "CTX_JSON_OUTPUT",
    "CTX_DRY_RUN",
    "CTX_QUIET",
    "CTX_VERBOSE",
    "CTX_CALLER",
    "CTX_EMITTER",
]
