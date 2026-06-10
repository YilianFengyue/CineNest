"""影视资料 Catalog 数据模型。"""
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


MediaKind = Literal["movie", "tv", "show", "unknown"]


class CatalogProviderConfig(BaseModel):
    """单个资料源配置。新增 Provider 时优先追加 YAML 配置。"""

    id: str
    name: str
    kind: str
    enabled: bool = True
    priority: int = 100
    options: dict[str, Any] = Field(default_factory=dict)


class CatalogSourceRef(BaseModel):
    """同一影视条目在不同 Catalog Provider 中的来源引用。"""

    provider_id: str
    provider_name: str
    source_id: str
    source_url: str = ""


class CatalogMovie(BaseModel):
    """供 Agent、帖子和海报共同使用的标准影视资料。"""

    catalog_id: str
    provider_id: str
    provider_name: str
    source_id: str
    title: str
    original_title: str = ""
    year: str = ""
    media_kind: MediaKind = "unknown"
    rating: float | None = None
    rating_count: int | None = None
    poster_url: str = ""
    backdrop_url: str = ""
    overview: str = ""
    genres: list[str] = Field(default_factory=list)
    directors: list[str] = Field(default_factory=list)
    cast: list[str] = Field(default_factory=list)
    source_url: str = ""
    sources: list[CatalogSourceRef] = Field(default_factory=list)


class CatalogTrace(BaseModel):
    """资料源调用 trace。"""

    provider_id: str
    provider_name: str
    ok: bool
    elapsed_ms: int
    result_count: int = 0
    error: str | None = None


class CatalogSearchResponse(BaseModel):
    """双源搜索结果。"""

    query: str
    items: list[CatalogMovie] = Field(default_factory=list)
    traces: list[CatalogTrace] = Field(default_factory=list)


class CatalogProviderHealth(BaseModel):
    """资料源配置状态。"""

    provider_id: str
    provider_name: str
    kind: str
    enabled: bool
    configured: bool
    priority: int
