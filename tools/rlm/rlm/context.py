"""Shared CLI context: ctx.obj keys + result/error rendering helpers.

Lives in its own module to avoid circular imports between `rlm.cli` (top-level
Click group) and `rlm.runner` / `rlm.commands.*` (subcommand bodies). Both
sides import from here.
"""

from __future__ import annotations

import json
from typing import Any

import click

from rlm.errors import RlmError

# Click context.obj keys
CTX_RLM_ROOT = "rlm_root"
CTX_JSON_OUTPUT = "json_output"
CTX_DRY_RUN = "dry_run"
CTX_QUIET = "quiet"
CTX_VERBOSE = "verbose"
CTX_CALLER = "caller"
CTX_EMITTER = "emitter"


def emit_result(ctx: click.Context, payload: dict[str, Any]) -> None:
    """Print a subcommand's success result to stdout per --json setting."""
    if ctx.obj.get(CTX_JSON_OUTPUT):
        click.echo(json.dumps(payload, separators=(",", ":"), ensure_ascii=False))
        return

    if ctx.obj.get(CTX_QUIET):
        return

    # Human-readable rendering. Subcommands may have printed extra prose
    # before; here we summarise key fields.
    summary_lines = []
    for key in (
        "issue_number",
        "pr_number",
        "fact_id",
        "file",
        "commit_sha",
        "branch",
        "triple_id",
    ):
        if key in payload:
            summary_lines.append(f"  {key}: {payload[key]}")

    if summary_lines:
        click.echo("✓ ok")
        for line in summary_lines:
            click.echo(line)
    else:
        click.echo(f"✓ ok: {json.dumps(payload, separators=(',', ':'))}")


def handle_rlm_error(ctx: click.Context, exc: RlmError) -> None:
    """Print the error JSON to stderr and exit with the matched code.

    Per contract § Error model: error JSON on stderr regardless of --json.
    """
    err = exc.to_dict()
    click.echo(json.dumps(err, separators=(",", ":"), ensure_ascii=False), err=True)
    ctx.exit(exc.exit_code)


__all__ = [
    "CTX_RLM_ROOT",
    "CTX_JSON_OUTPUT",
    "CTX_DRY_RUN",
    "CTX_QUIET",
    "CTX_VERBOSE",
    "CTX_CALLER",
    "CTX_EMITTER",
    "emit_result",
    "handle_rlm_error",
]
