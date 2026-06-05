"""从 YAML 加载并管理影视资源 Provider。"""
from __future__ import annotations

from pathlib import Path

import yaml

from config import settings

from .models import ProviderConfig
from .provider import MacCMSProvider
from .special import PlannedProvider


class ProviderRegistry:
    """Provider 注册中心：新增或停用标准 MacCMS 源无需改 Python。"""

    def __init__(self, config_path: Path | None = None) -> None:
        self.config_path = config_path or settings.resource_provider_config
        self._providers: dict[str, MacCMSProvider | PlannedProvider] = {}
        self.reload()

    def reload(self) -> None:
        payload = yaml.safe_load(self.config_path.read_text(encoding="utf-8")) or {}
        raw_providers = payload.get("providers", [])
        configs = [ProviderConfig.model_validate(item) for item in raw_providers]
        providers = {}
        for config in configs:
            provider_cls = MacCMSProvider if config.kind == "maccms" else PlannedProvider
            providers[config.id] = provider_cls(config, timeout_seconds=settings.resource_request_timeout_seconds)
        self._providers = providers

    def list_all(self) -> list[MacCMSProvider | PlannedProvider]:
        return list(self._providers.values())

    def list_enabled(self) -> list[MacCMSProvider | PlannedProvider]:
        return [provider for provider in self._providers.values() if provider.config.enabled]

    def get(self, provider_id: str) -> MacCMSProvider | PlannedProvider:
        provider = self._providers.get(provider_id)
        if provider is None:
            raise KeyError(f"未知资源站: {provider_id}")
        return provider
