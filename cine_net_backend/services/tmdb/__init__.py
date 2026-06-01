"""成员 B：TMDB 客户端骨架。

封装影视数据采集（搜索 / 详情 / 热门 / Top Rated），统一中文 language=zh-CN。
真实实现用 httpx 异步调用，并把 poster_path 拼成完整 URL（settings.tmdb_image_base）。
"""
from __future__ import annotations

import httpx

from config import settings


class TMDBClient:
    def __init__(self) -> None:
        self._base = settings.tmdb_base_url
        self._key = settings.tmdb_api_key

    async def _get(self, path: str, **params) -> dict:
        params.update(api_key=self._key, language="zh-CN")
        async with httpx.AsyncClient(timeout=10) as client:
            r = await client.get(f"{self._base}{path}", params=params)
            r.raise_for_status()
            return r.json()

    async def search(self, query: str) -> dict:
        """TODO(B): /search/movie。"""
        return await self._get("/search/movie", query=query)

    async def detail(self, movie_id: int) -> dict:
        """TODO(B): /movie/{id}?append_to_response=credits。"""
        return await self._get(f"/movie/{movie_id}", append_to_response="credits")

    async def discover(self, genre_id: int | None = None) -> dict:
        """TODO(B): /discover/movie 按类型/评分发现候选。"""
        return await self._get("/discover/movie", with_genres=genre_id or "")
