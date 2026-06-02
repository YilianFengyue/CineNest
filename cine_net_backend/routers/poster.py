"""MicroDesign 动态海报 API。"""
from fastapi import APIRouter, HTTPException

from services.microdesign import compose_poster
from services.microdesign.models import PosterSpec
from services.resources import get_resource_aggregator

router = APIRouter(prefix="/api", tags=["poster"])


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
