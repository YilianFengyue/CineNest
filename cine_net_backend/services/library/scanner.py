"""影视库扫盘 + 文件名解析。

把 "[SubGroup] 某番剧 - 03 [1080p][HEVC].mkv" / "某电影.2023.BluRay.x264.mkv" /
"Show.S01E02.WEB-DL.mp4" 这类文件名拆成 {title, year, season, episode}，
供 matcher 拿去 TMDB 搜索。解析失败不致命——文件会落到"未识别"分组照常可播。
"""
from __future__ import annotations

import datetime as dt
import re
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any

from services.local_videos import VIDEO_EXTENSIONS, encode_video_id, get_local_video_root

# 字幕组/来源等方括号标签整段去掉
_TAG_RE = re.compile(r"\[[^\]]*\]|【[^】]*】|\([^)]*\)")
_SEASON_EP_RE = re.compile(r"[Ss](\d{1,2})\s*[Ee](\d{1,3})")
_EPISODE_RES = [
    re.compile(r"第\s*(\d{1,4})\s*[集话話期]"),
    re.compile(r"\b[Ee][Pp]?\.?\s*(\d{1,3})\b"),
    re.compile(r"\s-\s*(\d{1,3})(?:\s|$|[vV]\d)"),
]
_YEAR_RE = re.compile(r"\b(19\d{2}|20\d{2})\b")
# 画质/编码/语言等噪声词，命中后该词及其右侧全部丢弃
_QUALITY_RE = re.compile(
    r"\b(2160p|1080p|720p|480p|4k|bluray|blu-ray|bdrip|webrip|web-dl|webdl|hdtv"
    r"|remux|dvdrip|x264|x265|h264|h265|hevc|avc|aac|flac|ddp?5?\.?1?|hdr10?|dv"
    r"|60fps|chs|cht|gb|big5|uncensored)\b.*$",
    re.IGNORECASE,
)


@dataclass
class ParsedName:
    title: str
    year: int | None = None
    season: int | None = None
    episode: int | None = None

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)


def _drop_match(text: str, start: int, end: int) -> str:
    """标题通常在匹配段左边；左边为空时（如"第3话 某动画"）取右边。"""
    prefix = text[:start].strip()
    return prefix if prefix else text[end:]


def parse_filename(stem: str) -> ParsedName:
    text = _TAG_RE.sub(" ", stem)
    text = text.replace("_", " ").replace(".", " ")

    season: int | None = None
    episode: int | None = None

    se = _SEASON_EP_RE.search(text)
    if se:
        season = int(se.group(1))
        episode = int(se.group(2))
        text = _drop_match(text, se.start(), se.end())
    else:
        for pattern in _EPISODE_RES:
            match = pattern.search(text)
            if match:
                episode = int(match.group(1))
                text = _drop_match(text, match.start(), match.end())
                break

    year: int | None = None
    year_match = _YEAR_RE.search(text)
    if year_match:
        year = int(year_match.group(1))
        text = text[: year_match.start()]
    else:
        # "(2010)" 这类年份在括号标签里、上面已被整段剔除，回原始名兜底找一次
        fallback = _YEAR_RE.search(stem)
        if fallback:
            year = int(fallback.group(1))

    text = _QUALITY_RE.sub(" ", text)
    title = re.sub(r"\s+", " ", text).strip(" -·~")
    if not title:
        title = re.sub(r"\s+", " ", _TAG_RE.sub(" ", stem)).strip()
    return ParsedName(title=title, year=year, season=season, episode=episode)


@dataclass
class ScannedFile:
    relative_path: str
    filename: str
    size: int
    mtime: float
    parsed: ParsedName

    @property
    def video_id(self) -> str:
        return encode_video_id(self.relative_path)

    def file_info(self) -> dict[str, Any]:
        return {
            "id": self.video_id,
            "filename": self.filename,
            "relative_path": self.relative_path,
            "size": self.size,
            "modified_at": dt.datetime.fromtimestamp(self.mtime).isoformat(
                timespec="seconds"
            ),
            "stream_url": f"/api/local-videos/stream/{self.video_id}",
        }


def scan_library(root: Path | None = None) -> list[ScannedFile]:
    base = root or get_local_video_root()
    result: list[ScannedFile] = []
    for path in sorted(base.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in VIDEO_EXTENSIONS:
            continue
        stat = path.stat()
        result.append(
            ScannedFile(
                relative_path=path.relative_to(base).as_posix(),
                filename=path.name,
                size=stat.st_size,
                mtime=stat.st_mtime,
                parsed=parse_filename(path.stem),
            )
        )
    return result
