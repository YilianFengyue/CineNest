"""统一播放解析 API。"""
from fastapi import APIRouter, HTTPException, Query

from services.play import resolve_play
from services.resources.models import PlayDescriptor

router = APIRouter(prefix="/api/play", tags=["play"])


@router.get("/resolve", response_model=PlayDescriptor)
async def resolve_play_api(
    provider_id: str = Query(min_length=1),
    remote_id: str = Query(min_length=1),
) -> PlayDescriptor:
    """把 provider_id/remote_id 解析成播放器可消费的统一播放描述。"""

    try:
        return await resolve_play(provider_id, remote_id)
    except KeyError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc
    except NotImplementedError as exc:
        raise HTTPException(status_code=501, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=502, detail=f"播放解析失败: {exc}") from exc
