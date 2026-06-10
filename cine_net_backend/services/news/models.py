"""资讯卡片模型。"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field

from services.microdesign.models import ContentBlock, MicroDesignAction, MICRODESIGN_SCHEMA_VERSION


class NewsItem(BaseModel):
    schema_version: str = MICRODESIGN_SCHEMA_VERSION
    id: str
    title: str
    source: str = "CineNest Agent"
    published_at: str
    blocks: list[ContentBlock] = Field(default_factory=list)
    actions: list[MicroDesignAction] = Field(default_factory=list)


class NewsFeed(BaseModel):
    schema_version: str = MICRODESIGN_SCHEMA_VERSION
    items: list[NewsItem] = Field(default_factory=list)


class NewsTask(BaseModel):
    """一条后台资讯生成任务，供 Chat 与资讯页轮询展示。"""

    id: str
    query: str
    media_kind: str = "movie"
    status: Literal["queued", "running", "done", "failed"]
    stage: str = "排队中"
    news_id: str = ""
    error: str = ""
    created_at: str
    updated_at: str
    finished_at: str = ""
