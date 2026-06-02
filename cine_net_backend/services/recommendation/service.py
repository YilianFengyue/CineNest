"""联合豆瓣/TMDB Catalog 与 MacCMS 播放资源生成推荐帖子。"""
from __future__ import annotations

import asyncio
from functools import lru_cache

from config import settings
from services.catalog import get_catalog_service
from services.catalog.cache import TTLCache
from services.catalog.models import CatalogMovie
from services.microdesign import compose_catalog_post, compose_catalog_poster
from services.resources import get_resource_aggregator
from services.resources.aggregator import normalize_title
from services.resources.models import AggregatedMediaItem, ResourceSearchResponse

from .models import RecommendationFeed


def find_best_resource(movie: CatalogMovie, response: ResourceSearchResponse) -> AggregatedMediaItem | None:
    """优先选择标题精确匹配；年份相符时优先级更高。"""

    title_key = normalize_title(movie.title)
    candidates = [item for item in response.items if normalize_title(item.title) == title_key]
    if not candidates:
        return None
    return sorted(
        candidates,
        key=lambda item: (
            item.year == movie.year and bool(movie.year),
            len(item.sources),
        ),
        reverse=True,
    )[0]


class RecommendationService:
    """把资料候选批量映射为可播放的 MicroDesign 帖子。"""

    def __init__(self) -> None:
        self.catalog = get_catalog_service()
        self.resources = get_resource_aggregator()
        self._semaphore = asyncio.Semaphore(5)
        self._feed_cache = TTLCache(settings.recommendation_cache_ttl_seconds)

    async def _to_post(self, movie: CatalogMovie):
        async with self._semaphore:
            response = await self.resources.search(movie.title)
        resource = find_best_resource(movie, response)
        if resource is None:
            return None
        return compose_catalog_post(movie, resource=resource)

    async def recommend(
        self,
        *,
        query: str = "",
        media_kind: str = "movie",
        limit: int = 5,
    ) -> RecommendationFeed:
        """按主题或热门目录获取候选，再确认真实可播放资源。"""

        cache_key = f"{media_kind}:{limit}:{query.strip() or '热门'}"
        cached = self._feed_cache.get(cache_key)
        if cached is not None:
            return cached
        candidate_limit = max(limit * 2, limit)
        catalog_response = (
            await self.catalog.search(query, media_kind=media_kind, limit=candidate_limit)
            if query.strip()
            else await self.catalog.hot(media_kind=media_kind, limit=candidate_limit)
        )
        posts = await asyncio.gather(*(self._to_post(movie) for movie in catalog_response.items))
        feed = RecommendationFeed(
            query=query or "热门",
            posts=[post for post in posts if post is not None][:limit],
            catalog_traces=catalog_response.traces,
        )
        self._feed_cache.set(cache_key, feed)
        return feed

    async def poster(self, provider_id: str, source_id: str, *, media_kind: str = "movie"):
        """根据 Catalog 条目补齐播放线路并生成动态海报。"""

        movie = await self.catalog.detail(provider_id, source_id, media_kind=media_kind)
        resources = await self.resources.search(movie.title)
        resource = find_best_resource(movie, resources)
        if resource is None or not resource.sources:
            raise LookupError(f"未找到《{movie.title}》的可播放资源")
        primary = resource.sources[0]
        detail = await self.resources.detail(primary.provider_id, primary.remote_id)
        return compose_catalog_poster(movie, detail)


@lru_cache(maxsize=1)
def get_recommendation_service() -> RecommendationService:
    return RecommendationService()
