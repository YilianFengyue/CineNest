"""上传资产模型。"""
from __future__ import annotations

from pydantic import BaseModel


class AssetRecord(BaseModel):
    id: str
    kind: str
    filename: str
    stored_name: str
    mime: str
    size: int
    created_at: str
    url: str


class AgentInputAttachment(BaseModel):
    asset_id: str
    kind: str = ""
    filename: str = ""

