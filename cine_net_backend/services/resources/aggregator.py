"""多资源站并发聚合服务。"""
from __future__ import annotations

import asyncio
import re
from functools import lru_cache
from time import perf_counter

from config import settings

from .models import (
    AggregatedMediaItem,
    MediaResourceDetail,
    ProviderHealth,
    ProviderSearchTrace,
    ResourceCandidate,
    ResourceSearchResponse,
)
from .registry import ProviderRegistry

_TITLE_PUNCTUATION_RE = re.compile(r"[\s\-_:：·.，,。！!？?《》【】\[\]()（）]+")


def normalize_title(title: str) -> str:
    """生成保守的标题归并键，避免把明显不同的影片误合并。"""

    return _TITLE_PUNCTUATION_RE.sub("", title).lower()


class ResourceAggregator:
    """并发搜索启用源；单源失败仅记录 trace，不中断整体。"""

    def __init__(self, registry: ProviderRegistry | None = None) -> None:
        self.registry = registry or ProviderRegistry()
        self._semaphore = asyncio.Semaphore(settings.resource_max_concurrency)

    async def _search_one(
        self,
        provider,
        keyword: str,
        limit_per_provider: int,
    ) -> tuple[list[ResourceCandidate], ProviderSearchTrace]:
        started = perf_counter()
        try:
            async with self._semaphore:
                items = await provider.search(keyword, limit=limit_per_provider)
            return items, ProviderSearchTrace(
                provider_id=provider.config.id,
                provider_name=provider.config.name,
                ok=True,
                elapsed_ms=int((perf_counter() - started) * 1000),
                result_count=len(items),
            )
        except Exception as exc:
            return [], ProviderSearchTrace(
                provider_id=provider.config.id,
                provider_name=provider.config.name,
                ok=False,
                elapsed_ms=int((perf_counter() - started) * 1000),
                error=f"{type(exc).__name__}: {exc}",
            )

    async def search(
        self,
        keyword: str,
        *,
        limit_per_provider: int | None = None,
    ) -> ResourceSearchResponse:
        keyword = keyword.strip()
        if not keyword:
            return ResourceSearchResponse(keyword="")
        limit = limit_per_provider or settings.resource_search_limit_per_provider
        results = await asyncio.gather(
            *(self._search_one(provider, keyword, limit) for provider in self.registry.list_enabled())
        )
        merged: dict[str, AggregatedMediaItem] = {}
        traces: list[ProviderSearchTrace] = []
        for candidates, trace in results:
            traces.append(trace)
            for candidate in candidates:
                key = normalize_title(candidate.title)
                if not key:
                    continue
                if key not in merged:
                    merged[key] = AggregatedMediaItem(
                        normalized_title=key,
                        title=candidate.title,
                        category=candidate.category,
                        cover_url=candidate.cover_url,
                        remarks=candidate.remarks,
                        year=candidate.year,
                    )
                item = merged[key]
                item.sources.append(candidate)
                if not item.cover_url and candidate.cover_url:
                    item.cover_url = candidate.cover_url
        items = sorted(merged.values(), key=lambda item: (-len(item.sources), item.title))
        return ResourceSearchResponse(keyword=keyword, items=items, traces=traces)

    async def detail(self, provider_id: str, remote_id: str) -> MediaResourceDetail:
        return await self.registry.get(provider_id).detail(remote_id)

    async def health(self, *, probe: bool = False) -> list[ProviderHealth]:
        providers = self.registry.list_all()
        if not probe:
            return [
                ProviderHealth(
                    provider_id=provider.config.id,
                    provider_name=provider.config.name,
                    endpoint=provider.config.endpoint,
                    enabled=provider.config.enabled,
                )
                for provider in providers
            ]
        traces = await asyncio.gather(*(provider.health() for provider in providers))
        trace_map = {trace.provider_id: trace for trace in traces}
        return [
            ProviderHealth(
                provider_id=provider.config.id,
                provider_name=provider.config.name,
                endpoint=provider.config.endpoint,
                enabled=provider.config.enabled,
                ok=trace_map[provider.config.id].ok,
                elapsed_ms=trace_map[provider.config.id].elapsed_ms,
                error=trace_map[provider.config.id].error,
            )
            for provider in providers
        ]


@lru_cache(maxsize=1)
def get_resource_aggregator() -> ResourceAggregator:
    return ResourceAggregator()
