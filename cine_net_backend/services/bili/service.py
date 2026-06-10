"""Raw-first Bilibili service layer for pages and Agent tools."""
from __future__ import annotations

import asyncio
from copy import deepcopy
from typing import Any

from .cache import get_cached, set_cached
from .client import bili_modules, guarded
from .models import BiliEnvelope
from .normalizer import (
    article_app_url,
    article_web_url,
    compact_video,
    score_video,
    with_article_extras,
    with_user_extras,
    with_video_extras,
)

SEARCH_TTL = 1800
MOVIE_TTL = 21600
DETAIL_TTL = 43200
HOT_TTL = 1800
MAX_PAGE_SIZE = 20


def _clamp_page(page: int) -> int:
    return max(1, int(page or 1))


def _clamp_page_size(page_size: int) -> int:
    return max(1, min(MAX_PAGE_SIZE, int(page_size or 12)))


def _cached_envelope(key: str) -> BiliEnvelope | None:
    value = get_cached(key)
    return BiliEnvelope.model_validate(value) if value is not None else None


def _store_envelope(key: str, envelope: BiliEnvelope, ttl: int) -> BiliEnvelope:
    set_cached(key, envelope.model_dump(), ttl)
    return envelope


def _search_order(order: str):
    search = bili_modules()["search"]
    mapping = {
        "total": search.OrderVideo.TOTALRANK,
        "click": search.OrderVideo.CLICK,
        "pubdate": search.OrderVideo.PUBDATE,
        "danmaku": search.OrderVideo.DM,
        "favorite": search.OrderVideo.STOW,
        "comment": search.OrderVideo.SCORES,
    }
    return mapping.get(order, search.OrderVideo.TOTALRANK)


def _article_order(order: str):
    search = bili_modules()["search"]
    mapping = {
        "total": search.OrderArticle.TOTALRANK,
        "click": search.OrderArticle.CLICK,
        "pubdate": search.OrderArticle.PUBDATE,
        "like": search.OrderArticle.LIKE,
        "comment": search.OrderArticle.SCORES,
    }
    return mapping.get(order, search.OrderArticle.TOTALRANK)


def _user_order(order: str):
    search = bili_modules()["search"]
    mapping = {
        "fans": search.OrderUser.FANS,
        "level": search.OrderUser.LEVEL,
    }
    return mapping.get(order, search.OrderUser.FANS)


def _rank_type(raw_type: str):
    rank = bili_modules()["rank"]
    mapping = {
        "cinephile": rank.RankType.Cinephile,
        "movie": rank.RankType.Movie,
        "tv": rank.RankType.TV,
        "documentary": rank.RankType.Documentary,
        "bangumi": rank.RankType.Bangumi,
        "variety": rank.RankType.Variety,
    }
    return mapping.get(raw_type, rank.RankType.Cinephile)


def _extract_list(raw: Any) -> list[dict[str, Any]]:
    if isinstance(raw, dict):
        for key in ("result", "data", "list", "archives", "items", "replies"):
            value = raw.get(key)
            if isinstance(value, list):
                return [dict(item) for item in value if isinstance(item, dict)]
        nested = raw.get("data")
        if isinstance(nested, dict):
            return _extract_list(nested)
    if isinstance(raw, list):
        return [dict(item) for item in raw if isinstance(item, dict)]
    return []


async def search_videos(keyword: str, order: str = "total", page: int = 1, page_size: int = 12) -> BiliEnvelope:
    page = _clamp_page(page)
    page_size = _clamp_page_size(page_size)
    key = f"bili:video-search:{keyword}:{order}:{page}:{page_size}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    search = bili_modules()["search"]
    raw = await guarded(
        search.search_by_type(
            keyword,
            search_type=search.SearchObjectType.VIDEO,
            order_type=_search_order(order),
            page=page,
            page_size=page_size,
        )
    )
    items = [with_video_extras(item) for item in _extract_list(raw)]
    envelope = BiliEnvelope(
        result_type="video",
        keyword=keyword,
        page=page,
        page_size=page_size,
        count=len(items),
        data=items,
        extra={"cached": False, "raw_keys": list(raw.keys()) if isinstance(raw, dict) else []},
    )
    return _store_envelope(key, envelope, SEARCH_TTL)


def _movie_keywords(movie: str, year: str = "") -> list[str]:
    suffixes = ["电影解说", "影评", "剧情解析", "混剪", "名场面", "预告", "幕后"]
    keywords = [f"{movie} {suffix}".strip() for suffix in suffixes]
    if year:
        keywords.insert(0, f"{movie} {year}")
    return keywords


async def get_movie_videos(movie: str, year: str = "", page: int = 1, page_size: int = 12) -> BiliEnvelope:
    page = _clamp_page(page)
    page_size = _clamp_page_size(page_size)
    key = f"bili:movie-videos:{movie}:{year}:{page}:{page_size}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    keywords = _movie_keywords(movie, year)
    per_query = min(8, page_size)
    results = await asyncio.gather(
        *(search_videos(keyword, page=1, page_size=per_query) for keyword in keywords),
        return_exceptions=True,
    )
    by_bvid: dict[str, dict[str, Any]] = {}
    for result in results:
        if isinstance(result, Exception):
            continue
        for item in result.data:
            if not isinstance(item, dict):
                continue
            key_id = str(item.get("bvid") or item.get("aid") or item.get("id") or "")
            if key_id and key_id not in by_bvid:
                by_bvid[key_id] = deepcopy(item)
    candidates = sorted(by_bvid.values(), key=score_video, reverse=True)
    start = (page - 1) * page_size
    page_items = candidates[start : start + page_size]
    envelope = BiliEnvelope(
        result_type="video",
        movie=movie,
        year=year,
        page=page,
        page_size=page_size,
        count=len(page_items),
        query_used=keywords,
        data=page_items,
        extra={
            "cached": False,
            "total_candidates": len(candidates),
            "has_more": start + page_size < len(candidates),
        },
    )
    return _store_envelope(key, envelope, MOVIE_TTL)


async def get_video_detail(bvid: str) -> BiliEnvelope:
    key = f"bili:video-detail:{bvid}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    video = bili_modules()["video"]
    instance = video.Video(bvid=bvid)
    info, pages, tags = await asyncio.gather(
        guarded(instance.get_info()),
        guarded(instance.get_pages()),
        guarded(instance.get_tags()),
        return_exceptions=True,
    )
    data = dict(info) if isinstance(info, dict) else {"bvid": bvid}
    if not isinstance(pages, Exception):
        data["pages"] = pages
    if not isinstance(tags, Exception):
        data["tags"] = tags
    data = with_video_extras(data)
    envelope = BiliEnvelope(result_type="video_detail", data=data, count=1, extra={"cached": False})
    return _store_envelope(key, envelope, DETAIL_TTL)


async def get_video_related(bvid: str, page: int = 1, page_size: int = 12) -> BiliEnvelope:
    page = _clamp_page(page)
    page_size = _clamp_page_size(page_size)
    key = f"bili:video-related:{bvid}:{page}:{page_size}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    video = bili_modules()["video"]
    raw = await guarded(video.Video(bvid=bvid).get_related())
    candidates = [with_video_extras(item) for item in _extract_list(raw)]
    start = (page - 1) * page_size
    items = candidates[start : start + page_size]
    envelope = BiliEnvelope(
        result_type="video",
        page=page,
        page_size=page_size,
        count=len(items),
        data=items,
        extra={"cached": False, "has_more": start + page_size < len(candidates)},
    )
    return _store_envelope(key, envelope, SEARCH_TTL)


async def search_articles(keyword: str, order: str = "total", page: int = 1, page_size: int = 12) -> BiliEnvelope:
    page = _clamp_page(page)
    page_size = _clamp_page_size(page_size)
    key = f"bili:article-search:{keyword}:{order}:{page}:{page_size}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    search = bili_modules()["search"]
    raw = await guarded(
        search.search_by_type(
            keyword,
            search_type=search.SearchObjectType.ARTICLE,
            order_type=_article_order(order),
            page=page,
            page_size=page_size,
        )
    )
    items = [with_article_extras(item) for item in _extract_list(raw)]
    envelope = BiliEnvelope(
        result_type="article",
        keyword=keyword,
        page=page,
        page_size=page_size,
        count=len(items),
        data=items,
        extra={"cached": False},
    )
    return _store_envelope(key, envelope, SEARCH_TTL)


async def get_article_markdown(cvid: int) -> BiliEnvelope:
    key = f"bili:article-markdown:{cvid}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    article = bili_modules()["article"]
    instance = article.Article(cvid)
    if await guarded(instance.is_note()):
        instance = instance.turn_to_note()
    await guarded(instance.fetch_content())
    data = {
        "source": "bilibili_article",
        "cvid": cvid,
        "url": article_web_url(cvid),
        "app_url": article_app_url(cvid),
        "markdown": instance.markdown(),
    }
    envelope = BiliEnvelope(result_type="article_markdown", data=data, count=1, extra={"cached": False})
    return _store_envelope(key, envelope, DETAIL_TTL)


async def search_up_users(keyword: str, order: str = "fans", page: int = 1, page_size: int = 12) -> BiliEnvelope:
    page = _clamp_page(page)
    page_size = _clamp_page_size(page_size)
    key = f"bili:user-search:{keyword}:{order}:{page}:{page_size}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    search = bili_modules()["search"]
    raw = await guarded(
        search.search_by_type(
            keyword,
            search_type=search.SearchObjectType.USER,
            order_type=_user_order(order),
            order_sort=0,
            page=page,
            page_size=page_size,
        )
    )
    items = [with_user_extras(item) for item in _extract_list(raw)]
    envelope = BiliEnvelope(
        result_type="user",
        keyword=keyword,
        page=page,
        page_size=page_size,
        count=len(items),
        data=items,
        extra={"cached": False},
    )
    return _store_envelope(key, envelope, SEARCH_TTL)


async def get_up_info(mid: int) -> BiliEnvelope:
    key = f"bili:up-info:{mid}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    user = bili_modules()["user"]
    instance = user.User(mid)
    info, stat = await asyncio.gather(
        guarded(instance.get_user_info()),
        guarded(instance.get_up_stat()),
        return_exceptions=True,
    )
    data = dict(info) if isinstance(info, dict) else {"mid": mid}
    if not isinstance(stat, Exception):
        data["stat"] = stat
    data = with_user_extras(data)
    envelope = BiliEnvelope(result_type="user_detail", data=data, count=1, extra={"cached": False})
    return _store_envelope(key, envelope, DETAIL_TTL)


async def get_up_videos(mid: int, page: int = 1, page_size: int = 12, order: str = "pubdate") -> BiliEnvelope:
    page = _clamp_page(page)
    page_size = _clamp_page_size(page_size)
    key = f"bili:up-videos:{mid}:{page}:{page_size}:{order}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    user = bili_modules()["user"]
    raw = await guarded(user.User(mid).get_videos(pn=page, ps=page_size, order=order))
    items = [with_video_extras(item) for item in _extract_list(raw)]
    envelope = BiliEnvelope(
        result_type="video",
        page=page,
        page_size=page_size,
        count=len(items),
        data=items,
        extra={"cached": False},
    )
    return _store_envelope(key, envelope, SEARCH_TTL)


async def get_rank(type_: str = "cinephile") -> BiliEnvelope:
    key = f"bili:rank:{type_}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    rank = bili_modules()["rank"]
    raw = await guarded(rank.get_rank(type_=_rank_type(type_)))
    items = [with_video_extras(item) for item in _extract_list(raw)]
    envelope = BiliEnvelope(result_type="rank", data=items or raw, count=len(items), extra={"cached": False})
    return _store_envelope(key, envelope, HOT_TTL)


async def get_hot_videos(page: int = 1, page_size: int = 12) -> BiliEnvelope:
    page = _clamp_page(page)
    page_size = _clamp_page_size(page_size)
    key = f"bili:hot:{page}:{page_size}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    hot = bili_modules()["hot"]
    raw = await guarded(hot.get_hot_videos(pn=page, ps=page_size))
    items = [with_video_extras(item) for item in _extract_list(raw)]
    envelope = BiliEnvelope(
        result_type="video",
        page=page,
        page_size=page_size,
        count=len(items),
        data=items,
        extra={"cached": False},
    )
    return _store_envelope(key, envelope, HOT_TTL)


async def get_weekly_hot(week: int | None = None) -> BiliEnvelope:
    key = f"bili:weekly:{week or 'latest'}"
    cached = _cached_envelope(key)
    if cached is not None:
        cached.extra["cached"] = True
        return cached

    hot = bili_modules()["hot"]
    if week is None:
        raw = await guarded(hot.get_weekly_hot_videos_list())
        result_type = "weekly_list"
        data = raw
        count = len(raw) if isinstance(raw, list) else 0
    else:
        raw = await guarded(hot.get_weekly_hot_videos(week=week))
        items = [with_video_extras(item) for item in _extract_list(raw)]
        result_type = "video"
        data = items
        count = len(items)
    envelope = BiliEnvelope(result_type=result_type, data=data, count=count, extra={"cached": False})
    return _store_envelope(key, envelope, HOT_TTL)


def compact_videos_for_agent(envelope: BiliEnvelope, limit: int = 8) -> list[dict[str, Any]]:
    if not isinstance(envelope.data, list):
        return []
    return [compact_video(item) for item in envelope.data[:limit] if isinstance(item, dict)]
