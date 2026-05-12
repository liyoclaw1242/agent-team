"""Triple emission per ADR-0011.

Dual-sink:
  1. JSONL append-only at `<repo>/.local/events.jsonl` — required; failure = exit 5
  2. Redis stream `rlm:events` — best-effort; degraded silently if unreachable

Per contract § Triple emission.
"""

from __future__ import annotations

import json
import os
import secrets
import sys
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from rlm.errors import StateWriteError

EVENT_STREAM_NAME = "rlm:events"
JSONL_REL_PATH = Path(".local") / "events.jsonl"


def _utc_now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")[:-4] + "Z"


def _new_triple_id() -> str:
    """ev_<timestamp>_<random6>."""
    ts = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.%fZ")[:-4] + "Z"
    return f"ev_{ts}_{secrets.token_hex(3)}"


@dataclass
class Triple:
    """ADR-0011 6-field record plus operational metadata.

    The CLI builds one summary triple per subcommand invocation, plus optional
    sub-triples chained via `parent_triple_id` for discrete external actions
    (file write, git commit, gh call) within the invocation.
    """

    action: str
    reasoning: str
    basis: list[dict[str, str]] = field(default_factory=list)
    agent_id: str = ""
    parent_triple_id: str | None = None
    affected_resources: list[dict[str, str]] = field(default_factory=list)

    # Operational metadata
    skill_name: str | None = None
    invocation_id: str | None = None
    exit_code: int | None = None
    dry_run: bool = False

    # Auto-populated
    triple_id: str = field(default_factory=_new_triple_id)
    timestamp: str = field(default_factory=_utc_now_iso)

    def to_dict(self) -> dict[str, Any]:
        out = asdict(self)
        # Drop Nones to keep JSON lean
        return {k: v for k, v in out.items() if v is not None}

    def to_json_line(self) -> str:
        return json.dumps(self.to_dict(), separators=(",", ":"), ensure_ascii=False)


class TripleEmitter:
    """Writes triples to JSONL (required) and Redis (best-effort).

    Construct once per CLI invocation; call `emit(triple)` for each.
    """

    def __init__(self, rlm_root: Path, redis_url: str | None = None) -> None:
        self.rlm_root = rlm_root
        self.jsonl_path = rlm_root / JSONL_REL_PATH
        self.jsonl_path.parent.mkdir(parents=True, exist_ok=True)
        self._redis_url = redis_url or os.environ.get("REDIS_URL")
        self._redis_client: Any = None
        self._redis_failed = False  # once-failed: stop retrying within this invocation

    def _get_redis(self) -> Any:
        if self._redis_failed:
            return None
        if self._redis_client is not None:
            return self._redis_client
        if not self._redis_url:
            self._redis_failed = True
            return None
        try:
            import redis as redis_pkg

            client = redis_pkg.Redis.from_url(
                self._redis_url, socket_connect_timeout=1, socket_timeout=1
            )
            client.ping()
            self._redis_client = client
            return client
        except Exception as e:
            self._redis_failed = True
            print(
                f"warning: Redis unreachable ({type(e).__name__}: {e}); emitting JSONL-only",
                file=sys.stderr,
            )
            return None

    def emit(self, triple: Triple) -> None:
        """Write triple to JSONL (required) and Redis (best-effort).

        Raises:
            StateWriteError (exit 5) if JSONL write fails.
        """
        line = triple.to_json_line()

        # JSONL — required
        try:
            with self.jsonl_path.open("a", encoding="utf-8") as f:
                f.write(line + "\n")
        except OSError as e:
            raise StateWriteError(
                f"Failed to append triple to {self.jsonl_path}: {e}",
                details={"path": str(self.jsonl_path), "error": str(e)},
            ) from e

        # Redis — best-effort
        client = self._get_redis()
        if client is not None:
            try:
                client.xadd(EVENT_STREAM_NAME, {"event": line})
            except Exception as e:
                self._redis_failed = True
                print(
                    f"warning: Redis XADD failed ({type(e).__name__}: {e}); continuing JSONL-only",
                    file=sys.stderr,
                )


__all__ = ["Triple", "TripleEmitter", "EVENT_STREAM_NAME", "JSONL_REL_PATH"]
