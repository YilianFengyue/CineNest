"""资讯 Agent Tool。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.news import NewsFeed, build_news_feed, generate_news_for_query


@tool
async def collect_movie_news(limit: int = 5) -> str:
    """生成影视资讯流卡片。用户询问资讯、热点、今日推荐或资讯页内容时调用。"""

    feed = await build_news_feed(limit=max(1, min(limit, 20)))
    return json.dumps(feed.model_dump(), ensure_ascii=False)


@tool
async def generate_movie_news(query: str, media_kind: str = "movie") -> str:
    """为某部电影/主题生成一条带 AI 海报图的资讯并持久化到资讯列表。

    用户说“给XX生成一条资讯/特辑/海报资讯”“做一张XX的资讯卡”时调用。
    """

    item = await generate_news_for_query(query, media_kind=media_kind)
    return json.dumps(NewsFeed(items=[item]).model_dump(), ensure_ascii=False)
