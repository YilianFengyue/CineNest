"""聊天记录 SQLite 存储。"""
from __future__ import annotations

import json
from datetime import datetime, timezone
from typing import Any
from uuid import uuid4

from db import get_conn, init_db

from .models import ChatHistoryResponse, ChatMessageRecord, ChatSession

_READY = False


def _ensure_db() -> None:
    global _READY
    if not _READY:
        init_db()
        _READY = True


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _session_from_row(row) -> ChatSession:
    return ChatSession(
        id=row["id"],
        title=row["title"],
        model=row["model"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
    )


def _message_from_row(row) -> ChatMessageRecord:
    return ChatMessageRecord(
        id=row["id"],
        session_id=row["session_id"],
        role=row["role"],
        content=row["content"],
        attachments=json.loads(row["attachments_json"] or "[]"),
        tool_calls=json.loads(row["tool_calls_json"] or "[]"),
        created_at=row["created_at"],
    )


def ensure_session(thread_id: str, *, model: str = "default", title: str = "") -> ChatSession:
    _ensure_db()
    current = _now()
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM chat_sessions WHERE id = ?", (thread_id,)).fetchone()
        if row is None:
            resolved_title = title or "新对话"
            conn.execute(
                """
                INSERT INTO chat_sessions(id, title, model, created_at, updated_at)
                VALUES(?, ?, ?, ?, ?)
                """,
                (thread_id, resolved_title, model or "default", current, current),
            )
            row = conn.execute("SELECT * FROM chat_sessions WHERE id = ?", (thread_id,)).fetchone()
        else:
            conn.execute(
                "UPDATE chat_sessions SET model = ?, updated_at = ? WHERE id = ?",
                (model or row["model"] or "default", current, thread_id),
            )
            row = conn.execute("SELECT * FROM chat_sessions WHERE id = ?", (thread_id,)).fetchone()
    return _session_from_row(row)


def add_message(
    thread_id: str,
    role: str,
    content: str = "",
    *,
    model: str = "default",
    attachments: list[dict[str, Any]] | None = None,
    tool_calls: list[dict[str, Any]] | None = None,
) -> ChatMessageRecord:
    _ensure_db()
    ensure_session(thread_id, model=model, title=content[:24] if role == "user" else "")
    current = _now()
    message_id = uuid4().hex
    payload = {
        "id": message_id,
        "session_id": thread_id,
        "role": role,
        "content": content,
        "attachments_json": json.dumps(attachments or [], ensure_ascii=False),
        "tool_calls_json": json.dumps(tool_calls or [], ensure_ascii=False),
        "created_at": current,
    }
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO chat_messages(id, session_id, role, content, attachments_json, tool_calls_json, created_at)
            VALUES(:id, :session_id, :role, :content, :attachments_json, :tool_calls_json, :created_at)
            """,
            payload,
        )
        conn.execute("UPDATE chat_sessions SET updated_at = ? WHERE id = ?", (current, thread_id))
    return ChatMessageRecord(
        id=message_id,
        session_id=thread_id,
        role=role,
        content=content,
        attachments=attachments or [],
        tool_calls=tool_calls or [],
        created_at=current,
    )


def list_sessions(limit: int = 50) -> list[ChatSession]:
    _ensure_db()
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM chat_sessions ORDER BY updated_at DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [_session_from_row(row) for row in rows]


def get_history(thread_id: str) -> ChatHistoryResponse:
    _ensure_db()
    with get_conn() as conn:
        session_row = conn.execute("SELECT * FROM chat_sessions WHERE id = ?", (thread_id,)).fetchone()
        if session_row is None:
            raise LookupError(f"未知会话: {thread_id}")
        rows = conn.execute(
            "SELECT * FROM chat_messages WHERE session_id = ? ORDER BY created_at ASC",
            (thread_id,),
        ).fetchall()
    return ChatHistoryResponse(
        session=_session_from_row(session_row),
        messages=[_message_from_row(row) for row in rows],
    )


def delete_session(thread_id: str) -> None:
    _ensure_db()
    with get_conn() as conn:
        conn.execute("DELETE FROM chat_messages WHERE session_id = ?", (thread_id,))
        conn.execute("DELETE FROM chat_sessions WHERE id = ?", (thread_id,))


def rename_session(thread_id: str, title: str) -> ChatSession:
    _ensure_db()
    current = _now()
    with get_conn() as conn:
        conn.execute(
            "UPDATE chat_sessions SET title = ?, updated_at = ? WHERE id = ?",
            (title, current, thread_id),
        )
        row = conn.execute("SELECT * FROM chat_sessions WHERE id = ?", (thread_id,)).fetchone()
    if row is None:
        raise LookupError(f"未知会话: {thread_id}")
    return _session_from_row(row)
