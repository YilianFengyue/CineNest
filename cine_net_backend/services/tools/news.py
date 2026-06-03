"""资讯 Agent Tool。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.news import build_news_feed


@tool
async def collect_movie_news(limit: int = 5) -> str:
    """生成影视资讯流卡片。用户询问资讯、热点、今日推荐或资讯页内容时调用。"""

    feed = await build_news_feed(limit=max(1, min(limit, 20)))
    return json.dumps(feed.model_dump(), ensure_ascii=False)
