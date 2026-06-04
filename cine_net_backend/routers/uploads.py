"""上传资产 API。"""
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, HTTPException, Query, UploadFile
from fastapi.responses import FileResponse, Response

from services.assets import asset_path, get_asset, save_upload
from services.assets.models import AssetRecord

router = APIRouter(prefix="/api", tags=["assets"])

_IMAGE_PROXY_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36"
    ),
    "Referer": "https://movie.douban.com/",
    "Accept": "image/avif,image/webp,image/apng,image/svg+xml,image/*,*/*;q=0.8",
}


async def _download_remote_image(url: str) -> tuple[bytes, str]:
    parsed = urlparse(url)
    if parsed.scheme not in {"http", "https"} or not parsed.netloc:
        raise ValueError("只允许代理 http/https 图片 URL")
    async with httpx.AsyncClient(timeout=15, follow_redirects=True, headers=_IMAGE_PROXY_HEADERS) as client:
        response = await client.get(url)
        response.raise_for_status()
    content_type = response.headers.get("content-type") or "image/jpeg"
    if not content_type.startswith("image/"):
        raise ValueError(f"目标不是图片资源: {content_type}")
    return response.content, content_type


@router.post("/uploads", response_model=AssetRecord)
async def upload_asset(file: UploadFile) -> AssetRecord:
    """上传图片或文件。图片可进入多模态 Agent，文件先持久化预留 RAG。"""

    try:
        return await save_upload(file)
    except ValueError as exc:
        raise HTTPException(status_code=413, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"上传失败: {exc}") from exc


@router.get("/assets/{asset_id}")
async def read_asset(asset_id: str):
    """读取上传资产。"""

    try:
        record = get_asset(asset_id)
        return FileResponse(asset_path(record), media_type=record.mime, filename=record.filename)
    except LookupError as exc:
        raise HTTPException(status_code=404, detail=str(exc)) from exc


@router.get("/image-proxy")
async def image_proxy(url: str = Query(min_length=1)) -> Response:
    """代理豆瓣/资源站图片，缓解移动端直链防盗链或不可达导致的灰图。"""

    try:
        content, content_type = await _download_remote_image(url)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except httpx.HTTPStatusError as exc:
        raise HTTPException(status_code=exc.response.status_code, detail="远端图片请求失败") from exc
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=502, detail=f"图片代理失败: {exc}") from exc
    return Response(
        content=content,
        media_type=content_type,
        headers={"Cache-Control": "public, max-age=15720000, s-maxage=15720000"},
    )
