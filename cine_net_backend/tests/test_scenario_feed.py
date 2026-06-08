from unittest import TestCase
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from main import app
from models.schemas import Movie, Post

class ScenarioFeedTests(TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    @patch("services.agent.service.movie_agent_service.get_scenario_recommendation")
    def test_scenario_endpoint(self, mock_get_scenario):
        # 模拟 ScenarioResponse
        from models.schemas import ScenarioResponse
        mock_get_scenario.return_value = ScenarioResponse(
            posts=[
                Post(
                    movie=Movie(id=1, title="测试电影", genres=["Comedy"], rating=8.0),
                    recommend_reason="因为你想放松"
                )
            ],
            debug_info="AI 解析为：喜剧"
        )

        # 调用新接口
        response = self.client.get("/api/feed/scenario", params={"scenario": "我想看点甜的"})

        # 验证
        self.assertEqual(200, response.status_code)
        self.assertEqual(response.json()["debug_info"], "AI 解析为：喜剧")
        self.assertEqual(len(response.json()["posts"]), 1)

    @patch("services.agent.service.invoke_agent")
    @patch("services.tmdb.tmdb_service.search")
    def test_agent_service_priority_logic(self, mock_search, mock_invoke):
        from services.agent.service import movie_agent_service
        import asyncio

        # 模拟 LLM 解析场景为关键词
        mock_invoke.side_effect = [
            type("Result", (), {"answer": "恐怖"})(), # _smart_search_query
            type("Result", (), {"answer": '{"666": "吓死你"}'})() # _agent_reason_map
        ]

        mock_search.return_value = [
            Movie(id=666, title="惊魂记", genres=["Horror"], rating=8.5)
        ]

        # 模拟用户偏好是“爱情”，但场景是“想看恐怖片”
        pref_prompt = "喜欢的类型: 爱情"
        scenario = "想看恐怖片"

        result = asyncio.run(movie_agent_service.get_scenario_recommendation(pref_prompt, scenario))

        # 验证是否搜索了“恐怖”而不是“爱情”
        self.assertEqual(result.posts[0].movie.id, 666)
        mock_search.assert_called_with("恐怖")

        # 验证 prompt 是否包含优先级信息
        call_args = mock_invoke.call_args_list[1] # _agent_reason_map call
        message = call_args[0][0]
        self.assertIn("最高优先级", message)
        self.assertIn("次要参考", message)
