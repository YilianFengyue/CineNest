"""影视资源聚合 API。"""
from fastapi import APIRouter, HTTPException, Query

from services.resources import get_resource_aggregator
from services.resources.models import MediaResourceDetail, ProviderHealth, ResourceSearchResponse

router = APIRouter(prefix="/api/resources", tags=["resources"])


@router.get("/providers", response_model=list[ProviderHealth])
async def list_providers(probe: bool = False) -> list[ProviderHealth]:
    """列出 Provider；`probe=true` 时实际联网健康检查。"""

    return await get_resource_aggregator().health(probe=probe)


@router.get("/search", response_model=ResourceSearchResponse)
async def search_resources(
    keyword: str = Query(min_length=1, max_length=100),
) -> ResourceSearchResponse:
    """并发搜索所有启用的 MacCMS Provider。"""

    return await get_resource_aggregator().search(keyword)


@router.get("/{provider_id}/{remote_id}", response_model=MediaResourceDetail)
async def get_resource_detail(provider_id: str, remote_id: str) -> MediaResourceDetail:
    """解析单个 Provider 条目的播放线路。"""

    try:
        return await get_resource_aggregator().detail(provider_id, remote_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"资源站解析失败: {exc}") from exc
