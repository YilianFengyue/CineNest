from fastapi import APIRouter, HTTPException

from models import VideoSource
from services.video_engine import (
    bilibili_search as engine_bilibili_search,
    parse_source as engine_parse_source,
    search_sources as engine_search_sources,
)

router = APIRouter(prefix="/api", tags=["sources (member A)"])


@router.get("/sources/search", response_model=list[VideoSource])
async def search_sources(movie_name: str):
    """Search MacCMS providers and return a stable demo source as fallback."""
    return await engine_search_sources(movie_name)


@router.get("/sources/parse", response_model=VideoSource)
async def parse_source(source_id: str):
    """Parse a source id into a playable URL or a fallback web URL."""
    try:
        return await engine_parse_source(source_id)
    except ValueError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc


@router.get("/bilibili/search", response_model=list[VideoSource])
async def bilibili_search(keyword: str):
    """Search Bilibili and return WebView-friendly results."""
    return await engine_bilibili_search(keyword)
