from unittest import TestCase
from unittest.mock import AsyncMock, patch

from fastapi.testclient import TestClient

from main import app


class ApiTests(TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    def test_health_exposes_provider_count(self) -> None:
        response = self.client.get("/api/health")

        self.assertEqual(200, response.status_code)
        self.assertEqual(20, response.json()["provider_count"])

    def test_provider_list_is_available_without_network(self) -> None:
        response = self.client.get("/api/resources/providers")

        self.assertEqual(200, response.status_code)
        self.assertEqual(20, len(response.json()))

    def test_agent_reports_missing_llm_config(self) -> None:
        with patch(
            "routers.agent.invoke_agent",
            new=AsyncMock(side_effect=RuntimeError("LLM 尚未配置：测试错误")),
        ):
            response = self.client.post("/api/agent/invoke", json={"message": "你好"})

        self.assertEqual(503, response.status_code)
        self.assertIn("LLM 尚未配置", response.json()["detail"])
