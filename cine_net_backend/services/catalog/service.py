"""影视资料 Catalog 聚合服务。"""
from __future__ import annotations

import asyncio
import re
from functools import lru_cache
from time import perf_counter

from config import settings

from .cache import TTLCache
from .models import (
    CatalogMovie,
    CatalogProviderHealth,
    CatalogSearchResponse,
    CatalogTrace,
)
from .registry import CatalogRegistry

_TITLE_RE = re.compile(r"[\s\-_:：·.，,。！!？?《》【】\[\]()（）]+")


def normalize_catalog_title(title: str) -> str:
    return _TITLE_RE.sub("", title).lower()


def _merge_movie(primary: CatalogMovie, candidate: CatalogMovie) -> CatalogMovie:
    """用第二资料源填补缺失字段，保留优先级更高的主来源。"""

    source_map = {source.provider_id: source for source in primary.sources}
    for source in candidate.sources:
        source_map.setdefault(source.provider_id, source)
    candidate_is_tmdb = candidate.provider_id == "tmdb"
    updates = {
        "original_title": primary.original_title or candidate.original_title,
        "year": primary.year or candidate.year,
        "rating": primary.rating if primary.rating is not None else candidate.rating,
        "rating_count": primary.rating_count if primary.rating_count is not None else candidate.rating_count,
        # 豆瓣图片容易 403/防盗链；只在 TMDB 缺失或未配置时使用豆瓣图。
        "poster_url": candidate.poster_url if candidate_is_tmdb and candidate.poster_url else primary.poster_url or candidate.poster_url,
        "backdrop_url": candidate.backdrop_url if candidate_is_tmdb and candidate.backdrop_url else primary.backdrop_url or candidate.backdrop_url,
        "overview": primary.overview or candidate.overview,
        "genres": primary.genres or candidate.genres,
        "directors": primary.directors or candidate.directors,
        "cast": primary.cast or candidate.cast,
        "sources": list(source_map.values()),
    }
    return primary.model_copy(update=updates)


class CatalogService:
    """聚合豆瓣与 TMDB；单源失败只进入 trace。"""

    def __init__(self, registry: CatalogRegistry | None = None) -> None:
        self.registry = registry or CatalogRegistry()
        self.cache = TTLCache(settings.catalog_cache_ttl_seconds)
        self._known_movies: dict[str, CatalogMovie] = {}

    def providers(self) -> list[CatalogProviderHealth]:
        return [
            CatalogProviderHealth(
                provider_id=provider.config.id,
                provider_name=provider.config.name,
                kind=provider.config.kind,
                enabled=provider.config.enabled,
                configured=provider.configured,
                priority=provider.config.priority,
            )
            for provider in self.registry.list_all()
        ]

    def _remember(self, movies: list[CatalogMovie]) -> None:
        """让合并后的资料可从任一来源 ID 重新进入。"""

        for movie in movies:
            self._known_movies[movie.catalog_id] = movie
            for source in movie.sources:
                self._known_movies[f"{source.provider_id}:{source.source_id}"] = movie

    async def _call_one(self, provider, operation: str, **kwargs) -> tuple[list[CatalogMovie], CatalogTrace]:
        started = perf_counter()
        try:
            movies = await getattr(provider, operation)(**kwargs)
            self._remember(movies)
            return movies, CatalogTrace(
                provider_id=provider.config.id,
                provider_name=provider.config.name,
                ok=True,
                elapsed_ms=int((perf_counter() - started) * 1000),
                result_count=len(movies),
            )
        except Exception as exc:
            return [], CatalogTrace(
                provider_id=provider.config.id,
                provider_name=provider.config.name,
                ok=False,
                elapsed_ms=int((perf_counter() - started) * 1000),
                error=f"{type(exc).__name__}: {exc}",
            )

    @staticmethod
    def _merge(
        results: list[tuple[list[CatalogMovie], CatalogTrace]],
        limit: int,
        *,
        query: str = "",
    ) -> CatalogSearchResponse:
        merged: list[CatalogMovie] = []
        traces: list[CatalogTrace] = []
        for movies, trace in results:
            traces.append(trace)
            for movie in movies:
                title_key = normalize_catalog_title(movie.title)
                matched_index = next(
                    (
                        index
                        for index, current in enumerate(merged)
                        if normalize_catalog_title(current.title) == title_key
                        and current.media_kind == movie.media_kind
                        and (not current.year or not movie.year or current.year == movie.year)
                    ),
                    None,
                )
                if matched_index is None:
                    merged.append(movie)
                else:
                    merged[matched_index] = _merge_movie(merged[matched_index], movie)
        query_key = normalize_catalog_title(query)
        merged.sort(
            key=lambda movie: (
                normalize_catalog_title(movie.title) != query_key,
                query_key not in normalize_catalog_title(movie.title),
                -(movie.rating or 0),
                movie.title,
            )
        )
        return CatalogSearchResponse(
            query="",
            items=merged[:limit],
            traces=traces,
        )

    async def hot(self, *, media_kind: str = "movie", limit: int = 20) -> CatalogSearchResponse:
        key = f"hot:{media_kind}:{limit}"
        cached = self.cache.get(key)
        if cached is not None:
            return cached
        results = await asyncio.gather(
            *(self._call_one(provider, "hot", media_kind=media_kind, limit=limit) for provider in self.registry.list_available())
        )
        response = self._merge(list(results), limit)
        response.query = "热门"
        self._remember(response.items)
        self.cache.set(key, response)
        return response

    async def search(
        self,
        query: str,
        *,
        media_kind: str = "movie",
        limit: int = 20,
    ) -> CatalogSearchResponse:
        query = query.strip()
        if not query:
            return CatalogSearchResponse(query="")
        key = f"search:{media_kind}:{limit}:{query}"
        cached = self.cache.get(key)
        if cached is not None:
            return cached
        results = await asyncio.gather(
            *(
                self._call_one(provider, "search", query=query, media_kind=media_kind, limit=limit)
                for provider in self.registry.list_available()
            )
        )
        response = self._merge(list(results), limit, query=query)
        response.query = query
        self._remember(response.items)
        self.cache.set(key, response)
        return response

    async def detail(self, provider_id: str, source_id: str, *, media_kind: str = "movie") -> CatalogMovie:
        provider = self.registry.get(provider_id)
        catalog_id = f"{provider_id}:{source_id}"
        if hasattr(provider, "detail"):
            movie = await provider.detail(source_id, media_kind=media_kind)
            self._known_movies[catalog_id] = movie
            return movie
        cached = self._known_movies.get(catalog_id)
        if cached is None:
            raise LookupError(f"{provider.config.name} 暂不支持独立详情查询，请先通过热门或搜索接口获取条目")
        return cached


@lru_cache(maxsize=1)
def get_catalog_service() -> CatalogService:
    return CatalogService()
