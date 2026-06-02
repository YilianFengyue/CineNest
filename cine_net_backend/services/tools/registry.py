"""集中注册 Agent 工具，后续新增 Provider 或 RAG 工具从这里接入。"""
from __future__ import annotations

from langchain_core.tools import BaseTool

from .media import build_microdesign_posts, get_playable_resource_detail, search_playable_resources
from .system import get_backend_status


def get_agent_tools() -> list[BaseTool]:
    return [
        get_backend_status,
        search_playable_resources,
        get_playable_resource_detail,
        build_microdesign_posts,
    ]
