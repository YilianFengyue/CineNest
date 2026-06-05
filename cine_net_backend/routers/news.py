"""资讯 API。"""
from fastapi import APIRouter, BackgroundTasks, HTTPException, Query
from pydantic import BaseModel, Field

from services.news import (
    NewsFeed,
    NewsItem,
    NewsTask,
    build_news_feed,
    create_news_task,
    get_news_item,
    get_news_task,
    list_news_tasks,
    run_news_task,
)

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


@router.post("/generate", response_model=NewsTask)
async def generate_news(payload: GenerateNewsRequest, background_tasks: BackgroundTasks) -> NewsTask:
    """提交一条 AI 资讯生成任务，后台完成后自动进入资讯列表。"""

    try:
        task = create_news_task(payload.query, media_kind=payload.media_kind)
        background_tasks.add_task(run_news_task, task.id)
        return task
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"资讯任务创建失败: {exc}") from exc


@router.get("/tasks", response_model=list[NewsTask])
async def news_tasks(limit: int = Query(20, ge=1, le=100)) -> list[NewsTask]:
    """返回最近的资讯生成任务，供资讯页轮询进度。"""

    return list_news_tasks(limit=limit)


@router.get("/tasks/{task_id}", response_model=NewsTask)
async def news_task_detail(task_id: str) -> NewsTask:
    """读取单条资讯生成任务。"""

    try:
        return get_news_task(task_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/{news_id}", response_model=NewsItem)
async def news_detail(news_id: str) -> NewsItem:
    """读取单条资讯。"""

    try:
        return await get_news_item(news_id)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
