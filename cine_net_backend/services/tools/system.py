"""无需联网的系统工具，用于验证真实 Tool Calling。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.llm import is_llm_configured
from services.resources import get_resource_aggregator


@tool
def get_backend_status() -> str:
    """查询 CineNest 后端能力状态。用户询问系统能力、资源源数量或配置状态时调用。"""

    aggregator = get_resource_aggregator()
    payload = {
        "service": "CineNest Backend",
        "llm_configured": is_llm_configured(),
        "provider_count": len(aggregator.registry.list_all()),
        "enabled_provider_count": len(aggregator.registry.list_enabled()),
        "capabilities": ["maccms_multi_source_search", "resource_detail", "microdesign_posts", "microdesign_poster"],
    }
    return json.dumps(payload, ensure_ascii=False)
