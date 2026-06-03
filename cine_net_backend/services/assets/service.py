"""上传资产存储。"""
from __future__ import annotations

import base64
import mimetypes
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4

from fastapi import UploadFile

from config import settings
from db import get_conn, init_db

from .models import AssetRecord

_READY = False


def _ensure_db() -> None:
    global _READY
    if not _READY:
        init_db()
        _READY = True


def _now() -> str:
    return datetime.now(timezone.utc).isoformat()


def _kind(mime: str) -> str:
    if mime.startswith("image/"):
        return "image"
    if mime.startswith("video/"):
        return "video"
    if mime in {"application/pdf", "text/plain"} or mime.startswith("text/"):
        return "document"
    return "file"


def _asset_url(asset_id: str) -> str:
    base = settings.asset_public_base_url.rstrip("/")
    return f"{base}/api/assets/{asset_id}" if base else f"/api/assets/{asset_id}"


def _record_from_row(row) -> AssetRecord:
    return AssetRecord(
        id=row["id"],
        kind=row["kind"],
        filename=row["filename"],
        stored_name=row["stored_name"],
        mime=row["mime"],
        size=row["size"],
        created_at=row["created_at"],
        url=_asset_url(row["id"]),
    )


async def save_upload(file: UploadFile) -> AssetRecord:
    _ensure_db()
    content = await file.read()
    if len(content) > settings.asset_max_bytes:
        raise ValueError(f"文件超过限制：最大 {settings.asset_max_bytes} bytes")
    filename = Path(file.filename or "upload.bin").name
    mime = file.content_type or mimetypes.guess_type(filename)[0] or "application/octet-stream"
    asset_id = uuid4().hex
    suffix = Path(filename).suffix[:16]
    stored_name = f"{asset_id}{suffix}"
    settings.asset_dir.mkdir(parents=True, exist_ok=True)
    target = settings.asset_dir / stored_name
    target.write_bytes(content)
    record = {
        "id": asset_id,
        "kind": _kind(mime),
        "filename": filename,
        "stored_name": stored_name,
        "mime": mime,
        "size": len(content),
        "created_at": _now(),
    }
    with get_conn() as conn:
        conn.execute(
            """
            INSERT INTO assets(id, kind, filename, stored_name, mime, size, created_at)
            VALUES(:id, :kind, :filename, :stored_name, :mime, :size, :created_at)
            """,
            record,
        )
    return AssetRecord(**record, url=_asset_url(asset_id))


def get_asset(asset_id: str) -> AssetRecord:
    _ensure_db()
    with get_conn() as conn:
        row = conn.execute("SELECT * FROM assets WHERE id = ?", (asset_id,)).fetchone()
    if row is None:
        raise LookupError(f"未知资产: {asset_id}")
    return _record_from_row(row)


def asset_path(record: AssetRecord) -> Path:
    target = settings.asset_dir / record.stored_name
    if not target.exists():
        raise LookupError(f"资产文件不存在: {record.id}")
    return target


def asset_data_url(record: AssetRecord) -> str:
    target = asset_path(record)
    encoded = base64.b64encode(target.read_bytes()).decode("ascii")
    return f"data:{record.mime};base64,{encoded}"
