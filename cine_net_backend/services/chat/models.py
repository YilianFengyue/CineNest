"""聊天持久化模型。"""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class ChatSession(BaseModel):
    id: str
    title: str = ""
    model: str = "default"
    created_at: str
    updated_at: str


class ChatMessageRecord(BaseModel):
    id: str
    session_id: str
    role: str
    content: str = ""
    attachments: list[dict[str, Any]] = Field(default_factory=list)
    tool_calls: list[dict[str, Any]] = Field(default_factory=list)
    created_at: str


class ChatHistoryResponse(BaseModel):
    session: ChatSession
    messages: list[ChatMessageRecord] = Field(default_factory=list)
