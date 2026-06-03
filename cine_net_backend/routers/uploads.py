"""上传资产 API。"""
from fastapi import APIRouter, HTTPException, UploadFile
from fastapi.responses import FileResponse

from services.assets import asset_path, get_asset, save_upload
from services.assets.models import AssetRecord

router = APIRouter(prefix="/api", tags=["assets"])


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
