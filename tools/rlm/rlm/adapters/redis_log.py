"""Best-effort Redis adapter.

Used by `triples.py` (stream `rlm:events`) and future Worker-lock + idempotency
overflow. v0.1.0 only uses it for the triple stream; `TripleEmitter` owns the
client lifecycle so this module is a thin wrapper for future use.
"""

from __future__ import annotations

import os
from typing import Any


def get_client(url: str | None = None) -> Any | None:
    """Return a redis.Redis client or None if connection fails.

    Args:
        url: explicit redis URL; falls back to REDIS_URL env var, then None.

    Returns:
        Redis client if reachable, else None. Caller decides degradation.
    """
    target = url or os.environ.get("REDIS_URL")
    if not target:
        return None
    try:
        import redis as redis_pkg

        client = redis_pkg.Redis.from_url(
            target, socket_connect_timeout=1, socket_timeout=1
        )
        client.ping()
        return client
    except Exception:
        return None


__all__ = ["get_client"]
