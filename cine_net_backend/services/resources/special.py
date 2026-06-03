"""非 MacCMS Provider 骨架。默认禁用，后续逐个补真实实现。"""
from __future__ import annotations

from time import perf_counter

from .models import MediaResourceDetail, ProviderConfig, ProviderSearchTrace, ResourceCandidate


class PlannedProvider:
    """B站、网盘、Alist、本地文件等资源 Provider 的占位实现。"""

    def __init__(self, config: ProviderConfig, *, timeout_seconds: float) -> None:
        self.config = config
        self.timeout_seconds = timeout_seconds

    async def search(self, keyword: str, *, limit: int) -> list[ResourceCandidate]:
        return []

    async def detail(self, remote_id: str) -> MediaResourceDetail:
        raise NotImplementedError(f"{self.config.name} Provider 尚未实现")

    async def health(self) -> ProviderSearchTrace:
        started = perf_counter()
        return ProviderSearchTrace(
            provider_id=self.config.id,
            provider_name=self.config.name,
            ok=False,
            elapsed_ms=int((perf_counter() - started) * 1000),
            error="Provider 已注册但尚未实现，默认禁用",
        )
