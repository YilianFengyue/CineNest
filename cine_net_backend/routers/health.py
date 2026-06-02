"""后端健康检查。"""
from fastapi import APIRouter

from services.llm import is_llm_configured
from services.resources import get_resource_aggregator

router = APIRouter(prefix="/api", tags=["health"])


@router.get("/health")
async def health() -> dict:
    """返回无需联网即可核验的后端能力状态。"""

    aggregator = get_resource_aggregator()
    return {
        "status": "ok",
        "service": "CineNest Backend",
        "version": "1.0.0",
        "llm_configured": is_llm_configured(),
        "provider_count": len(aggregator.registry.list_all()),
        "enabled_provider_count": len(aggregator.registry.list_enabled()),
    }
