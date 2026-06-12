"""影视库（带 TMDB 刮削的本地视频库）。

- GET  /api/library          只读缓存拼分组视图（movies/shows/unmatched），不打 TMDB
- POST /api/library/scan     扫盘 + 对新/变更文件 TMDB 匹配（?force=true 连失败的也重试）
- GET/POST /api/library/config  查看/修改库目录（运行期生效，存 data/library_config.json）

播放复用 /api/local-videos/stream/{id}（HTTP 206 Range），本模块只管元数据。
"""
from __future__ import annotations

from pathlib import Path

from fastapi import APIRouter, HTTPException, Query
from pydantic import BaseModel

from config import settings
from services.library.matcher import build_view, refresh_library
from services.local_videos import (
    get_configured_video_dir,
    get_local_video_root,
    set_configured_video_dir,
)

router = APIRouter(prefix="/api/library", tags=["library"])


@router.get("")
async def get_library() -> dict:
    view = build_view()
    view["root"] = str(get_local_video_root())
    return view


@router.post("/scan")
async def scan_library_endpoint(force: bool = Query(default=False)) -> dict:
    view = await refresh_library(force=force)
    view["root"] = str(get_local_video_root())
    return view


class LibraryConfig(BaseModel):
    dir: str


@router.get("/config")
async def get_config() -> dict:
    return {
        "dir": str(get_local_video_root()),
        "configured_dir": get_configured_video_dir(),
        "default_dir": settings.local_video_dir,
    }


@router.post("/config")
async def set_config(payload: LibraryConfig) -> dict:
    directory = payload.dir.strip()
    if not directory:
        raise HTTPException(status_code=400, detail="dir 不能为空")
    path = Path(directory).expanduser()
    if not path.is_dir():
        raise HTTPException(status_code=400, detail=f"目录不存在: {directory}")
    set_configured_video_dir(str(path.resolve()))
    return await get_config()
