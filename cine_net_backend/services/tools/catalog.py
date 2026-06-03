"""影视资料、推荐 Feed 与动态海报 Agent Tools。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.catalog import get_catalog_service
from services.recommendation import get_recommendation_service


def _json(payload) -> str:
    return json.dumps(payload, ensure_ascii=False)


@tool
async def browse_catalog_hot(media_kind: str = "movie", limit: int = 10) -> str:
    """浏览豆瓣/TMDB 的热门影视资料。用户没有指定片名、想看热门作品或需要推荐候选时调用。"""

    response = await get_catalog_service().hot(media_kind=media_kind, limit=max(1, min(limit, 20)))
    return _json(response.model_dump())


@tool
async def search_catalog_movies(query: str, media_kind: str = "movie", limit: int = 10) -> str:
    """跨豆瓣/TMDB 搜索电影或剧集资料，返回封面、评分、年份和简介。需要了解作品信息时调用。"""

    response = await get_catalog_service().search(query, media_kind=media_kind, limit=max(1, min(limit, 20)))
    return _json(response.model_dump())


@tool
async def build_recommendation_feed(query: str = "", media_kind: str = "movie", limit: int = 5) -> str:
    """生成 Flutter 可直接渲染的推荐帖子：先查资料候选，再确认真实可播放资源。"""

    feed = await get_recommendation_service().recommend(
        query=query,
        media_kind=media_kind,
        limit=max(1, min(limit, 10)),
        refresh=True,
    )
    return _json(feed.model_dump())


@tool
async def build_catalog_microdesign_poster(
    catalog_provider_id: str,
    catalog_source_id: str,
    media_kind: str = "movie",
) -> str:
    """为 Catalog 条目生成 Flutter 动态交互海报 blocks，并补齐真实可播放线路。"""

    poster = await get_recommendation_service().poster(
        catalog_provider_id,
        catalog_source_id,
        media_kind=media_kind,
    )
    return _json(poster.model_dump())
