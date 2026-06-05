"""Step 2 真实 smoke：豆瓣 Catalog、可选 TMDB、联合推荐 Feed。"""
from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient

from main import app
from config import settings
from services.catalog import get_catalog_service


def _utf8_console() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")


async def main() -> None:
    _utf8_console()
    catalog = get_catalog_service()
    print(json.dumps({"providers": [item.model_dump() for item in catalog.providers()]}, ensure_ascii=False, indent=2))

    hot = await catalog.hot(media_kind="movie", limit=10)
    if not hot.items:
        raise SystemExit("Catalog 热门接口未返回电影")
    print(
        json.dumps(
            {
                "hot_count": len(hot.items),
                "traces": [trace.model_dump() for trace in hot.traces],
                "first_hot": hot.items[0].model_dump(),
            },
            ensure_ascii=False,
            indent=2,
        )
    )

    search = await catalog.search("星际穿越", media_kind="movie", limit=10)
    if not search.items:
        raise SystemExit("Catalog 搜索未返回“星际穿越”")
    print(
        json.dumps(
            {
                "search_count": len(search.items),
                "traces": [trace.model_dump() for trace in search.traces],
                "top_search": [item.model_dump() for item in search.items[:3]],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    if search.items[0].title != "星际穿越":
        raise SystemExit(f"Catalog 精确标题排序失败: {search.items[0].title}")

    if settings.tmdb_read_access_token.strip():
        detail = await catalog.detail("tmdb", "157336")
        print(
            json.dumps(
                {
                    "tmdb_detail": detail.model_dump(),
                },
                ensure_ascii=False,
                indent=2,
            )
        )

    with TestClient(app) as client:
        response = client.get("/api/feed/recommend", params={"query": "星际穿越", "limit": 3})
        if response.status_code != 200:
            raise SystemExit(f"联合推荐 Feed 失败: HTTP {response.status_code} {response.text}")
        payload = response.json()
        if not payload["posts"]:
            raise SystemExit("联合推荐 Feed 没有返回可播放帖子")
        print(
            json.dumps(
                {
                    "feed_posts": len(payload["posts"]),
                    "first_post": payload["posts"][0],
                },
                ensure_ascii=False,
                indent=2,
            )
        )
        douban_id = search.items[0].source_id
        poster = client.get(f"/api/poster/catalog/douban/{douban_id}")
        if poster.status_code != 200:
            raise SystemExit(f"Catalog 动态海报失败: HTTP {poster.status_code} {poster.text}")
        print(
            json.dumps(
                {
                    "poster_blocks": [block["type"] for block in poster.json()["blocks"]],
                },
                ensure_ascii=False,
                indent=2,
            )
        )

    print("\nCatalog smoke 通过")


if __name__ == "__main__":
    asyncio.run(main())
