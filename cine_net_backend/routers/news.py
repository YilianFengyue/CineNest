"""资讯 API。"""
from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel, Field

from services.news import NewsFeed, NewsItem, build_news_feed, generate_news_for_query, get_news_item

router = APIRouter(prefix="/api/news", tags=["news"])


class GenerateNewsRequest(BaseModel):
    query: str = Field(min_length=1, max_length=100)
    media_kind: str = Field(default="movie")


@router.get("", response_model=NewsFeed)
async def list_news(
    limit: int = Query(10, ge=1, le=50),
    refresh: bool = False,
) -> NewsFeed:
    """返回可直接用 MicroDesign blocks 渲染的资讯流。"""

    return await build_news_feed(limit=limit, refresh=refresh)


@router.post("/generate", response_model=NewsItem)
async def generate_news(payload: GenerateNewsRequest) -> NewsItem:
    """按片名/主题生成一条 AI 资讯（含 AI 海报图），持久化后即进资讯列表。"""

    try:
        return await generate_news_for_query(payload.query, media_kind=payload.media_kind)
    except (ValueError, LookupError) as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"资讯生成失败: {exc}") from exc


@router.get("/{news_id}", response_model=NewsItem)
async def news_detail(news_id: str) -> NewsItem:
    """读取单条资讯。"""

    try:
        return await get_news_item(news_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
