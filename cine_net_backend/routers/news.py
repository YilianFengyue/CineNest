"""资讯 API。"""
from fastapi import APIRouter, HTTPException, Query

from services.news import NewsFeed, NewsItem, build_news_feed, get_news_item

router = APIRouter(prefix="/api/news", tags=["news"])


@router.get("", response_model=NewsFeed)
async def list_news(
    limit: int = Query(10, ge=1, le=50),
    refresh: bool = False,
) -> NewsFeed:
    """返回可直接用 MicroDesign blocks 渲染的资讯流。"""

    return await build_news_feed(limit=limit, refresh=refresh)


@router.get("/{news_id}", response_model=NewsItem)
async def news_detail(news_id: str) -> NewsItem:
    """读取单条资讯。"""

    try:
        return await get_news_item(news_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
