"""影视资源 Tools：Agent 只能通过这些工具获取真实资源。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.microdesign import compose_recommendation_posts
from services.resources import get_resource_aggregator


def _json(payload) -> str:
    return json.dumps(payload, ensure_ascii=False)


@tool
async def search_playable_resources(keyword: str, limit: int = 5) -> str:
    """按影视名称并发搜索已启用资源站，返回真实候选和逐源 trace。找片、推荐或确认是否可播放时调用。"""

    response = await get_resource_aggregator().search(keyword)
    compact_items = [
        {
            "title": item.title,
            "category": item.category,
            "remarks": item.remarks,
            "source_count": len(item.sources),
            "sources": [source.model_dump() for source in item.sources[:3]],
        }
        for item in response.items[: max(1, min(limit, 10))]
    ]
    return _json(
        {
            "keyword": keyword,
            "items": compact_items,
            "provider_summary": {
                "ok": sum(1 for trace in response.traces if trace.ok),
                "failed": sum(1 for trace in response.traces if not trace.ok),
            },
        }
    )


@tool
async def get_playable_resource_detail(provider_id: str, remote_id: str) -> str:
    """解析指定资源站条目的详情与真实播放线路。仅在需要查看剧集或播放地址时调用。"""

    detail = await get_resource_aggregator().detail(provider_id, remote_id)
    return _json(detail.model_dump())


@tool
async def build_microdesign_posts(keyword: str, limit: int = 5) -> str:
    """按用户主题搜索真实影视资源，并生成可由 Flutter 渲染的 MicroDesign 推荐帖子。"""

    response = await get_resource_aggregator().search(keyword)
    posts = compose_recommendation_posts(response, limit=max(1, min(limit, 10)))
    return _json([post.model_dump() for post in posts])
