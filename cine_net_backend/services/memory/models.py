"""Agent 长期记忆与画像协议模型。"""
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field, field_validator


MemoryType = Literal[
    "watch_history",
    "favorite",
    "explicit_preference",
    "negative_feedback",
    "chat_signal",
    "derived_trait",
]


class HistorySyncItem(BaseModel):
    id: str = ""
    title: str = ""
    cover: str | None = None
    year: str | None = None
    source: str = ""
    sourceName: str = ""
    episodeName: str | None = None
    episodeIndex: int = 0
    positionMs: int = 0
    durationMs: int = 0
    savedAt: int = 0
    tags: list[str] = Field(default_factory=list)

    @field_validator("id", "title", "cover", "year", "source", "sourceName", "episodeName", mode="before")
    @classmethod
    def _string_or_none(cls, value):
        if value is None:
            return None
        return str(value)

    @field_validator("episodeIndex", "positionMs", "durationMs", "savedAt", mode="before")
    @classmethod
    def _int_or_zero(cls, value):
        if value is None or value == "":
            return 0
        try:
            return int(value)
        except (TypeError, ValueError):
            return 0

    @field_validator("tags", mode="before")
    @classmethod
    def _tags_to_strings(cls, value):
        if value is None:
            return []
        if isinstance(value, str):
            return [value] if value.strip() else []
        if isinstance(value, list):
            return [str(item) for item in value if item is not None and str(item).strip()]
        return []


class FavoriteSyncItem(BaseModel):
    id: str = ""
    title: str = ""
    cover: str | None = None
    year: str | None = None
    source: str = ""
    sourceName: str = ""
    episodeCount: int = 0
    savedAt: int = 0
    tags: list[str] = Field(default_factory=list)

    @field_validator("id", "title", "cover", "year", "source", "sourceName", mode="before")
    @classmethod
    def _string_or_none(cls, value):
        if value is None:
            return None
        return str(value)

    @field_validator("episodeCount", "savedAt", mode="before")
    @classmethod
    def _int_or_zero(cls, value):
        if value is None or value == "":
            return 0
        try:
            return int(value)
        except (TypeError, ValueError):
            return 0

    @field_validator("tags", mode="before")
    @classmethod
    def _tags_to_strings(cls, value):
        if value is None:
            return []
        if isinstance(value, str):
            return [value] if value.strip() else []
        if isinstance(value, list):
            return [str(item) for item in value if item is not None and str(item).strip()]
        return []


class MemorySyncRequest(BaseModel):
    user_id: str = Field(default="default", min_length=1, max_length=80)
    device_id: str = Field(default="flutter", max_length=80)
    exported_at: int | None = None
    history: list[HistorySyncItem] = Field(default_factory=list)
    favorites: list[FavoriteSyncItem] = Field(default_factory=list)


class MemorySyncResponse(BaseModel):
    ok: bool = True
    batch_id: str
    user_id: str
    history_received: int
    favorites_received: int
    upserted: int
    profile_updated_at: str


class AgentMemoryItem(BaseModel):
    id: str
    user_id: str = "default"
    memory_type: MemoryType
    subject: str = ""
    relation: str = ""
    object: str = ""
    source: str = ""
    confidence: float = 0.5
    weight: float = 1.0
    payload: dict[str, Any] = Field(default_factory=dict)
    created_at: str
    updated_at: str
    last_seen_at: str


class ProfileTag(BaseModel):
    name: str
    weight: float = 0
    count: int = 0
    evidence: list[str] = Field(default_factory=list)


class ProfileMetric(BaseModel):
    key: str
    label: str
    value: float = Field(ge=0, le=100)
    hint: str = ""


class ProfileGraphNode(BaseModel):
    id: str
    label: str
    type: Literal["user", "genre", "movie", "source", "trait", "risk"]
    value: float = 1
    payload: dict[str, Any] = Field(default_factory=dict)


class ProfileGraphEdge(BaseModel):
    id: str
    source: str
    target: str
    relation: str
    weight: float = 1
    payload: dict[str, Any] = Field(default_factory=dict)


class ProfileTimelineItem(BaseModel):
    at: str
    type: str
    title: str
    subtitle: str = ""
    weight: float = 1
    payload: dict[str, Any] = Field(default_factory=dict)


class AgentProfile(BaseModel):
    user_id: str = "default"
    summary: str = "暂无足够数据，先同步本地观看历史和收藏。"
    taste_tags: list[ProfileTag] = Field(default_factory=list)
    avoid_tags: list[ProfileTag] = Field(default_factory=list)
    source_distribution: list[ProfileTag] = Field(default_factory=list)
    format_distribution: list[ProfileTag] = Field(default_factory=list)
    radar_metrics: list[ProfileMetric] = Field(default_factory=list)
    graph_nodes: list[ProfileGraphNode] = Field(default_factory=list)
    graph_edges: list[ProfileGraphEdge] = Field(default_factory=list)
    timeline: list[ProfileTimelineItem] = Field(default_factory=list)
    stats: dict[str, Any] = Field(default_factory=dict)
    updated_at: str = ""


class ProfileRebuildRequest(BaseModel):
    user_id: str = Field(default="default", min_length=1, max_length=80)
    use_llm: bool = False
