"""Catalog 的轻量 TTL 缓存。"""
from __future__ import annotations

from dataclasses import dataclass
from time import monotonic
from typing import Any


@dataclass
class _CacheValue:
    expires_at: float
    value: Any


class TTLCache:
    """进程内缓存。后续可替换 Redis，不影响 Provider 接口。"""

    def __init__(self, ttl_seconds: int) -> None:
        self.ttl_seconds = ttl_seconds
        self._values: dict[str, _CacheValue] = {}

    def get(self, key: str):
        current = self._values.get(key)
        if current is None:
            return None
        if current.expires_at <= monotonic():
            self._values.pop(key, None)
            return None
        return current.value

    def set(self, key: str, value) -> None:
        self._values[key] = _CacheValue(monotonic() + self.ttl_seconds, value)
