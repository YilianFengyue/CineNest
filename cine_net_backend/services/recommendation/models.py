"""推荐 Feed 返回模型。"""
from __future__ import annotations

from pydantic import BaseModel, Field

from services.catalog.models import CatalogTrace
from services.microdesign.models import MicroDesignPost


class RecommendationFeed(BaseModel):
    """Catalog 候选经过播放资源确认后的推荐帖子集合。"""

    query: str
    posts: list[MicroDesignPost] = Field(default_factory=list)
    catalog_traces: list[CatalogTrace] = Field(default_factory=list)
