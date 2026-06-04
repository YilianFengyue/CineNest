"""资讯流服务。第一版用热门影视资料生成可渲染资讯卡。"""
from __future__ import annotations

import json
from collections.abc import Callable
from datetime import datetime, timedelta, timezone
from uuid import NAMESPACE_URL, uuid4, uuid5

from db import get_conn
from services.catalog import get_catalog_service
from services.images import generate_image, is_image_enabled, movie_image_prompt
from services.microdesign import compose_media_gallery, compose_news_card
from services.microdesign.models import MicroDesignAction

from .models import NewsFeed, NewsItem, NewsTask


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _news_id(seed: str) -> str:
    return f"news-{uuid5(NAMESPACE_URL, seed).hex[:16]}"


def _task_id() -> str:
    return f"news-task-{uuid4().hex[:16]}"


def _item_from_payload(payload: dict) -> NewsItem:
    return NewsItem.model_validate(payload)


def _task_from_row(row) -> NewsTask:
    return NewsTask(
        id=row["id"],
        query=row["query"],
        media_kind=row["media_kind"],
        status=row["status"],
        stage=row["stage"],
        news_id=row["news_id"],
        error=row["error"],
        created_at=row["created_at"],
        updated_at=row["updated_at"],
        finished_at=row["finished_at"],
    )


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


def _create_task_record(query: str, media_kind: str) -> NewsTask:
    now = _now()
    task = NewsTask(
        id=_task_id(),
        query=query,
        media_kind=media_kind,
        status="queued",
        stage="排队中",
        created_at=now,
        updated_at=now,
    )
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO news_tasks(id, query, media_kind, status, stage, news_id, error, created_at, updated_at, finished_at)
            VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """,
            (
                task.id,
                task.query,
                task.media_kind,
                task.status,
                task.stage,
                task.news_id,
                task.error,
                task.created_at,
                task.updated_at,
                task.finished_at,
            ),
        )
    return task


def _update_task(
    task_id: str,
    *,
    status: str | None = None,
    stage: str | None = None,
    news_id: str | None = None,
    error: str | None = None,
    finished: bool = False,
) -> None:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM news_tasks WHERE id = ?", (task_id,)).fetchone()
        if row is None:
            raise LookupError(f"未知资讯任务: {task_id}")
        conn.execute(
            """
            UPDATE news_tasks
               SET status = ?,
                   stage = ?,
                   news_id = ?,
                   error = ?,
                   updated_at = ?,
                   finished_at = ?
             WHERE id = ?
            """,
            (
                status or row["status"],
                stage or row["stage"],
                news_id if news_id is not None else row["news_id"],
                error if error is not None else row["error"],
                _now(),
                _now() if finished else row["finished_at"],
                task_id,
            ),
        )


def get_news_task(task_id: str) -> NewsTask:
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM news_tasks WHERE id = ?", (task_id,)).fetchone()
    if row is None:
        raise LookupError(f"未知资讯任务: {task_id}")
    return _task_from_row(row)


def list_news_tasks(*, limit: int = 20) -> list[NewsTask]:
    with get_conn() as conn:
        rows = conn.execute(
            "SELECT * FROM news_tasks ORDER BY updated_at DESC LIMIT ?",
            (limit,),
        ).fetchall()
    return [_task_from_row(row) for row in rows]


def create_news_task(query: str, *, media_kind: str = "movie") -> NewsTask:
    query = query.strip()
    if not query:
        raise ValueError("资讯主题不能为空")
    return _create_task_record(query, media_kind)


async def build_news_feed(*, limit: int = 10, refresh: bool = False) -> NewsFeed:
    cached = _load_cached(limit)
    if not refresh:
        if len(cached) >= limit:
            return NewsFeed(items=cached[:limit])
    catalog = await get_catalog_service().hot(media_kind="movie", limit=max(limit, 10))
    published = datetime.now(timezone.utc)
    items: list[NewsItem] = []
    cached_ids = {item.id for item in cached}
    for index, movie in enumerate(catalog.items[:limit]):
        news_id = _news_id(movie.catalog_id or movie.title)
        if news_id in cached_ids:
            continue
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
    latest = _load_cached(limit)
    return NewsFeed(items=latest or cached[:limit])


async def generate_news_for_query(
    query: str,
    *,
    media_kind: str = "movie",
    stage_callback: Callable[[str], None] | None = None,
) -> NewsItem:
    """按片名/主题生成一条「AI 资讯」：资料 + AI 生成海报图，持久化后进资讯列表。

    生图失败会自动回退到 TMDB/豆瓣海报，不会让整条资讯失败。
    """

    query = query.strip()
    if not query:
        raise ValueError("资讯主题不能为空")
    if stage_callback is not None:
        stage_callback("检索影视资料")
    catalog = await get_catalog_service().search(query, media_kind=media_kind, limit=5)
    if not catalog.items:
        raise LookupError(f"未找到与“{query}”相关的影视资料")
    movie = catalog.items[0]
    news_id = _news_id(f"gen:{movie.catalog_id or movie.title}")

    cover = movie.backdrop_url or movie.poster_url or ""
    gallery_urls = [url for url in (movie.backdrop_url, movie.poster_url) if url]
    ai_generated = False
    if is_image_enabled():
        if stage_callback is not None:
            stage_callback("生成 AI 视觉")
        asset = await generate_image(
            movie_image_prompt(movie.title, movie.genres, movie.overview or "", kind="poster"),
            size="1024x1536",
        )
        if asset is not None:
            cover = asset.url
            gallery_urls = [asset.url, *gallery_urls]
            ai_generated = True

    if stage_callback is not None:
        stage_callback("组装资讯卡")
    title = f"AI 影视特辑 · 《{movie.title}》"
    summary = movie.overview or (
        f"{movie.provider_name} 资料"
        f"{f'，评分 {movie.rating:.1f}' if movie.rating is not None else ''}，"
        "由 CineNest 结合 AI 视觉生成的影视资讯卡。"
    )
    tags = [*movie.genres[:4]]
    if movie.year:
        tags.append(movie.year)
    if ai_generated:
        tags.append("AI 生成")

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
            source="CineNest AI",
            published_at="刚刚",
            tags=tags,
            cover=cover,
            action=poster_action,
        )
    ]
    if gallery_urls:
        blocks.append(
            compose_media_gallery(
                [{"url": url, "caption": "AI 视觉"} for url in gallery_urls],
                title="AI 视觉",
            )
        )
    actions: list[MicroDesignAction] = [poster_action] if poster_action is not None else []
    item = NewsItem(
        id=news_id,
        title=title,
        source="CineNest AI",
        published_at=datetime.now(timezone.utc).isoformat(),
        blocks=blocks,
        actions=actions,
    )
    if stage_callback is not None:
        stage_callback("写入资讯库")
    _save_items([item])
    return item


async def run_news_task(task_id: str) -> NewsTask:
    task = get_news_task(task_id)
    _update_task(task_id, status="running", stage="准备生成", error="")

    def update_stage(stage: str) -> None:
        _update_task(task_id, status="running", stage=stage)

    try:
        item = await generate_news_for_query(task.query, media_kind=task.media_kind, stage_callback=update_stage)
    except Exception as exc:  # noqa: BLE001
        _update_task(task_id, status="failed", stage="生成失败", error=str(exc), finished=True)
        return get_news_task(task_id)
    _update_task(task_id, status="done", stage="已完成", news_id=item.id, error="", finished=True)
    return get_news_task(task_id)


def seed_news_items() -> list[NewsItem]:
    """写入一批可展示的后端资讯数据，供资讯页离线/演示使用。"""

    now = datetime.now(timezone.utc)
    seeds = [
        {
            "id": "seed-news-sci-fi-night",
            "title": "周末科幻片单：从太空孤独感到赛博城市",
            "summary": "CineNest 预置了一组适合夜间观看的科幻主题资讯，用来验证资讯列表、收藏和微海报跳转。",
            "tags": ["科幻", "片单", "周末"],
            "cover": "https://picsum.photos/seed/cinenest-scifi/900/520",
            "gallery": [
                "https://picsum.photos/seed/cinenest-scifi-a/640/420",
                "https://picsum.photos/seed/cinenest-scifi-b/640/420",
            ],
        },
        {
            "id": "seed-news-animation-family",
            "title": "动画电影补课：轻松但不浅的家庭观影",
            "summary": "这一批种子数据用于保证后端接口首次启动也有内容可看，图片走稳定占位源，前端失败时仍会二次兜底。",
            "tags": ["动画", "家庭", "治愈"],
            "cover": "https://picsum.photos/seed/cinenest-animation/900/520",
            "gallery": [
                "https://picsum.photos/seed/cinenest-animation-a/640/420",
                "https://picsum.photos/seed/cinenest-animation-b/640/420",
            ],
        },
        {
            "id": "seed-news-crime-suspense",
            "title": "悬疑犯罪专题：把线索藏进海报和台词里",
            "summary": "用于测试 newsCard + mediaGallery 的混合渲染，以及点击后进入互动海报页的组合逻辑。",
            "tags": ["悬疑", "犯罪", "海报"],
            "cover": "https://picsum.photos/seed/cinenest-crime/900/520",
            "gallery": [
                "https://picsum.photos/seed/cinenest-crime-a/640/420",
                "https://picsum.photos/seed/cinenest-crime-b/640/420",
            ],
        },
        {
            "id": "seed-news-classic-review",
            "title": "经典重看：为什么老电影仍然适合今天推荐",
            "summary": "这条资讯模拟 Agent 的策展口吻，方便验收资讯流滚动、详情入口和收藏状态持久化。",
            "tags": ["经典", "重看", "推荐"],
            "cover": "https://picsum.photos/seed/cinenest-classic/900/520",
            "gallery": [
                "https://picsum.photos/seed/cinenest-classic-a/640/420",
                "https://picsum.photos/seed/cinenest-classic-b/640/420",
            ],
        },
        {
            "id": "seed-news-award-season",
            "title": "颁奖季观察：从口碑热度到个人片单",
            "summary": "预置数据不依赖外部 Catalog，适合在断网或第三方 API 不稳定时做资讯页演示。",
            "tags": ["颁奖季", "口碑", "片单"],
            "cover": "https://picsum.photos/seed/cinenest-awards/900/520",
            "gallery": [
                "https://picsum.photos/seed/cinenest-awards-a/640/420",
                "https://picsum.photos/seed/cinenest-awards-b/640/420",
            ],
        },
    ]
    items: list[NewsItem] = []
    for index, seed in enumerate(seeds):
        action = MicroDesignAction(
            type="openPoster",
            label="查看互动海报",
            data={},
        )
        blocks = [
            compose_news_card(
                news_id=seed["id"],
                title=seed["title"],
                summary=seed["summary"],
                source="CineNest Seed",
                published_at=f"{index + 1} 小时前",
                tags=seed["tags"],
                cover=seed["cover"],
                action=action,
            ),
            compose_media_gallery(
                [{"url": url, "caption": "预置视觉"} for url in seed["gallery"]],
                title="预置图集",
            ),
        ]
        items.append(
            NewsItem(
                id=seed["id"],
                title=seed["title"],
                source="CineNest Seed",
                published_at=(now - timedelta(hours=index + 1)).isoformat(),
                blocks=blocks,
                actions=[action],
            )
        )
    _save_items(items)
    return items


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
