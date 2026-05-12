"""SQLite-backed idempotency cache.

Per contract § Idempotency contracts:
  - 24h TTL default
  - Cached at `.local/rlm-idempotency.db`
  - Key = (subcommand, key-tuple, content-hash)
  - `ok` results cached; `external-service-down` errors never cached
"""

from __future__ import annotations

import hashlib
import json
import sqlite3
import time
from dataclasses import dataclass
from pathlib import Path
from typing import Any

DB_REL_PATH = Path(".local") / "rlm-idempotency.db"
DEFAULT_TTL_SECONDS = 24 * 60 * 60


def content_hash(*parts: str) -> str:
    """Stable SHA-256 over the concatenated UTF-8 of parts. Used to detect
    semantic duplicates (same body content + same args)."""
    h = hashlib.sha256()
    for p in parts:
        h.update(p.encode("utf-8"))
        h.update(b"\x00")  # separator
    return h.hexdigest()


@dataclass
class IdempotencyCache:
    """Read/write the local SQLite cache.

    Construct with the repo root path; the cache lives at `<root>/.local/rlm-idempotency.db`.
    """

    rlm_root: Path
    ttl_seconds: int = DEFAULT_TTL_SECONDS

    @property
    def db_path(self) -> Path:
        return self.rlm_root / DB_REL_PATH

    def _conn(self) -> sqlite3.Connection:
        self.db_path.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(self.db_path)
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS idempotency (
                subcommand TEXT NOT NULL,
                key_tuple TEXT NOT NULL,
                content_hash TEXT NOT NULL,
                result_json TEXT NOT NULL,
                created_at_unix INTEGER NOT NULL,
                PRIMARY KEY (subcommand, key_tuple, content_hash)
            )
            """
        )
        conn.execute("CREATE INDEX IF NOT EXISTS idx_idem_created ON idempotency(created_at_unix)")
        return conn

    @staticmethod
    def _key_tuple_str(key_tuple: tuple[Any, ...]) -> str:
        return json.dumps(list(key_tuple), separators=(",", ":"), default=str)

    def get(
        self,
        subcommand: str,
        key_tuple: tuple[Any, ...],
        content_hash_str: str,
    ) -> dict[str, Any] | None:
        """Return cached result if fresh (within TTL), else None."""
        conn = self._conn()
        try:
            row = conn.execute(
                """
                SELECT result_json, created_at_unix
                FROM idempotency
                WHERE subcommand=? AND key_tuple=? AND content_hash=?
                """,
                (subcommand, self._key_tuple_str(key_tuple), content_hash_str),
            ).fetchone()
        finally:
            conn.close()

        if row is None:
            return None

        result_json, created_at = row
        if int(time.time()) - int(created_at) > self.ttl_seconds:
            # Expired — caller may overwrite via .set()
            return None
        result = json.loads(result_json)
        if isinstance(result, dict):
            result["idempotent"] = True
            return result
        return None

    def set(
        self,
        subcommand: str,
        key_tuple: tuple[Any, ...],
        content_hash_str: str,
        result: dict[str, Any],
    ) -> None:
        """Cache a successful result. Overwrites any prior entry for the same key."""
        conn = self._conn()
        try:
            conn.execute(
                """
                INSERT OR REPLACE INTO idempotency
                  (subcommand, key_tuple, content_hash, result_json, created_at_unix)
                VALUES (?, ?, ?, ?, ?)
                """,
                (
                    subcommand,
                    self._key_tuple_str(key_tuple),
                    content_hash_str,
                    json.dumps(result, separators=(",", ":"), default=str),
                    int(time.time()),
                ),
            )
            conn.commit()
        finally:
            conn.close()


__all__ = ["IdempotencyCache", "content_hash", "DB_REL_PATH", "DEFAULT_TTL_SECONDS"]
