"""Bilibili Agent tools."""
from __future__ import annotations

import json

from langchain.tools import tool

from services.bili import get_article_markdown, get_movie_videos, search_articles, search_up_users
from services.bili.service import compact_videos_for_agent


@tool
async def search_bili_movie_videos(movie: str, year: str = "", page: int = 1, page_size: int = 8) -> str:
    """搜索某部影视在 B站的相关解说、影评、混剪、预告等视频。"""

    envelope = await get_movie_videos(movie, year=year, page=page, page_size=min(page_size, 10))
    payload = {
        "schema_version": "bili.tool.v1",
        "movie": movie,
        "year": year,
        "page": envelope.page,
        "page_size": envelope.page_size,
        "query_used": envelope.query_used,
        "videos": compact_videos_for_agent(envelope, limit=min(page_size, 10)),
        "extra": envelope.extra,
    }
    return json.dumps(payload, ensure_ascii=False)


@tool
async def search_bili_articles(keyword: str, page: int = 1, page_size: int = 5) -> str:
    """搜索 B站专栏影评或影视文字内容，返回轻量摘要供进一步总结。"""

    envelope = await search_articles(keyword, page=page, page_size=min(page_size, 8))
    articles = []
    for item in envelope.data[: min(page_size, 8)] if isinstance(envelope.data, list) else []:
        extra = item.get("_cinenest") or {}
        articles.append(
            {
                "id": item.get("id") or item.get("cvid"),
                "title": extra.get("title_plain") or item.get("title") or "",
                "author": item.get("author") or item.get("uname") or item.get("name") or "",
                "url": extra.get("web_url") or "",
                "app_url": extra.get("app_url") or "",
                "summary": item.get("desc") or item.get("description") or item.get("summary") or "",
            }
        )
    return json.dumps(
        {
            "schema_version": "bili.tool.v1",
            "keyword": keyword,
            "articles": articles,
            "extra": envelope.extra,
        },
        ensure_ascii=False,
    )


@tool
async def get_bili_article_markdown(cvid: int) -> str:
    """获取 B站专栏 Markdown，适合让 Agent 总结影评观点。"""

    envelope = await get_article_markdown(cvid)
    data = envelope.data if isinstance(envelope.data, dict) else {}
    markdown = str(data.get("markdown") or "")
    payload = {
        "schema_version": "bili.tool.v1",
        "cvid": cvid,
        "url": data.get("url") or "",
        "app_url": data.get("app_url") or "",
        "markdown": markdown[:6000],
        "truncated": len(markdown) > 6000,
    }
    return json.dumps(payload, ensure_ascii=False)


@tool
async def search_bili_up_users(keyword: str, page: int = 1, page_size: int = 5) -> str:
    """搜索 B站 UP 主，用于寻找影视解说、影评、混剪内容源。"""

    envelope = await search_up_users(keyword, page=page, page_size=min(page_size, 8))
    users = []
    for item in envelope.data[: min(page_size, 8)] if isinstance(envelope.data, list) else []:
        extra = item.get("_cinenest") or {}
        users.append(
            {
                "mid": item.get("mid") or item.get("id") or item.get("uid"),
                "name": extra.get("name_plain") or item.get("uname") or item.get("name") or "",
                "fans": item.get("fans") or item.get("fans_count") or 0,
                "sign": item.get("usign") or item.get("sign") or "",
                "url": extra.get("web_url") or "",
                "app_url": extra.get("app_url") or "",
            }
        )
    return json.dumps(
        {
            "schema_version": "bili.tool.v1",
            "keyword": keyword,
            "users": users,
            "extra": envelope.extra,
        },
        ensure_ascii=False,
    )


@tool
async def build_bili_companion(movie: str, year: str = "", intent: str = "analysis", page_size: int = 8) -> str:
    """为聊天界面构建 B站观影伴侣卡片，返回相关视频轻量列表和 App 跳转链接。"""

    envelope = await get_movie_videos(movie, year=year, page=1, page_size=min(page_size, 10))
    videos = compact_videos_for_agent(envelope, limit=min(page_size, 10))
    payload = {
        "schema_version": "bili.v1",
        "movie": movie,
        "year": year,
        "intent": intent,
        "answer": f"我从 B站相关内容里挑了 {len(videos)} 条，可直接跳转 B站 App 观看。",
        "query_used": envelope.query_used,
        "videos": videos,
        "sections": [
            {
                "type": "bilibili_videos",
                "title": "B站相关视频",
                "items": videos,
            }
        ],
        "extra": envelope.extra,
    }
    return json.dumps(payload, ensure_ascii=False)
