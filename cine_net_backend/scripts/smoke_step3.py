"""Step 3 确定性 smoke：功夫熊猫 Feed、互动海报、播放 Action。"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient

from main import app


def _utf8_console() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")


def _action(payload: dict, action_type: str) -> dict:
    return next((item for item in payload.get("actions", []) if item.get("type") == action_type), {})


def main() -> None:
    _utf8_console()
    keyword = sys.argv[1] if len(sys.argv) > 1 else "功夫熊猫"
    with TestClient(app) as client:
        feed_response = client.get("/api/feed/recommend", params={"query": keyword, "limit": 3})
        if feed_response.status_code != 200:
            raise SystemExit(f"推荐 Feed 失败: HTTP {feed_response.status_code} {feed_response.text}")
        feed = feed_response.json()
        if feed.get("schema_version") != "microdesign.v1.1" or not feed.get("posts"):
            raise SystemExit("推荐 Feed 未返回 microdesign.v1.1 帖子")
        post = feed["posts"][0]
        open_poster = _action(post, "openPoster")
        resolve_play = _action(post, "resolveAndPlay")
        if not open_poster or not resolve_play:
            raise SystemExit("帖子缺少 openPoster 或 resolveAndPlay Action")

        poster_data = open_poster["data"]
        poster_response = client.get(
            f"/api/poster/catalog/{poster_data['catalog_provider_id']}/{poster_data['catalog_source_id']}",
            params={"media_kind": poster_data.get("media_kind", "movie")},
        )
        if poster_response.status_code != 200:
            raise SystemExit(f"互动海报失败: HTTP {poster_response.status_code} {poster_response.text}")
        poster = poster_response.json()
        video_blocks = [block for block in poster.get("blocks", []) if block.get("type") == "videoBar"]
        if poster.get("schema_version") != "microdesign.v1.1" or not video_blocks:
            raise SystemExit("互动海报没有返回可播放 videoBar")
        video_action = video_blocks[0].get("action") or {}
        play_url = (video_action.get("data") or {}).get("play_url", "")
        if video_action.get("type") != "resolveAndPlay" or not play_url.startswith(("http://", "https://")):
            raise SystemExit("videoBar 缺少真实 HTTP(S) 播放 Action")

        print(
            json.dumps(
                {
                    "keyword": keyword,
                    "schema_version": feed["schema_version"],
                    "feed_post_count": len(feed["posts"]),
                    "first_post": {
                        "title": post["title"],
                        "rating": post["rating"],
                        "source_count": post["source_count"],
                        "actions": [action["type"] for action in post["actions"]],
                    },
                    "poster": {
                        "style": poster["style"],
                        "blocks": [block["type"] for block in poster["blocks"]],
                        "video_action": video_action,
                    },
                },
                ensure_ascii=False,
                indent=2,
            )
        )
    print("\nStep 3 smoke 通过")


if __name__ == "__main__":
    main()
