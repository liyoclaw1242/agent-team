"""enqueue-message — queue an outbound message for Hermes to route to Discord.

See .rlm/contracts/rlm-cli.md § Detailed: enqueue-message and ADR-0015.
"""

from __future__ import annotations

from pathlib import Path

import click

from rlm.adapters import gh
from rlm.errors import ValidationError
from rlm.routing import issue as issue_route
from rlm.runner import SubcommandRun, content_hash, read_body_arg

VALID_KINDS = [
    "retry-exhausted",
    "ac-ambiguity",
    "supervision-alert",
    "intake-confirmation",
    "design-approval",
    "worker-self-decline",
    "production-anomaly",
]

# Kinds that target a parent Issue (everything except supervision-alert)
PARENT_REQUIRED_KINDS = {k for k in VALID_KINDS if k != "supervision-alert"}


@click.command("enqueue-message")
@click.option(
    "--kind",
    required=True,
    type=click.Choice(VALID_KINDS),
    help="message kind (per ADR-0015)",
)
@click.option(
    "--parent-issue",
    "parent_issue",
    type=int,
    help="parent Issue number (required for all kinds except supervision-alert)",
)
@click.option(
    "--severity",
    type=click.Choice(["low", "mid", "high"]),
    help="for supervision-alert only",
)
@click.option(
    "--body-file",
    type=click.Path(exists=True, dir_okay=False, path_type=Path),
    help="message body markdown",
)
@click.option("--body", help="inline message body")
@click.pass_context
def cmd(
    ctx: click.Context,
    kind: str,
    parent_issue: int | None,
    severity: str | None,
    body_file: Path | None,
    body: str | None,
) -> None:
    """Enqueue a message. Routing: parent Issue comment+label OR new supervision-alert Issue."""
    with SubcommandRun(ctx, "enqueue-message") as run:
        body_content = read_body_arg(body_file, body)

        # Validate flag combinations
        if kind == "supervision-alert":
            if parent_issue is not None:
                raise ValidationError(
                    "--parent-issue is not allowed for kind=supervision-alert "
                    "(this kind creates a new Issue)",
                    field="parent_issue",
                )
            if severity is None:
                severity = "mid"  # default per contract
        else:
            if parent_issue is None:
                raise ValidationError(
                    f"--parent-issue is required for kind={kind}",
                    field="parent_issue",
                )
            if severity is not None:
                raise ValidationError(
                    "--severity is only valid for kind=supervision-alert",
                    field="severity",
                )

        # Idempotency: by (kind, parent or content-hash)
        if kind == "supervision-alert":
            key = ("kind", kind, "content", content_hash(body_content))
        else:
            key = ("kind", kind, "parent", parent_issue)
        ch = content_hash(kind, str(parent_issue or ""), body_content)
        cached = run.cache_get(key, ch)
        if cached:
            return

        run.reasoning = f"enqueuing {kind!r} message" + (
            f" on Issue #{parent_issue}" if parent_issue else " as new supervision-alert Issue"
        )

        if run.dry_run:
            run.set_result(ok=True, dry_run=True, would_enqueue_kind=kind)
            return

        if kind == "supervision-alert":
            # Create a new type:supervision-alert Issue
            title = _extract_title_for_alert(body_content)
            created = issue_route.create_workflow_issue(
                title=title,
                body=body_content,
                item_type="supervision-alert",
                initial_status="open",
                extra_labels=[f"severity:{severity}"],
            )
            run.add_affected("issue", f"#{created.number}", "created")
            run.set_result(
                ok=True,
                kind=kind,
                issue_number=created.number,
                severity=severity,
            )
            return

        # Other kinds: comment on parent Issue + add outbound:<kind> label
        assert parent_issue is not None  # guard via flag validation above
        run.add_basis("issue", f"#{parent_issue}")
        gh.issue_comment(parent_issue, body_content)
        gh.issue_edit(parent_issue, add_labels=[f"outbound:{kind}"])
        run.add_affected("issue", f"#{parent_issue}", "commented")
        run.add_affected("issue", f"#{parent_issue}", "labeled")
        run.set_result(
            ok=True,
            kind=kind,
            parent_issue=parent_issue,
        )


def _extract_title_for_alert(body: str) -> str:
    """First non-blank line, stripped of leading '#'. Cap 120 chars."""
    for line in body.splitlines():
        line = line.strip()
        if not line:
            continue
        line = line.lstrip("#").strip()
        return line[:120] or "Supervision alert"
    return "Supervision alert"
