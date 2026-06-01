"""成员 B：SQLite 数据库骨架（用户偏好 / 观影历史持久化）。

课设零部署成本，单文件 SQLite。真实实现由成员 B 填充（可用 sqlite3 标准库或 SQLModel）。
"""
from __future__ import annotations

import sqlite3
from pathlib import Path

DB_PATH = Path(__file__).parent / "cinenest.db"


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """TODO(B): 建表 preferences / watch_history。"""
    with get_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS preferences (
                id INTEGER PRIMARY KEY,
                liked_genres TEXT,
                disliked_genres TEXT,
                free_text TEXT
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS watch_history (
                movie_id INTEGER PRIMARY KEY,
                title TEXT,
                visited_at TEXT
            )
            """
        )
