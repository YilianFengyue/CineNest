"""Small in-memory TTL cache for Bilibili API calls."""
from __future__ import annotations

import time
from copy import deepcopy
from typing import Any

_CACHE: dict[str, tuple[float, Any]] = {}


def get_cached(key: str) -> Any | None:
    item = _CACHE.get(key)
    if item is None:
        return None
    expires_at, value = item
    if expires_at < time.time():
        _CACHE.pop(key, None)
        return None
    return deepcopy(value)


def set_cached(key: str, value: Any, ttl_seconds: int) -> None:
    _CACHE[key] = (time.time() + ttl_seconds, deepcopy(value))


def clear_cache() -> None:
    _CACHE.clear()
