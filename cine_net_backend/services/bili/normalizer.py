"""Non-invasive helpers for Bilibili raw items.

The public page APIs keep Bilibili fields intact and only append `_cinenest`
for app routing and display conveniences.
"""
from __future__ import annotations

import datetime as _dt
import html
import re
from copy import deepcopy
from typing import Any

_TAG_RE = re.compile(r"<[^>]+>")


def clean_html_text(value: Any) -> str:
    text = "" if value is None else str(value)
    return html.unescape(_TAG_RE.sub("", text)).strip()


def fix_url(value: Any) -> str:
    url = "" if value is None else str(value).strip()
    if url.startswith("//"):
        return f"https:{url}"
    if url.startswith("http://"):
        return "https://" + url.removeprefix("http://")
    return url


def video_web_url(item: dict[str, Any]) -> str:
    bvid = str(item.get("bvid") or "").strip()
    if bvid:
        return f"https://www.bilibili.com/video/{bvid}"
    return fix_url(item.get("arcurl") or item.get("url"))


def video_app_url(item: dict[str, Any]) -> str:
    bvid = str(item.get("bvid") or "").strip()
    if bvid:
        return f"bilibili://video/{bvid}"
    aid = item.get("aid") or item.get("id")
    return f"bilibili://video/{aid}" if aid else video_web_url(item)


def article_web_url(item: dict[str, Any] | int | str) -> str:
    cvid = item if isinstance(item, (int, str)) else item.get("id") or item.get("cvid")
    return f"https://www.bilibili.com/read/cv{cvid}" if cvid else ""


def article_app_url(item: dict[str, Any] | int | str) -> str:
    cvid = item if isinstance(item, (int, str)) else item.get("id") or item.get("cvid")
    return f"bilibili://article/{cvid}" if cvid else article_web_url(item)


def space_web_url(mid: Any) -> str:
    return f"https://space.bilibili.com/{mid}" if mid else ""


def space_app_url(mid: Any) -> str:
    return f"bilibili://space/{mid}" if mid else space_web_url(mid)


def duration_seconds(value: Any) -> int:
    if isinstance(value, int):
        return value
    parts = [part for part in str(value or "").split(":") if part.isdigit()]
    if not parts:
        return 0
    total = 0
    for part in parts:
        total = total * 60 + int(part)
    return total


def date_text(timestamp: Any) -> str:
    try:
        stamp = int(timestamp)
    except (TypeError, ValueError):
        return ""
    if stamp <= 0:
        return ""
    return _dt.datetime.fromtimestamp(stamp).strftime("%Y-%m-%d")


def score_video(item: dict[str, Any]) -> int:
    def number(name: str) -> int:
        try:
            return int(item.get(name) or 0)
        except (TypeError, ValueError):
            return 0

    danmaku = number("danmaku") or number("video_review")
    return number("play") + number("like") * 20 + number("favorites") * 30 + danmaku * 10


def with_video_extras(item: dict[str, Any]) -> dict[str, Any]:
    enriched = deepcopy(item)
    enriched["_cinenest"] = {
        "title_plain": clean_html_text(item.get("title")),
        "cover_url": fix_url(item.get("pic") or item.get("cover")),
        "web_url": video_web_url(item),
        "app_url": video_app_url(item),
        "fallback_url": video_web_url(item),
        "duration_seconds": duration_seconds(item.get("duration")),
        "pubdate_text": date_text(item.get("pubdate")),
        "score": score_video(item),
    }
    return enriched


def with_article_extras(item: dict[str, Any]) -> dict[str, Any]:
    enriched = deepcopy(item)
    enriched["_cinenest"] = {
        "title_plain": clean_html_text(item.get("title")),
        "cover_url": fix_url(item.get("pic") or item.get("image_urls") or item.get("cover")),
        "web_url": article_web_url(item),
        "app_url": article_app_url(item),
        "fallback_url": article_web_url(item),
    }
    return enriched


def with_user_extras(item: dict[str, Any]) -> dict[str, Any]:
    enriched = deepcopy(item)
    mid = item.get("mid") or item.get("id") or item.get("uid")
    enriched["_cinenest"] = {
        "name_plain": clean_html_text(item.get("uname") or item.get("name")),
        "face_url": fix_url(item.get("upic") or item.get("face")),
        "web_url": space_web_url(mid),
        "app_url": space_app_url(mid),
        "fallback_url": space_web_url(mid),
    }
    return enriched


def compact_video(item: dict[str, Any]) -> dict[str, Any]:
    extra = item.get("_cinenest") or {}
    return {
        "title": extra.get("title_plain") or clean_html_text(item.get("title")),
        "bvid": item.get("bvid") or "",
        "aid": item.get("aid") or item.get("id"),
        "author": item.get("author") or item.get("uname") or "",
        "mid": item.get("mid") or item.get("uid"),
        "url": extra.get("web_url") or video_web_url(item),
        "app_url": extra.get("app_url") or video_app_url(item),
        "cover": extra.get("cover_url") or fix_url(item.get("pic")),
        "play": item.get("play") or 0,
        "danmaku": item.get("danmaku") or item.get("video_review") or 0,
        "favorites": item.get("favorites") or 0,
        "duration": item.get("duration") or "",
        "description": clean_html_text(item.get("description")),
        "tag": item.get("tag") or item.get("tags") or "",
        "score": extra.get("score") or score_video(item),
    }
