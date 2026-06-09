"""伪 Multi-Agent 辩论式推荐模型。"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class HighlightMoment(BaseModel):
    label: str = Field(description="精彩片段名称，例如 开场世界观建立")
    why: str = Field(description="为什么值得看")
    spoiler_level: Literal["low", "medium", "high"] = "low"
    approx_time: str = Field(default="", description="有可靠依据时才写大致时间，否则留空")
    button_text: str = "查看片段"
    action: dict = Field(default_factory=dict)


class DebateRenderReply(BaseModel):
    author: str
    content: str
    likes: int = 0


class DebateRenderItem(BaseModel):
    id: str = ""
    author: str = ""
    badge: str = "AI"
    avatar_seed: str = ""
    content: str = ""
    likes: int = 0
    dislikes: int = 0
    time_label: str = "刚刚"
    location: str = "AI 推荐委员会"
    reply_preview: list[DebateRenderReply] = Field(default_factory=list)
    label: str = ""
    why: str = ""
    button_text: str = ""
    action: dict = Field(default_factory=dict)


class DebateRenderSection(BaseModel):
    type: Literal["committee_summary", "hot_comments", "highlight_buttons", "danmaku_seeds"]
    title: str
    subtitle: str = ""
    items: list[DebateRenderItem] = Field(default_factory=list)
    seeds: list[str] = Field(default_factory=list)


class DebateRecommendationRequest(BaseModel):
    user_id: str = Field(default="default", min_length=1, max_length=80)
    movie: str = Field(min_length=1, max_length=120)
    year: str | None = None
    overview: str = ""
    source_name: str = ""
    episode_name: str = ""
    playable: bool = True
    rating: str | None = None
    tags: list[str] = Field(default_factory=list)
    model: str = "default"


class DebateRecommendation(BaseModel):
    schema_version: str = "debate.v1"
    movie: str
    committee_title: str = "AI 推荐委员会结论"
    taste_agent: str
    resource_agent: str
    review_agent: str
    critic_agent: str
    chair_agent: str
    final_score: int = Field(ge=0, le=100)
    final_reason: str
    risk_tips: list[str] = Field(default_factory=list)
    highlight_moments: list[HighlightMoment] = Field(default_factory=list)
    render_sections: list[DebateRenderSection] = Field(default_factory=list)
    recommend: bool
    confidence: float = Field(default=0.72, ge=0, le=1)
    evidence: list[str] = Field(default_factory=list)


class DebateRecommendationEnvelope(BaseModel):
    user_id: str
    generated_by: Literal["llm", "fallback"] = "fallback"
    profile_summary: str = ""
    result: DebateRecommendation
