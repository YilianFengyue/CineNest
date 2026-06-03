"""P0-P4 总验收：模型、持久化、上传、交互卡片、资讯、播放描述。"""
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


def main() -> None:
    _utf8_console()
    keyword = sys.argv[1] if len(sys.argv) > 1 else "功夫熊猫"
    with TestClient(app) as client:
        models = client.get("/api/agent/models")
        schema = client.get("/api/microdesign/schema")
        upload = client.post("/api/uploads", files={"file": ("note.txt", b"hello", "text/plain")})
        news = client.get("/api/news", params={"limit": 3, "refresh": True})
        feed = client.get("/api/feed/recommend", params={"query": keyword, "limit": 2, "refresh": True})
        for label, response in (
            ("models", models),
            ("schema", schema),
            ("upload", upload),
            ("news", news),
            ("feed", feed),
        ):
            if response.status_code != 200:
                raise SystemExit(f"{label} 验收失败: HTTP {response.status_code} {response.text}")
        post = feed.json()["posts"][0]
        primary = post["primary_resource"]
        play = client.get(
            "/api/play/resolve",
            params={"provider_id": primary["provider_id"], "remote_id": primary["remote_id"]},
        )
        if play.status_code != 200:
            raise SystemExit(f"play 验收失败: HTTP {play.status_code} {play.text}")
        payload = {
            "models": models.json(),
            "schema": {
                "schema_version": schema.json()["schema_version"],
                "new_blocks": [
                    name
                    for name in ("playableMovieCard", "movieCarousel", "newsCard", "videoExplainCard")
                    if name in schema.json()["blocks"]
                ],
            },
            "upload": upload.json(),
            "news_count": len(news.json()["items"]),
            "first_news_blocks": [block["type"] for block in news.json()["items"][0]["blocks"]],
            "feed_first_post": {
                "title": post["title"],
                "actions": [action["type"] for action in post["actions"]],
                "blocks": [block["type"] for block in post["blocks"]],
            },
            "play_descriptor": play.json(),
        }
        print(json.dumps(payload, ensure_ascii=False, indent=2))
    print("\nP0-P4 smoke 通过")


if __name__ == "__main__":
    main()
