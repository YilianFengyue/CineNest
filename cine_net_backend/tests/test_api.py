from unittest import TestCase
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from db import get_conn, init_db
from main import app


class ApiTests(TestCase):
    def setUp(self) -> None:
        init_db()
        self.client = TestClient(app)

    def test_health_exposes_provider_count(self) -> None:
        response = self.client.get("/api/health")

        self.assertEqual(200, response.status_code)
        self.assertEqual(24, response.json()["provider_count"])
        self.assertEqual(20, response.json()["enabled_provider_count"])
        self.assertEqual("microdesign.v1.1", response.json()["microdesign_schema_version"])

    def test_provider_list_is_available_without_network(self) -> None:
        response = self.client.get("/api/resources/providers")

        self.assertEqual(200, response.status_code)
        self.assertEqual(24, len(response.json()))

    def test_agent_reports_missing_llm_config(self) -> None:
        with patch(
            "routers.agent.invoke_agent",
            new=AsyncMock(side_effect=RuntimeError("LLM 尚未配置：测试错误")),
        ):
            response = self.client.post("/api/agent/invoke", json={"message": "你好"})

        self.assertEqual(503, response.status_code)
        self.assertIn("LLM 尚未配置", response.json()["detail"])

    def test_agent_models_endpoint(self) -> None:
        response = self.client.get("/api/agent/models")

        self.assertEqual(200, response.status_code)
        self.assertIn("default", {item["id"] for item in response.json()})

    def test_microdesign_schema_endpoint(self) -> None:
        response = self.client.get("/api/microdesign/schema")

        self.assertEqual(200, response.status_code)
        payload = response.json()
        self.assertEqual("microdesign.v1.1", payload["schema_version"])
        self.assertIn("playableMovieCard", payload["blocks"])
        self.assertIn("resolveAndPlay", payload["actions"])

    def test_chat_history_endpoints(self) -> None:
        thread_id = "test-api-chat-history"
        delete = self.client.delete(f"/api/chat/sessions/{thread_id}")
        self.assertEqual(200, delete.status_code)

        with patch(
            "routers.agent.invoke_agent",
            new=AsyncMock(
                return_value=type(
                    "Result",
                    (),
                    {"thread_id": thread_id, "model": "default", "answer": "你好", "tool_calls": [], "attachments": []},
                )()
            ),
        ):
            response = self.client.post(
                "/api/agent/invoke",
                json={"thread_id": thread_id, "message": "你好", "model": "default"},
            )

        self.assertEqual(200, response.status_code)
        history = self.client.get(f"/api/chat/sessions/{thread_id}/messages")
        self.assertEqual(200, history.status_code)
        self.assertEqual(2, len(history.json()["messages"]))

    def test_play_resolve_endpoint(self) -> None:
        with patch("routers.play.resolve_play", new=AsyncMock()) as mocked:
            mocked.return_value = {
                "type": "direct",
                "play_url": "https://cdn.example/movie.m3u8",
                "headers": {},
                "expires_at": None,
                "fallback_web_url": None,
                "provider_id": "demo",
                "remote_id": "1",
                "title": "演示电影",
                "line_name": "m3u8",
                "episode_name": "正片",
            }
            response = self.client.get("/api/play/resolve", params={"provider_id": "demo", "remote_id": "1"})

        self.assertEqual(200, response.status_code)
        self.assertEqual("https://cdn.example/movie.m3u8", response.json()["play_url"])

    def test_upload_and_read_asset(self) -> None:
        response = self.client.post(
            "/api/uploads",
            files={"file": ("hello.txt", b"hello cinenest", "text/plain")},
        )

        self.assertEqual(200, response.status_code)
        asset_id = response.json()["id"]
        self.assertEqual(asset_id, response.json()["asset_id"])
        read = self.client.get(f"/api/assets/{asset_id}")
        self.assertEqual(200, read.status_code)
        self.assertEqual(b"hello cinenest", read.content)

    def test_image_proxy_returns_remote_image(self) -> None:
        with patch("routers.uploads._download_remote_image", new=AsyncMock(return_value=(b"image-bytes", "image/png"))):
            response = self.client.get("/api/image-proxy", params={"url": "https://img.example/poster.png"})

        self.assertEqual(200, response.status_code)
        self.assertEqual("image/png", response.headers["content-type"])
        self.assertEqual(b"image-bytes", response.content)

    def test_news_generate_creates_background_task(self) -> None:
        with patch("routers.news.run_news_task", new=AsyncMock()) as mocked_runner:
            response = self.client.post("/api/news/generate", json={"query": "星际穿越"})

        self.assertEqual(200, response.status_code)
        payload = response.json()
        self.assertEqual("queued", payload["status"])
        self.assertEqual("星际穿越", payload["query"])
        self.assertTrue(payload["id"].startswith("news-task-"))
        mocked_runner.assert_awaited_once_with(payload["id"])

        tasks = self.client.get("/api/news/tasks", params={"limit": 5})
        self.assertEqual(200, tasks.status_code)
        self.assertIn(payload["id"], {item["id"] for item in tasks.json()})

        with get_conn() as conn:
            conn.execute("DELETE FROM news_tasks WHERE id = ?", (payload["id"],))
