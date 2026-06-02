"""豆瓣非官方公开页面 Provider。用于中文影视发现、评分与海报。"""
from __future__ import annotations

import re
from typing import Any
from urllib.parse import quote

import httpx

from .models import CatalogMovie, CatalogProviderConfig, CatalogSourceRef

_YEAR_RE = re.compile(r"(\d{4})")


class DoubanCatalogProvider:
    """封装 MoonTV 使用的豆瓣近期热门与分类搜索入口。"""

    def __init__(self, config: CatalogProviderConfig, *, timeout_seconds: float) -> None:
        self.config = config
        self.timeout_seconds = timeout_seconds
        self._headers = {
            "User-Agent": (
                "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
                "AppleWebKit/537.36 Chrome/121.0.0.0 Safari/537.36"
            ),
            "Referer": "https://movie.douban.com/",
            "Accept": "application/json, text/plain, */*",
        }

    @property
    def configured(self) -> bool:
        return True

    async def _get(self, url: str) -> dict[str, Any]:
        async with httpx.AsyncClient(
            timeout=self.timeout_seconds,
            follow_redirects=True,
            headers=self._headers,
        ) as client:
            response = await client.get(url)
            response.raise_for_status()
            payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("豆瓣返回值不是 JSON object")
        return payload

    def _movie(
        self,
        raw: dict[str, Any],
        *,
        media_kind: str,
    ) -> CatalogMovie:
        picture = raw.get("pic") if isinstance(raw.get("pic"), dict) else {}
        rating = raw.get("rating") if isinstance(raw.get("rating"), dict) else {}
        subtitle = str(raw.get("card_subtitle") or "")
        source_id = str(raw.get("id") or "")
        raw_rating = rating.get("value", raw.get("rate"))
        return CatalogMovie(
            catalog_id=f"douban:{source_id}",
            provider_id=self.config.id,
            provider_name=self.config.name,
            source_id=source_id,
            title=str(raw.get("title") or "").strip(),
            year=(_YEAR_RE.search(subtitle).group(1) if _YEAR_RE.search(subtitle) else ""),
            media_kind=media_kind if media_kind in {"movie", "tv", "show"} else "unknown",
            rating=float(raw_rating) if raw_rating not in (None, "") else None,
            poster_url=str(raw.get("cover") or picture.get("normal") or picture.get("large") or ""),
            source_url=f"https://movie.douban.com/subject/{source_id}/",
            sources=[
                CatalogSourceRef(
                    provider_id=self.config.id,
                    provider_name=self.config.name,
                    source_id=source_id,
                    source_url=f"https://movie.douban.com/subject/{source_id}/",
                )
            ],
        )

    async def hot(self, *, media_kind: str = "movie", limit: int = 20) -> list[CatalogMovie]:
        if media_kind == "movie":
            kind, category, type_name = "movie", "热门", "全部"
        elif media_kind == "show":
            kind, category, type_name = "tv", "show", "show"
        else:
            kind, category, type_name = "tv", "tv", "tv"
        url = (
            "https://m.douban.com/rexxar/api/v2/subject/recent_hot/"
            f"{kind}?start=0&limit={limit}&category={quote(category)}&type={quote(type_name)}"
        )
        payload = await self._get(url)
        raw_items = payload.get("items")
        return [
            self._movie(item, media_kind=media_kind)
            for item in raw_items or []
            if isinstance(item, dict) and item.get("id") and item.get("title")
        ][:limit]

    async def search(
        self,
        query: str,
        *,
        media_kind: str = "movie",
        limit: int = 20,
    ) -> list[CatalogMovie]:
        type_name = "movie" if media_kind == "movie" else "tv"
        url = (
            "https://movie.douban.com/j/search_subjects"
            f"?type={type_name}&tag={quote(query)}&sort=recommend&page_limit={limit}&page_start=0"
        )
        payload = await self._get(url)
        raw_items = payload.get("subjects") or payload.get("items") or []
        return [
            self._movie(item, media_kind=media_kind)
            for item in raw_items
            if isinstance(item, dict) and item.get("id") and item.get("title")
        ][:limit]
