"""资讯流服务。第一版用热门影视资料生成可渲染资讯卡。"""
from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from uuid import uuid5, NAMESPACE_URL

from db import get_conn
from services.catalog import get_catalog_service
from services.microdesign import compose_media_gallery, compose_news_card
from services.microdesign.models import MicroDesignAction

from .models import NewsFeed, NewsItem


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _news_id(seed: str) -> str:
    return f"news-{uuid5(NAMESPACE_URL, seed).hex[:16]}"


def _item_from_payload(payload: dict) -> NewsItem:
    return NewsItem.model_validate(payload)


def _load_cached(limit: int) -> list[NewsItem]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT payload_json FROM news_items ORDER BY published_at DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [_item_from_payload(json.loads(row["payload_json"])) for row in rows]


def _save_items(items: list[NewsItem]) -> None:
    with get_conn() as conn:
        for item in items:
            conn.execute(
                """
                INSERT OR REPLACE INTO news_items(id, title, source, payload_json, created_at, published_at)
                VALUES(?, ?, ?, ?, ?, ?)
                """,
                (
                    item.id,
                    item.title,
                    item.source,
                    item.model_dump_json(),
                    _now(),
                    item.published_at,
                ),
            )


async def build_news_feed(*, limit: int = 10, refresh: bool = False) -> NewsFeed:
    if not refresh:
        cached = _load_cached(limit)
        if cached:
            return NewsFeed(items=cached[:limit])
    catalog = await get_catalog_service().hot(media_kind="movie", limit=max(limit, 10))
    published = datetime.now(timezone.utc)
    items: list[NewsItem] = []
    for index, movie in enumerate(catalog.items[:limit]):
        news_id = _news_id(movie.catalog_id or movie.title)
        title = f"今日影视推荐：《{movie.title}》值得加入片单"
        summary = movie.overview or (
            f"{movie.provider_name} 资料源显示这部作品"
            f"{f'评分 {movie.rating:.1f}' if movie.rating is not None else '已有资料'}，"
            "后端将继续为它匹配播放资源与互动海报。"
        )
        tags = [*movie.genres[:4]]
        if movie.year:
            tags.append(movie.year)
        poster_action = (
            MicroDesignAction(
                type="openPoster",
                label="查看互动海报",
                data={
                    "catalog_provider_id": movie.provider_id,
                    "catalog_source_id": movie.source_id,
                    "media_kind": movie.media_kind,
                },
            )
            if movie.provider_id and movie.source_id
            else None
        )
        blocks = [
            compose_news_card(
                news_id=news_id,
                title=title,
                summary=summary,
                source="CineNest Agent",
                published_at=f"{index + 1} 小时前",
                tags=tags,
                cover=movie.backdrop_url or movie.poster_url,
                action=poster_action,
            )
        ]
        images = [
            {"url": url, "caption": caption}
            for url, caption in (
                (movie.backdrop_url, "背景图"),
                (movie.poster_url, "海报"),
            )
            if url
        ]
        if images:
            blocks.append(compose_media_gallery(images, title="相关图片"))
        actions: list[MicroDesignAction] = [poster_action] if poster_action is not None else []
        items.append(
            NewsItem(
                id=news_id,
                title=title,
                source="CineNest Agent",
                published_at=(published - timedelta(hours=index + 1)).isoformat(),
                blocks=blocks,
                actions=actions,
            )
        )
    _save_items(items)
    return NewsFeed(items=items)


async def get_news_item(news_id: str) -> NewsItem:
    with get_conn() as conn:
        row = conn.execute("SELECT payload_json FROM news_items WHERE id = ?", (news_id,)).fetchone()
    if row is None:
        await build_news_feed(refresh=True)
        with get_conn() as conn:
            row = conn.execute("SELECT payload_json FROM news_items WHERE id = ?", (news_id,)).fetchone()
    if row is None:
        raise LookupError(f"未知资讯: {news_id}")
    return _item_from_payload(json.loads(row["payload_json"]))
