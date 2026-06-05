"""LLM 模型配置。"""
from __future__ import annotations

from pydantic import BaseModel


class ChatModelInfo(BaseModel):
    id: str
    label: str
    model: str
    configured: bool
    supports_images: bool = False

