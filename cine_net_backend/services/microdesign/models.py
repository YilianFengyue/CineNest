"""MicroDesign 输出模型：供 Flutter 直接按 blocks 渲染。"""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from services.resources.models import MediaResourceDetail, ResourceCandidate


class ContentBlock(BaseModel):
    type: str
    data: dict[str, Any] = Field(default_factory=dict)


class MicroDesignPost(BaseModel):
    id: str
    title: str
    subtitle: str = ""
    cover_url: str = ""
    recommend_reason: str
    has_video_source: bool
    source_count: int
    primary_resource: ResourceCandidate
    blocks: list[ContentBlock] = Field(default_factory=list)


class PosterSpec(BaseModel):
    id: str
    style: str
    title: str
    subtitle: str = ""
    resource: MediaResourceDetail
    blocks: list[ContentBlock] = Field(default_factory=list)
