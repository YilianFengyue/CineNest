"""影视资源聚合层的数据模型。"""
from __future__ import annotations

from pydantic import BaseModel, Field


class ProviderConfig(BaseModel):
    """单个资源站配置。新增 MacCMS 源时只改 YAML。"""

    id: str
    name: str
    endpoint: str = ""
    kind: str = "maccms"
    enabled: bool = True
    detail_action: str = "detail"
    headers: dict[str, str] = Field(default_factory=dict)
    options: dict[str, str] = Field(default_factory=dict)


class Episode(BaseModel):
    """可播放剧集或分段。"""

    name: str
    play_url: str


class PlayLine(BaseModel):
    """资源站的一条播放线路。"""

    name: str
    episodes: list[Episode] = Field(default_factory=list)


class ResourceCandidate(BaseModel):
    """某个 Provider 返回的一条影视搜索结果。"""

    provider_id: str
    provider_name: str
    remote_id: str
    title: str
    category: str = ""
    cover_url: str = ""
    remarks: str = ""
    year: str = ""


class MediaResourceDetail(ResourceCandidate):
    """单个资源详情，包含简介与播放线路。"""

    summary: str = ""
    play_lines: list[PlayLine] = Field(default_factory=list)

    @property
    def episode_count(self) -> int:
        return sum(len(line.episodes) for line in self.play_lines)


class ProviderSearchTrace(BaseModel):
    """逐 Provider 可观测结果。"""

    provider_id: str
    provider_name: str
    ok: bool
    elapsed_ms: int
    result_count: int = 0
    error: str | None = None


class AggregatedMediaItem(BaseModel):
    """按标题归并后的影视条目。"""

    normalized_title: str
    title: str
    category: str = ""
    cover_url: str = ""
    remarks: str = ""
    year: str = ""
    sources: list[ResourceCandidate] = Field(default_factory=list)


class ResourceSearchResponse(BaseModel):
    """多源并发检索结果。"""

    keyword: str
    items: list[AggregatedMediaItem] = Field(default_factory=list)
    traces: list[ProviderSearchTrace] = Field(default_factory=list)


class ProviderHealth(BaseModel):
    """Provider 健康状态。"""

    provider_id: str
    provider_name: str
    endpoint: str
    enabled: bool
    ok: bool | None = None
    elapsed_ms: int | None = None
    error: str | None = None


class PlayDescriptor(BaseModel):
    """Flutter 播放器消费的统一播放描述。"""

    type: str = "direct"
    play_url: str = ""
    headers: dict[str, str] = Field(default_factory=dict)
    expires_at: str | None = None
    fallback_web_url: str | None = None
    provider_id: str
    remote_id: str
    title: str = ""
    line_name: str = ""
    episode_name: str = ""
