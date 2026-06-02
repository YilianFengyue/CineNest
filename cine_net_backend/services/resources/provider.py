"""标准 MacCMS v10 Provider 适配器。"""
from __future__ import annotations

import html
import re
from time import perf_counter
from typing import Any

import httpx

from .models import MediaResourceDetail, ProviderConfig, ProviderSearchTrace, ResourceCandidate
from .playlist import parse_play_lines

_TAG_RE = re.compile(r"<[^>]+>")


def _clean_text(value: Any) -> str:
    text = html.unescape(str(value or ""))
    text = _TAG_RE.sub("", text)
    return re.sub(r"\s+", " ", text).strip()


class MacCMSProvider:
    """封装一个标准 MacCMS JSON API。"""

    def __init__(self, config: ProviderConfig, *, timeout_seconds: float) -> None:
        self.config = config
        self.timeout_seconds = timeout_seconds

    async def _get(self, params: dict[str, Any]) -> dict[str, Any]:
        async with httpx.AsyncClient(
            timeout=self.timeout_seconds,
            follow_redirects=True,
            headers=self.config.headers,
        ) as client:
            response = await client.get(self.config.endpoint, params=params)
            response.raise_for_status()
            payload = response.json()
        if not isinstance(payload, dict):
            raise ValueError("资源站返回值不是 JSON object")
        return payload

    def _candidate(self, raw: dict[str, Any]) -> ResourceCandidate:
        return ResourceCandidate(
            provider_id=self.config.id,
            provider_name=self.config.name,
            remote_id=str(raw.get("vod_id", "")),
            title=_clean_text(raw.get("vod_name")),
            category=_clean_text(raw.get("type_name")),
            cover_url=str(raw.get("vod_pic") or ""),
            remarks=_clean_text(raw.get("vod_remarks")),
            year=_clean_text(raw.get("vod_year")),
        )

    async def search(self, keyword: str, *, limit: int) -> list[ResourceCandidate]:
        payload = await self._get({"ac": "videolist", "wd": keyword, "pg": 1})
        raw_list = payload.get("list")
        if not isinstance(raw_list, list):
            return []
        items: list[ResourceCandidate] = []
        for raw in raw_list:
            if not isinstance(raw, dict):
                continue
            item = self._candidate(raw)
            if item.remote_id and item.title:
                items.append(item)
            if len(items) >= limit:
                break
        return items

    async def detail(self, remote_id: str) -> MediaResourceDetail:
        payload = await self._get({"ac": self.config.detail_action, "ids": remote_id})
        raw_list = payload.get("list")
        if not isinstance(raw_list, list) or not raw_list or not isinstance(raw_list[0], dict):
            raise LookupError(f"{self.config.name} 未返回资源 {remote_id}")
        raw = raw_list[0]
        item = self._candidate(raw)
        return MediaResourceDetail(
            **item.model_dump(),
            summary=_clean_text(raw.get("vod_content") or raw.get("vod_blurb")),
            play_lines=parse_play_lines(raw.get("vod_play_from"), raw.get("vod_play_url")),
        )

    async def health(self) -> ProviderSearchTrace:
        started = perf_counter()
        try:
            payload = await self._get({"ac": "videolist", "pg": 1})
            ok = isinstance(payload.get("list"), list)
            return ProviderSearchTrace(
                provider_id=self.config.id,
                provider_name=self.config.name,
                ok=ok,
                elapsed_ms=int((perf_counter() - started) * 1000),
                result_count=len(payload.get("list") or []),
                error=None if ok else "响应缺少 list 数组",
            )
        except Exception as exc:
            return ProviderSearchTrace(
                provider_id=self.config.id,
                provider_name=self.config.name,
                ok=False,
                elapsed_ms=int((perf_counter() - started) * 1000),
                error=f"{type(exc).__name__}: {exc}",
            )
