"""上传资产模型。"""
from __future__ import annotations

from pydantic import BaseModel, computed_field


class AssetRecord(BaseModel):
    id: str
    kind: str
    filename: str
    stored_name: str
    mime: str
    size: int
    created_at: str
    url: str

    @computed_field
    @property
    def asset_id(self) -> str:
        """兼容前端多模态附件字段；真实主键仍是 id。"""

        return self.id


class AgentInputAttachment(BaseModel):
    asset_id: str
    kind: str = ""
    filename: str = ""
