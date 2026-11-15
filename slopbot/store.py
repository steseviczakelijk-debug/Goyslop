"""SQLite history: what was made, what was posted, and when."""
from __future__ import annotations

import sqlite3
import time

from .config import DATA

SCHEMA = """
CREATE TABLE IF NOT EXISTS posts (
    id INTEGER PRIMARY KEY,
    created_at REAL NOT NULL,
    topic TEXT NOT NULL,
    caption TEXT NOT NULL,
    video_path TEXT NOT NULL,
    publish_id TEXT,
    status TEXT NOT NULL,          -- rendered | posted | failed
    detail TEXT
);
"""


class Store:
    def __init__(self, path=None):
        self.db = sqlite3.connect(path or DATA / "history.db")
        self.db.execute(SCHEMA)

    def add(self, topic: str, caption: str, video_path: str) -> int:
        cur = self.db.execute(
            "INSERT INTO posts (created_at, topic, caption, video_path, status) VALUES (?,?,?,?,?)",
            (time.time(), topic, caption, video_path, "rendered"),
        )
        self.db.commit()
        return cur.lastrowid

    def mark(self, post_id: int, status: str, publish_id: str | None = None, detail: str | None = None):
        self.db.execute(
            "UPDATE posts SET status=?, publish_id=COALESCE(?, publish_id), detail=? WHERE id=?",
            (status, publish_id, detail, post_id),
        )
        self.db.commit()

    def recent_topics(self, limit: int = 60) -> list[str]:
        rows = self.db.execute("SELECT topic FROM posts ORDER BY id DESC LIMIT ?", (limit,))
        return [r[0] for r in rows]

    def posted_since(self, since: float) -> int:
        row = self.db.execute(
            "SELECT COUNT(*) FROM posts WHERE status='posted' AND created_at>=?", (since,)
        ).fetchone()
        return row[0]

    def last_posted_at(self) -> float | None:
        row = self.db.execute("SELECT MAX(created_at) FROM posts WHERE status='posted'").fetchone()
        return row[0]
