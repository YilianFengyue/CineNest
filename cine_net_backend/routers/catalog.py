"""影视资料 Catalog API。"""
from fastapi import APIRouter, HTTPException, Query

from services.catalog import get_catalog_service
from services.catalog.models import CatalogMovie, CatalogProviderHealth, CatalogSearchResponse

router = APIRouter(prefix="/api/catalog", tags=["catalog"])


@router.get("/providers", response_model=list[CatalogProviderHealth])
async def list_catalog_providers() -> list[CatalogProviderHealth]:
    """列出豆瓣、TMDB 等资料源的启用和配置状态。"""

    return get_catalog_service().providers()


@router.get("/hot", response_model=CatalogSearchResponse)
async def hot_catalog(
    media_kind: str = Query("movie", pattern="^(movie|tv|show)$"),
    limit: int = Query(20, ge=1, le=50),
) -> CatalogSearchResponse:
    """从启用资料源获取热门电影、剧集或综艺。"""

    return await get_catalog_service().hot(media_kind=media_kind, limit=limit)


@router.get("/search", response_model=CatalogSearchResponse)
async def search_catalog(
    query: str = Query(min_length=1, max_length=100),
    media_kind: str = Query("movie", pattern="^(movie|tv)$"),
    limit: int = Query(20, ge=1, le=50),
) -> CatalogSearchResponse:
    """跨豆瓣与 TMDB 查询影视资料。"""

    return await get_catalog_service().search(query, media_kind=media_kind, limit=limit)


@router.get("/{provider_id}/{source_id}", response_model=CatalogMovie)
async def catalog_detail(
    provider_id: str,
    source_id: str,
    media_kind: str = Query("movie", pattern="^(movie|tv)$"),
) -> CatalogMovie:
    """获取资料详情。TMDB 可直接查；豆瓣条目需先经过热门或搜索接口进入缓存。"""

    try:
        return await get_catalog_service().detail(provider_id, source_id, media_kind=media_kind)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Catalog 详情查询失败: {exc}") from exc
