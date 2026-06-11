from unittest import TestCase
from unittest.mock import AsyncMock, patch
from fastapi.testclient import TestClient
from main import app

class GraphApiTests(TestCase):
    def setUp(self) -> None:
        self.client = TestClient(app)

    @patch("services.tmdb.tmdb_service.get_movie_graph")
    def test_get_movie_graph_endpoint(self, mock_get_graph):
        from models.schemas import MovieGraphResponse, GraphNode, GraphLink

        # 模拟返回数据
        mock_get_graph.return_value = MovieGraphResponse(
            nodes=[
                GraphNode(id="m1", label="Inception", type="movie", movie_id=27205),
                GraphNode(id="p1", label="Nolan", type="person"),
            ],
            links=[
                GraphLink(source="m1", target="p1", relation="导演")
            ]
        )

        response = self.client.get("/api/movie/27205/graph")

        self.assertEqual(200, response.status_code)
        data = response.json()
        self.assertTrue("nodes" in data)
        self.assertTrue("links" in data)
        self.assertEqual(data["nodes"][0]["label"], "Inception")
        self.assertEqual(data["links"][0]["relation"], "导演")

    @patch("services.tmdb.service.TMDBHTTPClient.request")
    def test_tmdb_service_graph_logic(self, mock_request):
        from services.tmdb import tmdb_service
        import asyncio

        # 模拟 TMDB 返回的聚合数据
        mock_request.return_value = {
            "title": "Inception",
            "genres": [{"id": 1, "name": "Sci-Fi"}],
            "credits": {
                "crew": [{"job": "Director", "name": "Nolan", "id": 100}],
                "cast": [{"name": "Leo", "id": 200}]
            },
            "keywords": {"keywords": [{"name": "dream", "id": 300}]},
            "recommendations": {"results": [{"title": "Interstellar", "id": 400}]}
        }

        result = asyncio.run(tmdb_service.get_movie_graph(27205))

        self.assertTrue(len(result.nodes) > 1)
        # 检查中心节点
        self.assertEqual(result.nodes[0].label, "Inception")
        # 检查是否包含了推荐电影
        movie_nodes = [n for n in result.nodes if n.type == "movie"]
        self.assertTrue(any(n.label == "Interstellar" for n in movie_nodes))
