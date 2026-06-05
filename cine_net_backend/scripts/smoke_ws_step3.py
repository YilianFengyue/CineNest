"""Step 3 WebSocket smoke：验证聊天流中包含 Flutter 可渲染附件。"""
from __future__ import annotations

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from fastapi.testclient import TestClient

from main import app
from services.llm import is_llm_configured


def _utf8_console() -> None:
    if hasattr(sys.stdout, "reconfigure"):
        sys.stdout.reconfigure(encoding="utf-8")
    if hasattr(sys.stderr, "reconfigure"):
        sys.stderr.reconfigure(encoding="utf-8")


def main() -> None:
    _utf8_console()
    if not is_llm_configured():
        raise SystemExit("请先在 .env 填写 LLM_API_KEY / LLM_BASE_URL / LLM_MODEL")
    keyword = sys.argv[1] if len(sys.argv) > 1 else "功夫熊猫"
    received_types: list[str] = []
    attachment: dict | None = None
    with TestClient(app) as client:
        with client.websocket_connect("/ws/chat") as websocket:
            websocket.send_json(
                {
                    "thread_id": "smoke-step3-ws",
                    "message": f"请调用 build_recommendation_feed 工具，为“{keyword}”生成最多 2 个真实可播放推荐帖子。",
                }
            )
            while True:
                event = websocket.receive_json()
                received_types.append(event["type"])
                if event["type"] == "attachment":
                    attachment = event["data"]
                if event["type"] == "error":
                    raise SystemExit(f"WebSocket Agent 失败: {event['content']}")
                if event["type"] == "done":
                    break
    if attachment is None or attachment.get("type") != "recommendation_feed":
        raise SystemExit(f"WebSocket 未返回 recommendation_feed 附件，事件: {received_types}")
    posts = attachment.get("payload", {}).get("posts") or []
    if not posts:
        raise SystemExit("WebSocket 推荐附件没有帖子")
    print(
        json.dumps(
            {
                "keyword": keyword,
                "events": received_types,
                "attachment_type": attachment["type"],
                "schema_version": attachment["schema_version"],
                "first_post": posts[0]["title"],
                "actions": [action["type"] for action in posts[0]["actions"]],
            },
            ensure_ascii=False,
            indent=2,
        )
    )
    print("\nStep 3 WebSocket smoke 通过")


if __name__ == "__main__":
    main()
