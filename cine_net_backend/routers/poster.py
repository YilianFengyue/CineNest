"""MicroDesign 动态海报 API。"""
from fastapi import APIRouter, HTTPException

from services.microdesign import compose_poster
from services.microdesign.models import PosterSpec
from services.recommendation import get_recommendation_service
from services.resources import get_resource_aggregator

router = APIRouter(prefix="/api", tags=["poster"])


@router.get("/poster/catalog/{catalog_provider_id}/{catalog_source_id}", response_model=PosterSpec)
async def get_catalog_poster(
    catalog_provider_id: str,
    catalog_source_id: str,
    media_kind: str = "movie",
) -> PosterSpec:
    """从 Catalog 资料出发，补齐播放线路并生成动态海报 blocks。"""

    try:
        return await get_recommendation_service().poster(
            catalog_provider_id,
            catalog_source_id,
            media_kind=media_kind,
        )
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"Catalog 动态海报生成失败: {exc}") from exc


@router.get("/poster/{provider_id}/{remote_id}", response_model=PosterSpec)
async def get_poster(provider_id: str, remote_id: str) -> PosterSpec:
    """解析真实资源详情并返回 Flutter 可渲染的海报 blocks。"""

    try:
        detail = await get_resource_aggregator().detail(provider_id, remote_id)
        return compose_poster(detail)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"动态海报生成失败: {exc}") from exc
