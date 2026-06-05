# services/tmdb/service.py
#真正的业务入口
#串联组合 TMDBHTTPClient 与 TMDBDataParser，向外提供干净、直接返回 Movie 对象的异步函数，
#包含：搜索（Search）、详情（Detail）、热门（Popular）、高分榜（Top Rated）。
from typing import List
from services.tmdb.client import TMDBHTTPClient
from services.tmdb.parser import TMDBDataParser
from models.schemas import Movie

class TMDBService:
    """TMDB 业务服务层（提供高层 API 方法）"""
    def __init__(self) -> None:
        self.client = TMDBHTTPClient()
        self.parser = TMDBDataParser(image_base_url=self.client.image_base)

    async def search(self, query: str, page: int = 1) -> List[Movie]:
        """
        根据关键字搜索电影
        对应 TMDB 路径: /search/movie
        """
        if not query.strip():
            return []
        payload = await self.client.request("/search/movie", params={"query": query, "page": page})
        return self.parser.json_to_movie_list(payload.get("results", []))

    async def detail(self, movie_id: int) -> Movie:
        """
        获取单部电影的详尽信息（通过追加参数一并拿到演职员列表）
        对应 TMDB 路径: /movie/{movie_id}
        """
        # 使用 append_to_response 减少网络请求次数，一次性带回演职员
        payload = await self.client.request(f"/movie/{movie_id}", params={"append_to_response": "credits"})
        return self.parser.json_to_movie(payload)

    async def popular(self, page: int = 1) -> List[Movie]:
        """
        获取当前热门电影列表
        对应 TMDB 路径: /movie/popular
        """
        payload = await self.client.request("/movie/popular", params={"page": page})
        return self.parser.json_to_movie_list(payload.get("results", []))

    async def discover_by_genres(
        self,
        genre_ids: List[int],
        excluded_genre_ids: List[int] | None = None,
        page: int = 1,
    ) -> List[Movie]:
        """
        根据 TMDB 类型 ID 获取电影列表。
        这一步用于把用户在设置页选择的类型，稳定映射到真实 TMDB 推荐结果。
        """
        params = {
            "page": page,
            "sort_by": "popularity.desc",
            "with_genres": ",".join(str(item) for item in genre_ids),
        }
        if excluded_genre_ids:
            params["without_genres"] = ",".join(str(item) for item in excluded_genre_ids)
        payload = await self.client.request("/discover/movie", params=params)
        return self.parser.json_to_movie_list(payload.get("results", []))

    async def top_rated(self, page: int = 1) -> List[Movie]:
        """
        获取高分/Top Rated电影列表
        对应 TMDB 路径: /movie/top_rated
        """
        payload = await self.client.request("/movie/top_rated", params={"page": page})
        return self.parser.json_to_movie_list(payload.get("results", []))
