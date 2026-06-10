"""CineNest 后端 SQLite 存储。"""
from __future__ import annotations

import datetime
import json
import sqlite3

from config import settings
from models.schemas import CollectionItem, UserPreference, WatchHistoryItem


def get_conn() -> sqlite3.Connection:
    settings.database_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(settings.database_path, timeout=10)
    # Some Windows development environments lock SQLite rollback journal files.
    # The app only stores local course-demo state, so disabling the journal keeps
    # preferences/history usable instead of failing every request with disk I/O.
    conn.execute("PRAGMA journal_mode=OFF")
    conn.execute("PRAGMA busy_timeout=5000")
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """初始化课设所需的轻量表。"""

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
            CREATE TABLE IF NOT EXISTS chat_sessions (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL DEFAULT '',
                model TEXT NOT NULL DEFAULT 'default',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS chat_messages (
                id TEXT PRIMARY KEY,
                session_id TEXT NOT NULL,
                role TEXT NOT NULL,
                content TEXT NOT NULL DEFAULT '',
                attachments_json TEXT NOT NULL DEFAULT '[]',
                tool_calls_json TEXT NOT NULL DEFAULT '[]',
                created_at TEXT NOT NULL,
                FOREIGN KEY(session_id) REFERENCES chat_sessions(id) ON DELETE CASCADE
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_chat_messages_session_time ON chat_messages(session_id, created_at)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS assets (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                filename TEXT NOT NULL,
                stored_name TEXT NOT NULL,
                mime TEXT NOT NULL,
                size INTEGER NOT NULL,
                created_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS recommendation_posts (
                id TEXT PRIMARY KEY,
                query TEXT NOT NULL,
                media_kind TEXT NOT NULL,
                title TEXT NOT NULL,
                catalog_provider_id TEXT NOT NULL DEFAULT '',
                catalog_source_id TEXT NOT NULL DEFAULT '',
                resource_provider_id TEXT NOT NULL DEFAULT '',
                resource_remote_id TEXT NOT NULL DEFAULT '',
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                expires_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_recommendation_posts_query ON recommendation_posts(query, expires_at)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS news_items (
                id TEXT PRIMARY KEY,
                title TEXT NOT NULL,
                source TEXT NOT NULL,
                payload_json TEXT NOT NULL,
                created_at TEXT NOT NULL,
                published_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS news_tasks (
                id TEXT PRIMARY KEY,
                query TEXT NOT NULL,
                media_kind TEXT NOT NULL DEFAULT 'movie',
                status TEXT NOT NULL,
                stage TEXT NOT NULL,
                news_id TEXT NOT NULL DEFAULT '',
                error TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                finished_at TEXT NOT NULL DEFAULT ''
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_news_tasks_updated ON news_tasks(updated_at DESC)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS watch_history (
                movie_id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                visited_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS collections (
                movie_id INTEGER PRIMARY KEY,
                title TEXT NOT NULL,
                poster_url TEXT,
                collected_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS agent_sync_batches (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                device_id TEXT NOT NULL DEFAULT '',
                history_count INTEGER NOT NULL DEFAULT 0,
                favorite_count INTEGER NOT NULL DEFAULT 0,
                created_at TEXT NOT NULL,
                payload_hash TEXT NOT NULL DEFAULT ''
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS agent_memory_items (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                memory_type TEXT NOT NULL,
                subject TEXT NOT NULL DEFAULT '',
                relation TEXT NOT NULL DEFAULT '',
                object TEXT NOT NULL DEFAULT '',
                source TEXT NOT NULL DEFAULT '',
                confidence REAL NOT NULL DEFAULT 0.5,
                weight REAL NOT NULL DEFAULT 1.0,
                payload_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                last_seen_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_agent_memory_user_type ON agent_memory_items(user_id, memory_type)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS agent_profile (
                user_id TEXT PRIMARY KEY,
                summary TEXT NOT NULL DEFAULT '',
                payload_json TEXT NOT NULL DEFAULT '{}',
                version INTEGER NOT NULL DEFAULT 1,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS agent_memory_edges (
                id TEXT PRIMARY KEY,
                user_id TEXT NOT NULL,
                source_node TEXT NOT NULL,
                target_node TEXT NOT NULL,
                relation TEXT NOT NULL,
                weight REAL NOT NULL DEFAULT 1.0,
                payload_json TEXT NOT NULL DEFAULT '{}',
                updated_at TEXT NOT NULL
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_agent_memory_edges_user ON agent_memory_edges(user_id)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS phone_tasks (
                id TEXT PRIMARY KEY,
                thread_id TEXT NOT NULL DEFAULT '',
                parent_task_id TEXT NOT NULL DEFAULT '',
                objective TEXT NOT NULL,
                success_criteria TEXT NOT NULL DEFAULT '',
                device_type TEXT NOT NULL DEFAULT 'adb',
                device_id TEXT NOT NULL DEFAULT '',
                status TEXT NOT NULL,
                result TEXT NOT NULL DEFAULT '',
                error TEXT NOT NULL DEFAULT '',
                max_steps INTEGER NOT NULL DEFAULT 30,
                created_at TEXT NOT NULL,
                updated_at TEXT NOT NULL,
                finished_at TEXT NOT NULL DEFAULT ''
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_phone_tasks_status_updated ON phone_tasks(status, updated_at DESC)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS phone_steps (
                id TEXT PRIMARY KEY,
                task_id TEXT NOT NULL,
                step_index INTEGER NOT NULL,
                thinking TEXT NOT NULL DEFAULT '',
                action_json TEXT NOT NULL DEFAULT '{}',
                observation_json TEXT NOT NULL DEFAULT '{}',
                success INTEGER NOT NULL DEFAULT 0,
                finished INTEGER NOT NULL DEFAULT 0,
                message TEXT NOT NULL DEFAULT '',
                created_at TEXT NOT NULL,
                FOREIGN KEY(task_id) REFERENCES phone_tasks(id) ON DELETE CASCADE
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_phone_steps_task_index ON phone_steps(task_id, step_index)"
        )
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS phone_events (
                id TEXT PRIMARY KEY,
                task_id TEXT NOT NULL,
                event_type TEXT NOT NULL,
                payload_json TEXT NOT NULL DEFAULT '{}',
                created_at TEXT NOT NULL,
                FOREIGN KEY(task_id) REFERENCES phone_tasks(id) ON DELETE CASCADE
            )
            """
        )
        conn.execute(
            "CREATE INDEX IF NOT EXISTS idx_phone_events_task_time ON phone_events(task_id, created_at)"
        )


def _empty_preference() -> UserPreference:
    return UserPreference(liked_genres=[], disliked_genres=[], free_text="")


def _json_list(value: str | None) -> list[str]:
    if not value:
        return []
    try:
        data = json.loads(value)
    except json.JSONDecodeError:
        return []
    return [str(item) for item in data] if isinstance(data, list) else []


def _now_text() -> str:
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def save_user_preference(pref: UserPreference) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO preferences (id, liked_genres, disliked_genres, free_text)
            VALUES (1, ?, ?, ?)
            ON CONFLICT(id) DO UPDATE SET
                liked_genres = excluded.liked_genres,
                disliked_genres = excluded.disliked_genres,
                free_text = excluded.free_text
            """,
            (
                json.dumps(pref.liked_genres, ensure_ascii=False),
                json.dumps(pref.disliked_genres, ensure_ascii=False),
                pref.free_text or "",
            ),
        )


def get_user_preference() -> UserPreference:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT liked_genres, disliked_genres, free_text FROM preferences WHERE id = 1"
        ).fetchone()
    if row is None:
        return _empty_preference()
    return UserPreference(
        liked_genres=_json_list(row["liked_genres"]),
        disliked_genres=_json_list(row["disliked_genres"]),
        free_text=row["free_text"] or "",
    )


def add_watch_history(movie_id: int, title: str) -> None:
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO watch_history (movie_id, title, visited_at)
            VALUES (?, ?, ?)
            ON CONFLICT(movie_id) DO UPDATE SET
                title = excluded.title,
                visited_at = excluded.visited_at
            """,
            (movie_id, title, _now_text()),
        )


def get_watch_history_titles() -> list[str]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT title FROM watch_history ORDER BY visited_at DESC LIMIT 10"
        ).fetchall()
    return [str(row["title"]) for row in rows if row["title"]]


def get_watch_history() -> list[WatchHistoryItem]:
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT movie_id, title, visited_at
            FROM watch_history
            ORDER BY visited_at DESC
            LIMIT 50
            """
        ).fetchall()
    return [WatchHistoryItem(**dict(row)) for row in rows]


def toggle_collection(movie_id: int, title: str, poster_url: str | None = None) -> bool:
    """切换收藏状态。返回 True 表示现在已收藏，False 表示已取消收藏。"""

    with get_conn() as conn:
        existing = conn.execute(
            "SELECT movie_id FROM collections WHERE movie_id = ?",
            (movie_id,),
        ).fetchone()
        if existing is not None:
            conn.execute("DELETE FROM collections WHERE movie_id = ?", (movie_id,))
            return False
        conn.execute(
            """
            INSERT INTO collections (movie_id, title, poster_url, collected_at)
            VALUES (?, ?, ?, ?)
            """,
            (movie_id, title, poster_url, _now_text()),
        )
        return True


def get_collections() -> list[CollectionItem]:
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT movie_id, title, poster_url, collected_at
            FROM collections
            ORDER BY collected_at DESC
            """
        ).fetchall()
    return [CollectionItem(**dict(row)) for row in rows]


def is_movie_collected(movie_id: int) -> bool:
    with get_conn() as conn:
        row = conn.execute(
            "SELECT movie_id FROM collections WHERE movie_id = ?",
            (movie_id,),
        ).fetchone()
    return row is not None
