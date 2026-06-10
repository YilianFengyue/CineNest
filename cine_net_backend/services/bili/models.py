"""Shared Bilibili response helpers."""
from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class BiliEnvelope(BaseModel):
    schema_version: str = "bili.raw.v1"
    source: str = "bilibili"
    result_type: str
    data: Any
    page: int | None = None
    page_size: int | None = None
    count: int = 0
    keyword: str = ""
    movie: str = ""
    year: str = ""
    query_used: list[str] = Field(default_factory=list)
    extra: dict[str, Any] = Field(default_factory=dict)
