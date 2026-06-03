"""MicroDesign 输出模型：供 Flutter 直接按 blocks 渲染。"""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from services.catalog.models import CatalogMovie
from services.resources.models import MediaResourceDetail, ResourceCandidate

MICRODESIGN_SCHEMA_VERSION = "microdesign.v1.1"
SUPPORTED_BLOCKS = [
    "posterRow",
    "banner",
    "rating",
    "tagRow",
    "heading",
    "text",
    "videoBar",
    "imageSwiper",
    "playableMovieCard",
    "movieCarousel",
    "reviewQuoteCard",
    "sourceTraceCard",
    "newsCard",
    "mediaGallery",
    "videoExplainCard",
]
SUPPORTED_ACTIONS = [
    "openPoster",
    "openResourcePoster",
    "resolveAndPlay",
]
SUPPORTED_STYLES = ["warm", "neon", "contrast"]


class MicroDesignAction(BaseModel):
    """Flutter 只处理白名单动作，不解析自然语言。"""

    type: str
    label: str = ""
    data: dict[str, Any] = Field(default_factory=dict)


class ContentBlock(BaseModel):
    type: str
    data: dict[str, Any] = Field(default_factory=dict)
    action: MicroDesignAction | None = None


class MicroDesignPost(BaseModel):
    schema_version: str = MICRODESIGN_SCHEMA_VERSION
    id: str
    catalog_id: str = ""
    title: str
    subtitle: str = ""
    cover_url: str = ""
    backdrop_url: str = ""
    rating: float | None = None
    rating_count: int | None = None
    overview: str = ""
    genres: list[str] = Field(default_factory=list)
    recommend_reason: str
    has_video_source: bool
    source_count: int
    primary_resource: ResourceCandidate
    blocks: list[ContentBlock] = Field(default_factory=list)
    actions: list[MicroDesignAction] = Field(default_factory=list)


class PosterSpec(BaseModel):
    schema_version: str = MICRODESIGN_SCHEMA_VERSION
    id: str
    catalog_id: str = ""
    style: str
    title: str
    subtitle: str = ""
    recommend_reason: str = ""
    catalog: CatalogMovie | None = None
    resource: MediaResourceDetail
    blocks: list[ContentBlock] = Field(default_factory=list)
    actions: list[MicroDesignAction] = Field(default_factory=list)


class InteractiveCardsPayload(BaseModel):
    """Agent 聊天气泡可挂载的交互卡片集合。"""

    schema_version: str = MICRODESIGN_SCHEMA_VERSION
    cards: list[ContentBlock] = Field(default_factory=list)
    actions: list[MicroDesignAction] = Field(default_factory=list)


class MicroDesignSchema(BaseModel):
    schema_version: str = MICRODESIGN_SCHEMA_VERSION
    blocks: list[str] = Field(default_factory=lambda: SUPPORTED_BLOCKS)
    actions: list[str] = Field(default_factory=lambda: SUPPORTED_ACTIONS)
    styles: list[str] = Field(default_factory=lambda: SUPPORTED_STYLES)
