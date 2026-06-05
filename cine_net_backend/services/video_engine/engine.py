from __future__ import annotations

import asyncio
import json
import re
from dataclasses import dataclass
from html import unescape
from pathlib import Path
from typing import Any
from urllib.parse import quote, unquote, urlencode
from urllib.request import Request, urlopen

from models import VideoSource

DEMO_VIDEO_URL = "https://media.w3.org/2010/05/sintel/trailer.mp4"

_TIMEOUT_SECONDS = 6
_HEADERS = {
    "User-Agent": (
        "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36"
    ),
    "Accept": "application/json,text/plain,*/*",
}
_BLOCKED_KEYWORDS = (
    "\u798f\u5229",
    "\u4f26\u7406",
    "\u4f26\u7406\u7247",
    "\u5199\u771f",
    "\u5348\u591c",
    "\u6210\u4eba",
    "\u60c5\u8272",
    "\u6709\u7801",
    "\u65e0\u7801",
)
_PROVIDER_CONFIG = Path(__file__).with_name("providers.json")
_ALIASES = {
    "the shawshank redemption": ("\u8096\u7533\u514b\u7684\u6551\u8d4e",),
    "shawshank redemption": ("\u8096\u7533\u514b\u7684\u6551\u8d4e",),
    "interstellar": ("\u661f\u9645\u7a7f\u8d8a",),
    "inception": ("\u76d7\u68a6\u7a7a\u95f4",),
    "titanic": ("\u6cf0\u5766\u5c3c\u514b\u53f7",),
    "avatar": ("\u963f\u51e1\u8fbe",),
    "forrest gump": ("\u963f\u7518\u6b63\u4f20",),
    "the matrix": ("\u9ed1\u5ba2\u5e1d\u56fd",),
    "matrix": ("\u9ed1\u5ba2\u5e1d\u56fd",),
    "parasite": ("\u5bc4\u751f\u866b",),
    "spirited away": ("\u5343\u4e0e\u5343\u5bfb",),
}


@dataclass(frozen=True)
class MacCmsProvider:
    id: str
    name: str
    endpoint: str


_DEFAULT_PROVIDERS: tuple[MacCmsProvider, ...] = (
    MacCmsProvider(
        id="wujin",
        name="Wujin",
        endpoint="https://api.wujinapi.me/api.php/provide/vod",
    ),
    MacCmsProvider(
        id="heimuer",
        name="Heimuer",
        endpoint="https://json.heimuer.xyz/api.php/provide/vod",
    ),
    MacCmsProvider(
        id="zuid",
        name="Zuid",
        endpoint="https://api.zuidapi.com/api.php/provide/vod",
    ),
)
PROVIDERS: tuple[MacCmsProvider, ...] = ()
_PROVIDER_BY_ID = {provider.id: provider for provider in PROVIDERS}


def _config_text(value: Any) -> str:
    if value is None:
        return ""
    return str(value).strip()


def _load_providers() -> tuple[MacCmsProvider, ...]:
    try:
        raw = json.loads(_PROVIDER_CONFIG.read_text(encoding="utf-8"))
    except Exception:
        return _DEFAULT_PROVIDERS

    providers: list[MacCmsProvider] = []
    if not isinstance(raw, list):
        return _DEFAULT_PROVIDERS
    for item in raw:
        if not isinstance(item, dict) or item.get("enabled") is False:
            continue
        provider_id = _config_text(item.get("id"))
        name = _config_text(item.get("name"))
        endpoint = _config_text(item.get("endpoint"))
        if not provider_id or not name or not endpoint.startswith(("http://", "https://")):
            continue
        providers.append(MacCmsProvider(id=provider_id, name=name, endpoint=endpoint))
    return tuple(providers) or _DEFAULT_PROVIDERS


PROVIDERS = _load_providers()
_PROVIDER_BY_ID = {provider.id: provider for provider in PROVIDERS}


def _clean_text(value: Any) -> str:
    if value is None:
        return ""
    text = unescape(str(value))
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"\s+", " ", text).strip()


def _is_blocked(*values: str) -> bool:
    merged = " ".join(value.lower() for value in values if value)
    return any(word.lower() in merged for word in _BLOCKED_KEYWORDS)


def _quality_from_item(item: dict[str, Any]) -> str | None:
    remarks = _clean_text(item.get("vod_remarks"))
    if remarks:
        return remarks[:30]
    serial = _clean_text(item.get("vod_serial"))
    if serial:
        return serial[:30]
    return None


def _demo_source(keyword: str) -> VideoSource:
    encoded = quote(keyword or "demo")
    return VideoSource(
        id=f"demo:{encoded}",
        name=f"TEST ONLY - fixed demo video for {keyword or 'Demo'}",
        quality="720P fixed sample",
        type="netdisk",
    )


def _bili_fallback_source(keyword: str) -> VideoSource:
    search_keyword = keyword.strip() or "movie review"
    encoded = quote(search_keyword)
    return VideoSource(
        id=f"bili:{encoded}",
        name=f"{keyword or 'Movie'} - Bilibili search",
        quality="WebView",
        type="bilibili",
        cover="https://www.bilibili.com/favicon.ico",
        play_count=0,
        play_url=f"https://m.bilibili.com/search?keyword={encoded}",
    )


async def search_sources(movie_name: str) -> list[VideoSource]:
    keyword = movie_name.strip()
    if not keyword:
        return []

    keywords = _keyword_variants(keyword)
    tasks = [
        _search_provider(provider, search_keyword)
        for provider in PROVIDERS
        for search_keyword in keywords
    ]
    results = await asyncio.gather(*tasks, return_exceptions=True)

    sources: list[VideoSource] = []
    seen: set[str] = set()
    for result in results:
        if isinstance(result, Exception):
            continue
        for source in result:
            if source.id in seen:
                continue
            seen.add(source.id)
            sources.append(source)

    return sources[:24]


def _keyword_variants(keyword: str) -> list[str]:
    variants = [keyword]
    normalized = keyword.lower().strip()
    for alias in _ALIASES.get(normalized, ()):
        if alias not in variants:
            variants.append(alias)
    return variants


async def _search_provider(
    provider: MacCmsProvider,
    keyword: str,
) -> list[VideoSource]:
    payload = await _fetch_json(
        provider.endpoint,
        {"ac": "videolist", "wd": keyword, "pg": 1},
    )
    items = payload.get("list") if isinstance(payload, dict) else None
    if not isinstance(items, list):
        return []

    sources: list[VideoSource] = []
    for item in items:
        if not isinstance(item, dict):
            continue
        vod_id = item.get("vod_id")
        title = _clean_text(item.get("vod_name"))
        type_name = _clean_text(item.get("type_name"))
        if not vod_id or not title or _is_blocked(title, type_name):
            continue
        sources.append(
            VideoSource(
                id=f"maccms:{provider.id}:{vod_id}",
                name=f"{title} - {provider.name}",
                quality=_quality_from_item(item),
                type="web",
                cover=_clean_text(item.get("vod_pic")) or None,
            )
        )
    return sources[:8]


async def parse_source(source_id: str) -> VideoSource:
    source_id = source_id.strip()
    if not source_id:
        raise ValueError("source_id is required")

    if source_id.startswith("demo:"):
        keyword = unquote(source_id.removeprefix("demo:"))
        return VideoSource(
            id=source_id,
            name=f"TEST ONLY - fixed demo video for {keyword or 'Demo'}",
            quality="720P fixed sample",
            type="netdisk",
            play_url=DEMO_VIDEO_URL,
        )

    if source_id.startswith("bili:"):
        keyword = unquote(source_id.removeprefix("bili:"))
        if keyword.startswith("BV"):
            parsed = await _parse_bilibili_video(keyword)
            if parsed is not None:
                return parsed
        encoded = quote(keyword)
        return VideoSource(
            id=source_id,
            name=f"{keyword or 'Movie'} - Bilibili search",
            quality="WebView",
            type="bilibili",
            play_url=f"https://m.bilibili.com/search?keyword={encoded}",
        )

    parts = source_id.split(":", 2)
    if len(parts) != 3 or parts[0] != "maccms":
        raise ValueError("unknown source_id")

    provider = _PROVIDER_BY_ID.get(parts[1])
    if provider is None:
        raise ValueError("unknown provider")

    vod_id = parts[2]
    item = await _detail_item(provider, vod_id)
    title = _clean_text(item.get("vod_name")) or provider.name
    play_url = _pick_play_url(_clean_text(item.get("vod_play_url")))
    if not play_url:
        raise ValueError("no playable url found")

    return VideoSource(
        id=source_id,
        name=f"{title} - {provider.name}",
        quality=_quality_from_item(item) or _episode_title(item.get("vod_play_url")),
        type="web",
        play_url=play_url,
        cover=_clean_text(item.get("vod_pic")) or None,
    )


async def _detail_item(provider: MacCmsProvider, vod_id: str) -> dict[str, Any]:
    for ac in ("detail", "videolist"):
        payload = await _fetch_json(provider.endpoint, {"ac": ac, "ids": vod_id})
        items = payload.get("list") if isinstance(payload, dict) else None
        if isinstance(items, list) and items and isinstance(items[0], dict):
            return items[0]
    raise ValueError("source detail not found")


def _episode_title(raw: Any) -> str | None:
    text = _clean_text(raw)
    first = next((part for part in text.split("#") if "$" in part), "")
    title = first.split("$", 1)[0].strip()
    return title[:30] if title else None


def _pick_play_url(raw: str) -> str | None:
    if not raw:
        return None

    candidates: list[tuple[str, int]] = []
    for episode in raw.split("#"):
        if "$" not in episode:
            continue
        _, url = episode.split("$", 1)
        url = url.strip()
        if not url.startswith(("http://", "https://")):
            continue
        lower = url.lower()
        if ".m3u8" in lower:
            score = 3
        elif ".mp4" in lower:
            score = 2
        else:
            score = 1
        candidates.append((url, score))

    if not candidates:
        return None
    candidates.sort(key=lambda item: item[1], reverse=True)
    return candidates[0][0]


async def bilibili_search(keyword: str) -> list[VideoSource]:
    keyword = keyword.strip()
    if not keyword:
        return []

    fallback = _bili_fallback_source(keyword)
    params = {"search_type": "video", "keyword": keyword, "page": 1}
    try:
        payload = await _fetch_json(
            "https://api.bilibili.com/x/web-interface/search/type",
            params,
        )
    except Exception:
        return [fallback]

    data = payload.get("data") if isinstance(payload, dict) else None
    results = data.get("result") if isinstance(data, dict) else None
    if not isinstance(results, list):
        return [fallback]

    sources: list[VideoSource] = []
    for item in results[:8]:
        if not isinstance(item, dict):
            continue
        bvid = _clean_text(item.get("bvid"))
        title = _clean_text(item.get("title"))
        if not bvid or not title:
            continue
        pic = _clean_text(item.get("pic"))
        if pic.startswith("//"):
            pic = f"https:{pic}"
        sources.append(
            VideoSource(
                id=f"bili:{bvid}",
                name=title,
                quality="WebView",
                type="bilibili",
                play_url=f"https://m.bilibili.com/video/{bvid}",
                cover=pic or None,
                play_count=_safe_int(item.get("play")),
            )
        )

    if not sources:
        return [fallback]
    sources.append(fallback)
    return sources


async def _parse_bilibili_video(bvid: str) -> VideoSource | None:
    try:
        page_payload = await _fetch_json(
            "https://api.bilibili.com/x/player/pagelist",
            {"bvid": bvid},
        )
        page_data = page_payload.get("data") if isinstance(page_payload, dict) else None
        if not isinstance(page_data, list) or not page_data:
            return None
        first_page = page_data[0]
        if not isinstance(first_page, dict):
            return None
        cid = first_page.get("cid")
        title = _clean_text(first_page.get("part")) or bvid
        if not cid:
            return None

        play_payload = await _fetch_json(
            "https://api.bilibili.com/x/player/playurl",
            {
                "bvid": bvid,
                "cid": cid,
                "qn": 80,
                "fnval": 0,
                "fourk": 1,
            },
        )
        play_data = play_payload.get("data") if isinstance(play_payload, dict) else None
        durl = play_data.get("durl") if isinstance(play_data, dict) else None
        if not isinstance(durl, list) or not durl:
            return None
        play_url = _clean_text(durl[0].get("url") if isinstance(durl[0], dict) else None)
        if not play_url:
            return None
        return VideoSource(
            id=f"bili:{bvid}",
            name=f"{title} - Bilibili direct",
            quality="Bilibili direct",
            type="bilibili",
            play_url=play_url,
        )
    except Exception:
        return None


def _safe_int(value: Any) -> int | None:
    if isinstance(value, int):
        return value
    if isinstance(value, str):
        digits = re.sub(r"\D", "", value)
        return int(digits) if digits else None
    return None


async def _fetch_json(url: str, params: dict[str, Any]) -> Any:
    return await asyncio.to_thread(_fetch_json_sync, url, params)


def _fetch_json_sync(url: str, params: dict[str, Any]) -> Any:
    full_url = f"{url}?{urlencode(params)}"
    request = Request(full_url, headers=_HEADERS, method="GET")
    with urlopen(request, timeout=_TIMEOUT_SECONDS) as response:
        charset = response.headers.get_content_charset() or "utf-8"
        text = response.read().decode(charset, errors="replace")
    return json.loads(text)
