"""成员 B：SQLite 数据库骨架（用户偏好 / 观影历史持久化）。

课设零部署成本，单文件 SQLite。真实实现由成员 B 填充（可用 sqlite3 标准库或 SQLModel）。
"""
# db/database.py
from __future__ import annotations

import sqlite3
import json  # 用于将 genres 列表序列化为字符串存储
from pathlib import Path
from models.schemas import UserPreference

DB_PATH = Path(__file__).parent / "cinenest.db"


def get_conn() -> sqlite3.Connection:
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row
    return conn


def init_db() -> None:
    """初始化建表"""
    with get_conn() as conn:
        conn.execute(
            """
            CREATE TABLE IF NOT EXISTS preferences (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
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


# ==================== 偏好设置 (Preferences) 业务逻辑 ====================

def save_user_preference(pref: UserPreference) -> None:
    """保存或更新用户偏好（单用户系统，利用 先删再插 确保库里永远只有最新的一条记录）"""
    # 1. 将列表序列化为 JSON 字符串
    liked_str = json.dumps(pref.liked_genres, ensure_ascii=False)
    disliked_str = json.dumps(pref.disliked_genres, ensure_ascii=False)

    with get_conn() as conn:
        # 2. 先清空 preferences 表中的所有旧数据
        conn.execute("DELETE FROM preferences")

        # 3. 插入当前最新的这条偏好数据
        conn.execute(
            """
            INSERT INTO preferences (liked_genres, disliked_genres, free_text)
            VALUES (?, ?, ?)
            """,
            (liked_str, disliked_str, pref.free_text)
        )
        # 使用 with 语句会自动 commit 提交事务


def get_user_preference() -> UserPreference:
    """获取用户偏好，若无则返回空对象（核心修复：去掉 WHERE id=1 限制，改用 LIMIT 1 兼容自增 id）"""
    with get_conn() as conn:
        # 去掉 WHERE id = 1，直接拿表中的第 1 条（也是唯一一条最新数据）
        cursor = conn.execute("SELECT liked_genres, disliked_genres, free_text FROM preferences LIMIT 1")
        row = cursor.fetchone()

    if not row:
        return UserPreference(liked_genres=[], disliked_genres=[], free_text="")

    # 加上异常保护，确保反序列化绝对安全
    try:
        liked_genres = json.loads(row["liked_genres"]) if row["liked_genres"] else []
    except Exception:
        liked_genres = []

    try:
        disliked_genres = json.loads(row["disliked_genres"]) if row["disliked_genres"] else []
    except Exception:
        disliked_genres = []

    return UserPreference(
        liked_genres=liked_genres,
        disliked_genres=disliked_genres,
        free_text=row["free_text"] or ""
    )


# ==================== 观影历史 (Watch History) 业务逻辑 ====================

def add_watch_history(movie_id: int, title: str) -> None:
    """记录一条观影历史，若存在则覆盖最新时间"""
    import datetime
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO watch_history (movie_id, title, visited_at)
            VALUES (?, ?, ?)
            ON CONFLICT(movie_id) DO UPDATE SET visited_at=excluded.visited_at
            """,
            (movie_id, title, now_str)
        )


def get_watch_history_titles() -> list[str]:
    """获取用户最近看过的电影标题列表（用于喂给 AI 规避或参考）"""
    with get_conn() as conn:
        cursor = conn.execute("SELECT title FROM watch_history ORDER BY visited_at DESC LIMIT 10")
        rows = cursor.fetchall()
    return [row["title"] for row in rows]