"""TMDB 匹配 + 缓存 + 分组视图。

刮削只在 POST /api/library/scan 时发生（带并发上限）；GET /api/library 永远
只读缓存拼视图，不打 TMDB。缓存按 相对路径+mtime+size 失效，落
data/library_cache.json。匹配失败的文件进 unmatched 分组，照常可播。
"""
from __future__ import annotations

import asyncio
import json
from pathlib import Path
from typing import Any
from urllib.parse import quote

from config import settings
from services.library.scanner import ScannedFile, scan_library
from services.tmdb.client import TMDBHTTPClient

_DATA_DIR = Path(__file__).resolve().parents[2] / "data"
_CACHE_FILE = _DATA_DIR / "library_cache.json"
_MATCH_CONCURRENCY = 4


# ── 缓存 ────────────────────────────────────────────────────


def load_cache() -> dict[str, Any]:
    try:
        data = json.loads(_CACHE_FILE.read_text("utf-8"))
        if isinstance(data, dict) and isinstance(data.get("entries"), dict):
            return data
    except (OSError, json.JSONDecodeError):
        pass
    return {"version": 1, "entries": {}}


def save_cache(cache: dict[str, Any]) -> None:
    _DATA_DIR.mkdir(parents=True, exist_ok=True)
    _CACHE_FILE.write_text(
        json.dumps(cache, ensure_ascii=False, indent=1), "utf-8"
    )


def _cache_valid(entry: dict[str, Any] | None, file: ScannedFile) -> bool:
    return (
        entry is not None
        and entry.get("mtime") == file.mtime
        and entry.get("size") == file.size
    )


# ── TMDB 匹配 ───────────────────────────────────────────────


def _poster_url(poster_path: str | None) -> str:
    if not poster_path:
        return ""
    return f"{settings.tmdb_image_base.rstrip('/')}{poster_path}"


async def _search_tmdb(client: TMDBHTTPClient, kind: str, parsed_title: str, year: int | None) -> dict[str, Any] | None:
    """kind: movie / tv。取第一条结果。"""
    params: dict[str, Any] = {"query": quote(parsed_title)}
    if year and kind == "movie":
        params["year"] = year
    if year and kind == "tv":
        params["first_air_date_year"] = year
    try:
        payload = await client.request(f"/search/{kind}", params=params)
    except Exception:  # noqa: BLE001 —— 网络/代理问题不让单文件失败拖垮整轮扫描
        return None
    results = payload.get("results") or []
    if not results:
        return None
    top = results[0]
    return {
        "kind": kind,
        "tmdb_id": top.get("id"),
        "title": top.get("title") or top.get("name") or parsed_title,
        "year": (top.get("release_date") or top.get("first_air_date") or "")[:4],
        "poster": _poster_url(top.get("poster_path")),
        "overview": top.get("overview") or "",
        "vote": top.get("vote_average") or 0,
    }


async def match_file(client: TMDBHTTPClient, file: ScannedFile) -> dict[str, Any] | None:
    parsed = file.parsed
    if not parsed.title:
        return None
    # 有集数 → 先当剧集搜，搜不到退回电影；反之亦然
    order = ["tv", "movie"] if parsed.episode is not None else ["movie", "tv"]
    for kind in order:
        match = await _search_tmdb(client, kind, parsed.title, parsed.year)
        if match:
            match["season"] = parsed.season
            match["episode"] = parsed.episode
            return match
    return None


async def refresh_library(force: bool = False) -> dict[str, Any]:
    """扫盘 → 对新/变更文件做 TMDB 匹配 → 存缓存 → 返回分组视图。

    force=True 时连历史匹配失败的文件也重试（之前断网/没配 Key 的场景）。
    """
    files = scan_library()
    cache = load_cache()
    entries: dict[str, Any] = cache["entries"]

    pending: list[ScannedFile] = []
    for file in files:
        entry = entries.get(file.relative_path)
        if not _cache_valid(entry, file):
            pending.append(file)
        elif force and entry.get("match") is None:
            pending.append(file)

    if pending:
        client = TMDBHTTPClient()
        semaphore = asyncio.Semaphore(_MATCH_CONCURRENCY)

        async def worker(file: ScannedFile) -> None:
            async with semaphore:
                match = await match_file(client, file)
            entries[file.relative_path] = {
                "mtime": file.mtime,
                "size": file.size,
                "parsed": file.parsed.to_dict(),
                "match": match,
            }

        await asyncio.gather(*(worker(file) for file in pending))

    # 已删除的文件踢出缓存
    alive = {file.relative_path for file in files}
    for key in list(entries.keys()):
        if key not in alive:
            del entries[key]

    save_cache(cache)
    return build_view(files, cache)


def build_view(files: list[ScannedFile] | None = None, cache: dict[str, Any] | None = None) -> dict[str, Any]:
    """缓存 → {movies, shows, unmatched} 分组视图。不打 TMDB。"""
    files = files if files is not None else scan_library()
    cache = cache if cache is not None else load_cache()
    entries = cache["entries"]

    movies: list[dict[str, Any]] = []
    shows: dict[Any, dict[str, Any]] = {}
    unmatched: list[dict[str, Any]] = []

    for file in files:
        info = file.file_info()
        entry = entries.get(file.relative_path)
        match = entry.get("match") if _cache_valid(entry, file) else None
        if not match:
            parsed = (entry or {}).get("parsed") or file.parsed.to_dict()
            unmatched.append({**info, "parsed_title": parsed.get("title", "")})
            continue

        proxy_poster = (
            f"/api/proxy/image?url={quote(match['poster'], safe='')}"
            if match.get("poster")
            else ""
        )
        meta = {
            "tmdb_id": match.get("tmdb_id"),
            "title": match.get("title", ""),
            "year": match.get("year", ""),
            "poster": match.get("poster", ""),
            "poster_proxy": proxy_poster,
            "overview": match.get("overview", ""),
            "vote": match.get("vote", 0),
        }

        if match.get("kind") == "tv":
            group = shows.setdefault(
                match.get("tmdb_id") or match.get("title"),
                {**meta, "episodes": []},
            )
            episode_no = match.get("episode")
            group["episodes"].append(
                {
                    **info,
                    "season": match.get("season"),
                    "episode": episode_no,
                    "episode_label": f"第{episode_no}集" if episode_no else file.filename,
                }
            )
        else:
            movies.append({**meta, **info})

    for group in shows.values():
        group["episodes"].sort(
            key=lambda e: (e.get("season") or 0, e.get("episode") or 0)
        )

    return {
        "movies": sorted(movies, key=lambda m: m.get("title", "")),
        "shows": sorted(shows.values(), key=lambda s: s.get("title", "")),
        "unmatched": unmatched,
        "total": len(files),
    }
