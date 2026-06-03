"""无需联网的系统工具，用于验证真实 Tool Calling。"""
from __future__ import annotations

import json

from langchain.tools import tool

from services.catalog import get_catalog_service
from services.llm import is_llm_configured
from services.microdesign.models import MICRODESIGN_SCHEMA_VERSION
from services.resources import get_resource_aggregator


@tool
def get_backend_status() -> str:
    """查询 CineNest 后端能力状态。用户询问系统能力、资源源数量或配置状态时调用。"""

    aggregator = get_resource_aggregator()
    catalog = get_catalog_service()
    payload = {
        "service": "CineNest Backend",
        "llm_configured": is_llm_configured(),
        "provider_count": len(aggregator.registry.list_all()),
        "enabled_provider_count": len(aggregator.registry.list_enabled()),
        "catalog_providers": [provider.model_dump() for provider in catalog.providers()],
        "microdesign_schema_version": MICRODESIGN_SCHEMA_VERSION,
        "capabilities": [
            "maccms_multi_source_search",
            "catalog_search",
            "catalog_hot",
            "resource_detail",
            "recommendation_feed",
            "microdesign_posts",
            "microdesign_poster",
            "agent_structured_attachments",
            "agent_model_select",
            "chat_history_persistence",
            "asset_uploads",
            "interactive_cards",
            "news_feed",
            "play_descriptor",
        ],
    }
    return json.dumps(payload, ensure_ascii=False)
