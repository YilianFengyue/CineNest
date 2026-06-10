"""Agent REST 与 WebSocket 的协议模型。"""
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field

from services.assets.models import AgentInputAttachment


class AgentInvokeRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    thread_id: str = Field(default="default", min_length=1, max_length=128)
    model: str = Field(default="default", min_length=1, max_length=64)
    attachments: list[AgentInputAttachment] = Field(default_factory=list)


class AgentAttachment(BaseModel):
    """聊天气泡可直接挂载的结构化内容。"""

    type: Literal[
        "recommendation_feed",
        "microdesign_poster",
        "interactive_cards",
        "news_feed",
        "news_task",
        "debate_recommendation",
        "bilibili_companion",
        "phone_task",
    ]
    schema_version: str = "microdesign.v1.1"
    payload: dict[str, Any]


class AgentInvokeResponse(BaseModel):
    thread_id: str
    model: str = "default"
    answer: str
    tool_calls: list[dict[str, Any]] = Field(default_factory=list)
    attachments: list[AgentAttachment] = Field(default_factory=list)


class AgentStreamEvent(BaseModel):
    type: Literal["started", "delta", "tool_started", "tool_finished", "attachment", "done", "error"]
    thread_id: str
    content: str = ""
    data: dict[str, Any] = Field(default_factory=dict)
