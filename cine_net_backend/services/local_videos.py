from __future__ import annotations

import base64
import datetime as dt
import json
import mimetypes
from pathlib import Path

from fastapi import HTTPException

from config import settings
from models.schemas import LocalVideo


VIDEO_EXTENSIONS = {".mp4", ".mkv", ".mov", ".webm", ".m3u8", ".avi"}

# 影视库目录运行期可改（CineLink/手机端设置），覆盖 .env 的 LOCAL_VIDEO_DIR
_LIBRARY_CONFIG = Path(__file__).resolve().parents[1] / "data" / "library_config.json"


def get_configured_video_dir() -> str:
    try:
        data = json.loads(_LIBRARY_CONFIG.read_text("utf-8"))
        return str(data.get("dir") or "")
    except (OSError, json.JSONDecodeError):
        return ""


def set_configured_video_dir(directory: str) -> None:
    _LIBRARY_CONFIG.parent.mkdir(parents=True, exist_ok=True)
    _LIBRARY_CONFIG.write_text(
        json.dumps({"dir": directory}, ensure_ascii=False), "utf-8"
    )


def get_local_video_root() -> Path:
    configured = get_configured_video_dir()
    root = Path(configured or settings.local_video_dir).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)
    return root


def encode_video_id(relative_path: str) -> str:
    raw = relative_path.replace("\\", "/").encode("utf-8")
    return base64.urlsafe_b64encode(raw).decode("ascii").rstrip("=")


def decode_video_id(video_id: str) -> Path:
    try:
        padded = video_id + ("=" * (-len(video_id) % 4))
        relative = base64.urlsafe_b64decode(padded.encode("ascii")).decode("utf-8")
    except Exception as exc:  # noqa: BLE001
        raise HTTPException(status_code=400, detail="Invalid video id") from exc

    root = get_local_video_root()
    path = (root / relative).resolve()
    try:
        path.relative_to(root)
    except ValueError as exc:
        raise HTTPException(status_code=403, detail="Video path is outside LOCAL_VIDEO_DIR") from exc
    if not path.is_file() or path.suffix.lower() not in VIDEO_EXTENSIONS:
        raise HTTPException(status_code=404, detail="Video not found")
    return path


def list_local_videos() -> list[LocalVideo]:
    root = get_local_video_root()
    videos: list[LocalVideo] = []
    for path in sorted(root.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in VIDEO_EXTENSIONS:
            continue
        relative = path.relative_to(root).as_posix()
        stat = path.stat()
        videos.append(
            LocalVideo(
                id=encode_video_id(relative),
                title=path.stem,
                filename=path.name,
                relative_path=relative,
                size=stat.st_size,
                modified_at=dt.datetime.fromtimestamp(stat.st_mtime).isoformat(timespec="seconds"),
                stream_url=f"/api/local-videos/stream/{encode_video_id(relative)}",
            )
        )
    return videos


def guess_video_mime(path: Path) -> str:
    if path.suffix.lower() == ".m3u8":
        return "application/vnd.apple.mpegurl"
    return mimetypes.guess_type(path.name)[0] or "application/octet-stream"


def iter_file_range(path: Path, start: int, end: int, chunk_size: int = 1024 * 1024):
    with path.open("rb") as file:
        file.seek(start)
        remaining = end - start + 1
        while remaining > 0:
            chunk = file.read(min(chunk_size, remaining))
            if not chunk:
                break
            remaining -= len(chunk)
            yield chunk
