"""Bilibili raw proxy APIs."""
from __future__ import annotations

from fastapi import APIRouter, HTTPException, Query

from services.bili import (
    get_article_markdown,
    get_hot_videos,
    get_movie_videos,
    get_rank,
    get_up_info,
    get_up_videos,
    get_video_detail,
    get_video_related,
    get_weekly_hot,
    search_articles,
    search_up_users,
    search_videos,
)
from services.bili.client import BiliUnavailableError
from services.bili.models import BiliEnvelope

router = APIRouter(prefix="/api/bili", tags=["bilibili"])


def _handle_error(exc: Exception) -> HTTPException:
    if isinstance(exc, BiliUnavailableError):
        return HTTPException(status_code=503, detail=str(exc))
    return HTTPException(status_code=502, detail=f"B站 API 请求失败: {exc}")


@router.get("/videos/search", response_model=BiliEnvelope)
async def video_search(
    keyword: str = Query(min_length=1, max_length=100),
    order: str = "total",
    page: int = Query(1, ge=1),
    page_size: int = Query(12, ge=1, le=20),
) -> BiliEnvelope:
    try:
        return await search_videos(keyword, order=order, page=page, page_size=page_size)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/movie/videos", response_model=BiliEnvelope)
async def movie_videos(
    movie: str = Query(min_length=1, max_length=100),
    year: str = "",
    page: int = Query(1, ge=1),
    page_size: int = Query(12, ge=1, le=20),
) -> BiliEnvelope:
    try:
        return await get_movie_videos(movie, year=year, page=page, page_size=page_size)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/video/{bvid}", response_model=BiliEnvelope)
async def video_detail(bvid: str) -> BiliEnvelope:
    try:
        return await get_video_detail(bvid)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/video/{bvid}/related", response_model=BiliEnvelope)
async def video_related(
    bvid: str,
    page: int = Query(1, ge=1),
    page_size: int = Query(12, ge=1, le=20),
) -> BiliEnvelope:
    try:
        return await get_video_related(bvid, page=page, page_size=page_size)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/articles/search", response_model=BiliEnvelope)
async def article_search(
    keyword: str = Query(min_length=1, max_length=100),
    order: str = "total",
    page: int = Query(1, ge=1),
    page_size: int = Query(12, ge=1, le=20),
) -> BiliEnvelope:
    try:
        return await search_articles(keyword, order=order, page=page, page_size=page_size)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/article/{cvid}/markdown", response_model=BiliEnvelope)
async def article_markdown(cvid: int) -> BiliEnvelope:
    try:
        return await get_article_markdown(cvid)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/up/search", response_model=BiliEnvelope)
async def up_search(
    keyword: str = Query(min_length=1, max_length=100),
    order: str = "fans",
    page: int = Query(1, ge=1),
    page_size: int = Query(12, ge=1, le=20),
) -> BiliEnvelope:
    try:
        return await search_up_users(keyword, order=order, page=page, page_size=page_size)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/up/{mid}", response_model=BiliEnvelope)
async def up_info(mid: int) -> BiliEnvelope:
    try:
        return await get_up_info(mid)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/up/{mid}/videos", response_model=BiliEnvelope)
async def up_videos(
    mid: int,
    page: int = Query(1, ge=1),
    page_size: int = Query(12, ge=1, le=20),
    order: str = "pubdate",
) -> BiliEnvelope:
    try:
        return await get_up_videos(mid, page=page, page_size=page_size, order=order)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/rank", response_model=BiliEnvelope)
async def rank(type: str = "cinephile") -> BiliEnvelope:  # noqa: A002
    try:
        return await get_rank(type)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/hot", response_model=BiliEnvelope)
async def hot(
    page: int = Query(1, ge=1),
    page_size: int = Query(12, ge=1, le=20),
) -> BiliEnvelope:
    try:
        return await get_hot_videos(page=page, page_size=page_size)
    except Exception as exc:
        raise _handle_error(exc) from exc


@router.get("/hot/weekly", response_model=BiliEnvelope)
async def weekly_hot(week: int | None = Query(None, ge=1)) -> BiliEnvelope:
    try:
        return await get_weekly_hot(week=week)
    except Exception as exc:
        raise _handle_error(exc) from exc
