"""推荐帖子持久化缓存。"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone

from config import settings
from db import get_conn, init_db

from .models import RecommendationFeed

_READY = False


def _ensure_db() -> None:
    global _READY
    if not _READY:
        init_db()
        _READY = True


def _now() -> datetime:
    return datetime.now(timezone.utc)


def load_feed(query: str, media_kind: str, limit: int) -> RecommendationFeed | None:
    _ensure_db()
    current = _now().isoformat()
    with get_conn() as conn:
        rows = conn.execute(
            """
            SELECT payload_json FROM recommendation_posts
            WHERE query = ? AND media_kind = ? AND expires_at > ?
            ORDER BY created_at DESC
            LIMIT ?
            """,
            (query, media_kind, current, limit),
        ).fetchall()
    if not rows:
        return None
    posts = [json.loads(row["payload_json"]) for row in rows]
    return RecommendationFeed(query=query, posts=posts[:limit], catalog_traces=[])


def save_feed(query: str, media_kind: str, feed: RecommendationFeed) -> None:
    _ensure_db()
    created_at = _now()
    expires_at = created_at + timedelta(seconds=settings.recommendation_cache_ttl_seconds)
    with get_conn() as conn:
        for post in feed.posts:
            open_poster = next((action for action in post.actions if action.type == "openPoster"), None)
            conn.execute(
                """
                INSERT OR REPLACE INTO recommendation_posts(
                    id, query, media_kind, title, catalog_provider_id, catalog_source_id,
                    resource_provider_id, resource_remote_id, payload_json, created_at, expires_at
                )
                VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """,
                (
                    f"{query}:{media_kind}:{post.id}",
                    query,
                    media_kind,
                    post.title,
                    (open_poster.data.get("catalog_provider_id") if open_poster else "") or "",
                    (open_poster.data.get("catalog_source_id") if open_poster else "") or "",
                    post.primary_resource.provider_id,
                    post.primary_resource.remote_id,
                    post.model_dump_json(),
                    created_at.isoformat(),
                    expires_at.isoformat(),
                ),
            )
