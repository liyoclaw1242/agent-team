"""SubcommandRun — context manager wrapping per-invocation boilerplate.

Every command body uses:

    @click.command("record-signal")
    @click.option(...)
    @click.pass_context
    def cmd(ctx: click.Context, ...) -> None:
        with SubcommandRun(ctx, "record-signal") as run:
            # validate args
            # check idempotency via run.cache_get
            # execute side effects via adapters
            # populate run.result / run.basis / run.affected / run.reasoning
            ...
        # On exit: triple emitted, result printed, errors → JSON-on-stderr + exit code.

Responsibilities:
  - Acquire caller from ctx.obj; assert_can(subcommand)
  - Resolve .rlm/ root + emitter; raise NoRlmRootError if missing
  - Provide idempotency cache helpers
  - Emit success / error triple at exit
  - Convert exceptions to exit codes per contract § Error model
"""

from __future__ import annotations

import dataclasses
import hashlib
import json
from contextlib import AbstractContextManager
from pathlib import Path
from types import TracebackType
from typing import Any

import click

from rlm.context import (
    CTX_CALLER,
    CTX_DRY_RUN,
    CTX_EMITTER,
    CTX_RLM_ROOT,
    emit_result,
    handle_rlm_error,
)
from rlm.errors import NoRlmRootError, RlmError
from rlm.idempotency import IdempotencyCache
from rlm.identity import Caller
from rlm.triples import Triple, TripleEmitter


def _normalize_key(parts: tuple[Any, ...]) -> str:
    """Stable string form of a key-tuple for caching."""
    return json.dumps(list(parts), separators=(",", ":"), default=str, ensure_ascii=False)


def content_hash(*parts: str) -> str:
    """SHA-256 over the concatenated UTF-8 of parts. Re-exported from idempotency."""
    h = hashlib.sha256()
    for p in parts:
        h.update(p.encode("utf-8"))
        h.update(b"\x00")
    return h.hexdigest()


@dataclasses.dataclass
class SubcommandRun(AbstractContextManager["SubcommandRun"]):
    """Runtime context for a single subcommand invocation."""

    ctx: click.Context
    name: str

    # Populated by __post_init__
    caller: Caller = dataclasses.field(init=False)
    repo_root: Path = dataclasses.field(init=False)
    emitter: TripleEmitter = dataclasses.field(init=False)
    cache: IdempotencyCache = dataclasses.field(init=False)
    dry_run: bool = dataclasses.field(init=False)

    # Body populates these before exiting `with`
    result: dict[str, Any] = dataclasses.field(default_factory=dict)
    reasoning: str = ""
    basis: list[dict[str, str]] = dataclasses.field(default_factory=list)
    affected: list[dict[str, str]] = dataclasses.field(default_factory=list)

    # Internal — for cache.set
    _idempotency_key: tuple[Any, ...] | None = dataclasses.field(default=None, init=False)
    _content_hash: str = dataclasses.field(default="", init=False)
    _cache_hit: bool = dataclasses.field(default=False, init=False)

    def __post_init__(self) -> None:
        self.caller = self.ctx.obj[CTX_CALLER]

        repo_root = self.ctx.obj.get(CTX_RLM_ROOT)
        emitter = self.ctx.obj.get(CTX_EMITTER)
        if repo_root is None or emitter is None:
            raise NoRlmRootError(
                "Cannot run subcommand without resolved .rlm/ root",
                subcommand=self.name,
            )
        self.repo_root = repo_root
        self.emitter = emitter
        self.cache = IdempotencyCache(self.repo_root)
        self.dry_run = bool(self.ctx.obj.get(CTX_DRY_RUN, False))

        # Permission check (per ADR-0009)
        self.caller.assert_can(self.name)

    # ---- Context-manager protocol ----

    def __enter__(self) -> SubcommandRun:
        return self

    def __exit__(
        self,
        exc_type: type[BaseException] | None,
        exc_val: BaseException | None,
        exc_tb: TracebackType | None,
    ) -> bool:
        if exc_val is None:
            self._on_success()
            return False

        if isinstance(exc_val, RlmError):
            exc_val.subcommand = exc_val.subcommand or self.name
            self._on_error(exc_val)
            return True  # Suppress further propagation (handle_rlm_error exited)

        # Unknown exception — wrap as internal-error (exit 99)
        wrapped = RlmError(
            f"Unexpected {exc_type.__name__ if exc_type else 'error'}: {exc_val}",
            subcommand=self.name,
        )
        self._on_error(wrapped)
        return True

    # ---- Success / error finalisers ----

    def _on_success(self) -> None:
        if self._cache_hit:
            # Idempotent re-invocation: no new work happened, so no new triple
            # and no cache.set. Just render the cached result.
            emit_result(self.ctx, self.result)
            return

        triple = self._build_triple(exit_code=0)
        self.emitter.emit(triple)
        # Stamp triple_id on result so callers / agents can correlate
        self.result.setdefault("triple_id", triple.triple_id)
        # Cache the result if an idempotency key was set
        if self._idempotency_key is not None:
            self.cache.set(self.name, self._idempotency_key, self._content_hash, self.result)
        emit_result(self.ctx, self.result)

    def _on_error(self, exc: RlmError) -> None:
        triple = self._build_triple(
            exit_code=exc.exit_code,
            reasoning_override=f"failed: {exc.message}",
        )
        self.emitter.emit(triple)
        handle_rlm_error(self.ctx, exc)

    def _build_triple(self, *, exit_code: int, reasoning_override: str | None = None) -> Triple:
        return Triple(
            action=f"rlm.{self.name}",
            reasoning=reasoning_override or self.reasoning or f"{self.name} executed",
            basis=list(self.basis),
            agent_id=self.caller.role or "unknown",
            affected_resources=list(self.affected),
            skill_name=self.caller.skill_name,
            invocation_id=self.caller.invocation_id,
            exit_code=exit_code,
            dry_run=self.dry_run,
        )

    # ---- Idempotency helpers ----

    def cache_get(
        self,
        key_tuple: tuple[Any, ...],
        content_hash_str: str = "",
    ) -> dict[str, Any] | None:
        """Look up a prior successful invocation by key. None if absent / expired.

        On cache hit: also sets `self.result` to the cached value and marks
        `_cache_hit=True`. The caller can then `if cached: return` to short-
        circuit. `_on_success` detects the flag and skips re-emission.

        Caller must also pass the same content_hash_str if used, OR pass ""
        for plain key-only matching.
        """
        # Record for cache.set on success
        self._idempotency_key = key_tuple
        self._content_hash = content_hash_str

        cached = self.cache.get(self.name, key_tuple, content_hash_str)
        if cached is not None:
            self.result = dict(cached)
            self._cache_hit = True
        return cached

    # ---- Convenience setters ----

    def add_basis(self, kind: str, ref: str) -> None:
        self.basis.append({"kind": kind, "ref": ref})

    def add_affected(self, kind: str, ref: str, verb: str) -> None:
        self.affected.append({"kind": kind, "ref": ref, "verb": verb})

    def set_result(self, **kwargs: Any) -> None:
        self.result.update(kwargs)


def read_body_arg(
    body_file: Path | None,
    body_inline: str | None,
    *,
    allow_stdin: bool = True,
) -> str:
    """Common body-argument resolution per contract § Invocation conventions.

    Priority: --body-file > --body > stdin. Returns the body content as str.

    Raises ValidationError if both --body-file and --body are given, or if
    neither is given and stdin is empty / not a TTY.
    """
    import sys

    from rlm.errors import ValidationError

    if body_file is not None and body_inline is not None:
        raise ValidationError(
            "Cannot use both --body-file and --body; pick one",
            field="body",
        )

    if body_file is not None:
        return body_file.read_text(encoding="utf-8")

    if body_inline is not None:
        return body_inline

    if allow_stdin and not sys.stdin.isatty():
        return sys.stdin.read()

    raise ValidationError(
        "No body provided. Use --body-file, --body, or pipe via stdin.",
        field="body",
    )


__all__ = ["SubcommandRun", "read_body_arg", "content_hash"]
