"""MicroDesign 输出模型：供 Flutter 直接按 blocks 渲染。"""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from services.catalog.models import CatalogMovie
from services.resources.models import MediaResourceDetail, ResourceCandidate


class ContentBlock(BaseModel):
    type: str
    data: dict[str, Any] = Field(default_factory=dict)


class MicroDesignPost(BaseModel):
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


class PosterSpec(BaseModel):
    id: str
    catalog_id: str = ""
    style: str
    title: str
    subtitle: str = ""
    recommend_reason: str = ""
    catalog: CatalogMovie | None = None
    resource: MediaResourceDetail
    blocks: list[ContentBlock] = Field(default_factory=list)
