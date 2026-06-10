"""Thin async wrapper around bilibili-api-python."""
from __future__ import annotations

import asyncio
from typing import Any, Awaitable

_READY = False
_SEM = asyncio.Semaphore(3)


class BiliUnavailableError(RuntimeError):
    """Bilibili integration dependency or upstream is unavailable."""


def _require_bili():
    try:
        from bilibili_api import article, comment, hot, rank, search, user, video
        from bilibili_api import request_settings, select_client
    except Exception as exc:  # noqa: BLE001
        raise BiliUnavailableError(
            "B站能力依赖尚未安装，请先安装 bilibili-api-python、curl_cffi。"
        ) from exc

    global _READY
    if not _READY:
        try:
            select_client("curl_cffi")
            request_settings.set("impersonate", "chrome131")
        except Exception:
            pass
        _READY = True
    return {
        "article": article,
        "comment": comment,
        "hot": hot,
        "rank": rank,
        "search": search,
        "user": user,
        "video": video,
    }


async def guarded(awaitable: Awaitable[Any]) -> Any:
    async with _SEM:
        return await awaitable


def bili_modules():
    return _require_bili()
