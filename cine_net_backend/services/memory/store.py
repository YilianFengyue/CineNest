"""SQLite-backed Agent 长期记忆存储。"""
from __future__ import annotations

import datetime
import hashlib
import json
from collections.abc import Iterable
from typing import Any
from uuid import uuid4

from db import get_conn, init_db

from .models import AgentMemoryItem


def utc_now() -> str:
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def stable_id(*parts: object) -> str:
    raw = "|".join(str(part or "") for part in parts)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()


def _payload_hash(payload: dict[str, Any]) -> str:
    raw = json.dumps(payload, ensure_ascii=False, sort_keys=True)
    return hashlib.sha1(raw.encode("utf-8")).hexdigest()


def _row_to_memory(row) -> AgentMemoryItem:
    return AgentMemoryItem(
        id=row["id"],
        user_id=row["user_id"],
        memory_type=row["memory_type"],
        subject=row["subject"] or "",
        relation=row["relation"] or "",
        object=row["object"] or "",
        source=row["source"] or "",
        confidence=float(row["confidence"] or 0.5),
        weight=float(row["weight"] or 1.0),
        payload=json.loads(row["payload_json"] or "{}"),
        created_at=row["created_at"],
        updated_at=row["updated_at"],
        last_seen_at=row["last_seen_at"],
    )


def create_sync_batch(
    *,
    user_id: str,
    device_id: str,
    history_count: int,
    favorite_count: int,
    payload: dict[str, Any],
) -> str:
    init_db()
    batch_id = uuid4().hex
    now = utc_now()
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO agent_sync_batches(
                id, user_id, device_id, history_count, favorite_count, created_at, payload_hash
            )
            VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (
                batch_id,
                user_id,
                device_id,
                history_count,
                favorite_count,
                now,
                _payload_hash(payload),
            ),
        )
    return batch_id


def upsert_memory_item(
    *,
    item_id: str,
    user_id: str,
    memory_type: str,
    subject: str,
    relation: str,
    object_value: str,
    source: str,
    confidence: float,
    weight: float,
    payload: dict[str, Any],
    seen_at: str | None = None,
) -> bool:
    init_db()
    now = utc_now()
    seen = seen_at or now
    payload_json = json.dumps(payload, ensure_ascii=False)
    with get_conn() as conn:
        existing = conn.execute(
            "SELECT id FROM agent_memory_items WHERE id = ?",
            (item_id,),
        ).fetchone()
        if existing is None:
            conn.execute(
                """
                INSERT INTO agent_memory_items(
                    id, user_id, memory_type, subject, relation, object, source,
                    confidence, weight, payload_json, created_at, updated_at, last_seen_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    item_id,
                    user_id,
                    memory_type,
                    subject,
                    relation,
                    object_value,
                    source,
                    confidence,
                    weight,
                    payload_json,
                    now,
                    now,
                    seen,
                ),
            )
            return True
        conn.execute(
            """
            UPDATE agent_memory_items
            SET subject = ?, relation = ?, object = ?, source = ?, confidence = ?,
                weight = ?, payload_json = ?, updated_at = ?, last_seen_at = ?
            WHERE id = ?
            """,
            (
                subject,
                relation,
                object_value,
                source,
                confidence,
                weight,
                payload_json,
                now,
                seen,
                item_id,
            ),
        )
    return False


def list_memory_items(user_id: str = "default", limit: int = 500) -> list[AgentMemoryItem]:
    init_db()
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT * FROM agent_memory_items
            WHERE user_id = ?
            ORDER BY last_seen_at DESC
            LIMIT ?
            """,
            (user_id, limit),
        ).fetchall()
    return [_row_to_memory(row) for row in rows]


def save_profile(user_id: str, payload: dict[str, Any], summary: str) -> str:
    init_db()
    now = utc_now()
    payload_json = json.dumps(payload, ensure_ascii=False)
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO agent_profile(user_id, summary, payload_json, version, created_at, updated_at)
            VALUES (?, ?, ?, 1, ?, ?)
            ON CONFLICT(user_id) DO UPDATE SET
                summary = excluded.summary,
                payload_json = excluded.payload_json,
                version = agent_profile.version + 1,
                updated_at = excluded.updated_at
            """,
            (user_id, summary, payload_json, now, now),
        )
    return now


def load_profile_payload(user_id: str = "default") -> dict[str, Any] | None:
    init_db()
    with get_conn() as conn:
        row = conn.execute(
            "SELECT payload_json FROM agent_profile WHERE user_id = ?",
            (user_id,),
        ).fetchone()
    if row is None:
        return None
    return json.loads(row["payload_json"] or "{}")


def replace_graph_edges(user_id: str, edges: Iterable[dict[str, Any]]) -> None:
    init_db()
    now = utc_now()
    with get_conn() as conn:
        conn.execute("DELETE FROM agent_memory_edges WHERE user_id = ?", (user_id,))
        for edge in edges:
            conn.execute(
                """
                INSERT INTO agent_memory_edges(
                    id, user_id, source_node, target_node, relation, weight, payload_json, updated_at
                )
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    edge["id"],
                    user_id,
                    edge["source"],
                    edge["target"],
                    edge["relation"],
                    float(edge.get("weight") or 1),
                    json.dumps(edge.get("payload") or {}, ensure_ascii=False),
                    now,
                ),
            )

