"""资讯卡片模型。"""
from __future__ import annotations

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

