"""真实资源 smoke：并发搜索、详情解析、Feed 与动态海报接口验收。"""
from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient

from main import app
from services.resources import get_resource_aggregator


def _enable_utf8_console() -> None:
    """Windows PowerShell 管道下也稳定输出 UTF-8。"""

    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")


async def _search_and_parse(keyword: str) -> tuple[str, str]:
    aggregator = get_resource_aggregator()
    result = await aggregator.search(keyword)
    print(
        json.dumps(
            {
                "keyword": result.keyword,
                "provider_total": len(result.traces),
                "provider_ok": sum(1 for trace in result.traces if trace.ok),
                "provider_failed": sum(1 for trace in result.traces if not trace.ok),
                "merged_items": len(result.items),
                "top_items": [
                    {
                        "title": item.title,
                        "source_count": len(item.sources),
                        "sources": [f"{source.provider_id}:{source.remote_id}" for source in item.sources[:8]],
                    }
                    for item in result.items[:8]
                ],
                "failed_providers": [
                    {"provider": trace.provider_id, "error": trace.error}
                    for trace in result.traces
                    if not trace.ok
                ],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    for item in result.items:
        for source in item.sources:
            try:
                detail = await aggregator.detail(source.provider_id, source.remote_id)
            except Exception:
                continue
            if detail.episode_count:
                first = detail.play_lines[0].episodes[0]
                print(
                    json.dumps(
                        {
                            "parsed_resource": f"{detail.provider_id}:{detail.remote_id}",
                            "title": detail.title,
                            "play_lines": len(detail.play_lines),
                            "episode_count": detail.episode_count,
                            "first_episode": first.model_dump(),
                        },
                        ensure_ascii=False,
                        indent=2,
                    )
                )
                return detail.provider_id, detail.remote_id
    raise SystemExit("没有候选资源成功解析出 HTTP(S) 播放地址")


def _verify_fastapi(provider_id: str, remote_id: str, keyword: str) -> None:
    with TestClient(app) as client:
        feed = client.get("/api/feed", params={"keyword": keyword, "limit": 3})
        poster = client.get(f"/api/poster/{provider_id}/{remote_id}")
        parsed = client.get("/api/sources/parse", params={"source_id": f"{provider_id}:{remote_id}"})
        for label, response in (("feed", feed), ("poster", poster), ("sources_parse", parsed)):
            if response.status_code != 200:
                raise SystemExit(f"{label} 验收失败: HTTP {response.status_code} {response.text}")
        print(
            json.dumps(
                {
                    "fastapi": "ok",
                    "feed_count": len(feed.json()),
                    "poster_blocks": [block["type"] for block in poster.json()["blocks"]],
                    "play_url": parsed.json()["play_url"],
                },
                ensure_ascii=False,
                indent=2,
            )
        )


async def main() -> None:
    _enable_utf8_console()
    keyword = "星际穿越"
    provider_id, remote_id = await _search_and_parse(keyword)
    _verify_fastapi(provider_id, remote_id, keyword)
    print("\n资源 smoke 通过")


if __name__ == "__main__":
    asyncio.run(main())
