"""Agent REST 与 WebSocket 的协议模型。"""
from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field


class AgentInvokeRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    thread_id: str = Field(default="default", min_length=1, max_length=128)


class AgentInvokeResponse(BaseModel):
    thread_id: str
    answer: str
    tool_calls: list[dict[str, Any]] = Field(default_factory=list)


class AgentStreamEvent(BaseModel):
    type: Literal["started", "delta", "tool_started", "tool_finished", "done", "error"]
    thread_id: str
    content: str = ""
    data: dict[str, Any] = Field(default_factory=dict)
