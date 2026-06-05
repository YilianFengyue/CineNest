"""TMDB 官方 Catalog Provider。"""
from __future__ import annotations

from typing import Any

import httpx

from config import settings

from .models import CatalogMovie, CatalogProviderConfig, CatalogSourceRef


def _auth_headers_and_params(
    *,
    read_access_token: str,
    api_key: str,
) -> tuple[dict[str, str], dict[str, str]]:
    headers = {"Accept": "application/json"}
    query: dict[str, str] = {}
    token = read_access_token.strip()
    key = api_key.strip()
    # 合并 .env 时常把 TMDB Read Access Token 误放进 TMDB_API_KEY；
    # JWT/read token 必须走 Authorization，32 位 v3 key 才能作为 api_key 参数。
    if token or key.startswith("eyJ"):
        headers["Authorization"] = f"Bearer {token or key}"
    else:
        query["api_key"] = key
    return headers, query


class TMDBCatalogProvider:
    """封装 TMDB 搜索、热门和详情 API。"""

    def __init__(self, config: CatalogProviderConfig, *, timeout_seconds: float) -> None:
        self.config = config
        self.timeout_seconds = timeout_seconds

    @property
    def configured(self) -> bool:
        return bool(settings.tmdb_read_access_token.strip() or settings.tmdb_api_key.strip())

    async def _get(self, path: str, params: dict[str, Any] | None = None) -> dict[str, Any]:
        if not self.configured:
            raise RuntimeError("TMDB 尚未配置：请填写 TMDB_READ_ACCESS_TOKEN 或 TMDB_API_KEY")
        headers, auth_query = _auth_headers_and_params(
            read_access_token=settings.tmdb_read_access_token,
            api_key=settings.tmdb_api_key,
        )
        query = {"language": "zh-CN", **auth_query, **(params or {})}
        async with httpx.AsyncClient(
            timeout=self.timeout_seconds,
            follow_redirects=True,
            headers=headers,
        ) as client:
            response = await client.get(f"{settings.tmdb_base_url.rstrip('/')}{path}", params=query)
            response.raise_for_status()
            payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("TMDB 返回值不是 JSON object")
        return payload

    @staticmethod
    def _year(raw_date: Any) -> str:
        value = str(raw_date or "")
        return value[:4] if len(value) >= 4 else ""

    @staticmethod
    def _image(base_url: str, path: Any) -> str:
        return f"{base_url.rstrip('/')}{path}" if path else ""

    def _movie(
        self,
        raw: dict[str, Any],
        *,
        media_kind: str,
        genres: list[str] | None = None,
        overview: str | None = None,
    ) -> CatalogMovie:
        source_id = str(raw.get("id") or "")
        title = str(raw.get("title") or raw.get("name") or "").strip()
        release_date = raw.get("release_date") or raw.get("first_air_date")
        return CatalogMovie(
            catalog_id=f"tmdb:{source_id}",
            provider_id=self.config.id,
            provider_name=self.config.name,
            source_id=source_id,
            title=title,
            original_title=str(raw.get("original_title") or raw.get("original_name") or ""),
            year=self._year(release_date),
            media_kind=media_kind if media_kind in {"movie", "tv"} else "unknown",
            rating=float(raw["vote_average"]) if raw.get("vote_average") is not None else None,
            rating_count=int(raw["vote_count"]) if raw.get("vote_count") is not None else None,
            poster_url=self._image(settings.tmdb_image_base, raw.get("poster_path")),
            backdrop_url=self._image(settings.tmdb_backdrop_base, raw.get("backdrop_path")),
            overview=overview if overview is not None else str(raw.get("overview") or ""),
            genres=genres or [],
            source_url=f"https://www.themoviedb.org/{media_kind}/{source_id}",
            sources=[
                CatalogSourceRef(
                    provider_id=self.config.id,
                    provider_name=self.config.name,
                    source_id=source_id,
                    source_url=f"https://www.themoviedb.org/{media_kind}/{source_id}",
                )
            ],
        )

    async def hot(self, *, media_kind: str = "movie", limit: int = 20) -> list[CatalogMovie]:
        kind = "tv" if media_kind == "tv" else "movie"
        payload = await self._get(f"/{kind}/popular", {"page": 1})
        return [
            self._movie(item, media_kind=kind)
            for item in payload.get("results") or []
            if isinstance(item, dict) and item.get("id")
        ][:limit]

    async def search(
        self,
        query: str,
        *,
        media_kind: str = "movie",
        limit: int = 20,
    ) -> list[CatalogMovie]:
        kind = "tv" if media_kind == "tv" else "movie"
        payload = await self._get(f"/search/{kind}", {"query": query, "page": 1})
        return [
            self._movie(item, media_kind=kind)
            for item in payload.get("results") or []
            if isinstance(item, dict) and item.get("id")
        ][:limit]

    async def detail(self, source_id: str, *, media_kind: str = "movie") -> CatalogMovie:
        kind = "tv" if media_kind == "tv" else "movie"
        raw = await self._get(
            f"/{kind}/{source_id}",
            {"append_to_response": "credits,images,videos", "include_image_language": "zh,en,null"},
        )
        raw_genres = raw.get("genres") or []
        genres = [str(item.get("name")) for item in raw_genres if isinstance(item, dict) and item.get("name")]
        credits = raw.get("credits") or {}
        directors = [
            str(item.get("name"))
            for item in credits.get("crew") or []
            if isinstance(item, dict) and item.get("job") == "Director" and item.get("name")
        ]
        cast = [
            str(item.get("name"))
            for item in (credits.get("cast") or [])[:8]
            if isinstance(item, dict) and item.get("name")
        ]
        movie = self._movie(raw, media_kind=kind, genres=genres)
        return movie.model_copy(update={"directors": directors, "cast": cast})
