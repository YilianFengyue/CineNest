"""Catalog Provider 注册中心。"""
from __future__ import annotations

from pathlib import Path

import yaml

from config import settings

from .douban import DoubanCatalogProvider
from .models import CatalogProviderConfig
from .tmdb import TMDBCatalogProvider

_PROVIDER_TYPES = {
    "douban": DoubanCatalogProvider,
    "tmdb": TMDBCatalogProvider,
}


class CatalogRegistry:
    """从 YAML 加载资料源；未配置凭据的 Provider 自动跳过。"""

    def __init__(self, config_path: Path | None = None) -> None:
        self.config_path = config_path or settings.catalog_provider_config
        self._providers: dict[str, object] = {}
        self.reload()

    def reload(self) -> None:
        payload = yaml.safe_load(self.config_path.read_text(encoding="utf-8")) or {}
        configs = [CatalogProviderConfig.model_validate(item) for item in payload.get("providers", [])]
        providers: dict[str, object] = {}
        for config in configs:
            provider_type = _PROVIDER_TYPES.get(config.kind)
            if provider_type is None:
                raise ValueError(f"未知 Catalog Provider 类型: {config.kind}")
            providers[config.id] = provider_type(
                config,
                timeout_seconds=settings.catalog_request_timeout_seconds,
            )
        self._providers = providers

    def list_all(self) -> list:
        return sorted(self._providers.values(), key=lambda provider: provider.config.priority)

    def list_available(self) -> list:
        return [
            provider
            for provider in self.list_all()
            if provider.config.enabled and provider.configured
        ]

    def get(self, provider_id: str):
        provider = self._providers.get(provider_id)
        if provider is None:
            raise KeyError(f"未知 Catalog Provider: {provider_id}")
        return provider
