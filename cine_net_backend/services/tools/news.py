"""资讯 Agent Tool。"""
from __future__ import annotations

import asyncio
import json

from langchain.tools import tool

from services.news import NewsFeed, build_news_feed, create_news_task, run_news_task


@tool
async def collect_movie_news(limit: int = 5) -> str:
    """生成影视资讯流卡片。用户询问资讯、热点、今日推荐或资讯页内容时调用。"""

    feed = await build_news_feed(limit=max(1, min(limit, 20)))
    return json.dumps(feed.model_dump(), ensure_ascii=False)


@tool
async def generate_movie_news(query: str, media_kind: str = "movie") -> str:
    """为某部电影/主题提交一条带 AI 海报图的资讯后台任务。

    用户说“给XX生成一条资讯/特辑/海报资讯”“做一张XX的资讯卡”时调用。
    """

    task = create_news_task(query, media_kind=media_kind)
    asyncio.create_task(run_news_task(task.id))
    return json.dumps(task.model_dump(), ensure_ascii=False)
