# services/tmdb/service.py
#真正的业务入口
#串联组合 TMDBHTTPClient 与 TMDBDataParser，向外提供干净、直接返回 Movie 对象的异步函数，
#包含：搜索（Search）、详情（Detail）、热门（Popular）、高分榜（Top Rated）。
from typing import List
from services.tmdb.client import TMDBHTTPClient
from services.tmdb.parser import TMDBDataParser
from models.schemas import Movie, MovieGraphResponse, GraphNode, GraphLink
from config import settings

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

    async def get_movie_graph(self, movie_id: int) -> MovieGraphResponse:
        """
        聚合电影关系图谱：导演、主演、类型、题材、推荐。
        """
        import asyncio

        # 0. 离线/无 Key 模式下的 mock 数据
        if not settings.tmdb_api_key:
            print(f">>> [TMDB Graph] No API key, returning mock graph for {movie_id}", flush=True)
            nodes = [
                GraphNode(id=f"m{movie_id}", label="演示电影", type="movie", movie_id=movie_id),
                GraphNode(id="g1", label="剧情", type="genre"),
                GraphNode(id="p1", label="演示导演", type="person"),
                GraphNode(id="k1", label="演示题材", type="keyword"),
                GraphNode(id="m999", label="相似电影A", type="movie", movie_id=27205),
            ]
            links = [
                GraphLink(source=f"m{movie_id}", target="g1", relation="类型"),
                GraphLink(source=f"m{movie_id}", target="p1", relation="导演"),
                GraphLink(source=f"m{movie_id}", target="k1", relation="题材"),
                GraphLink(source=f"m{movie_id}", target="m999", relation="推荐"),
            ]
            return MovieGraphResponse(nodes=nodes, links=links)

        # 1. 并发获取基础信息、关键词、推荐
        print(f">>> [TMDB Graph] Fetching data for movie {movie_id}...", flush=True)
        try:
            results = await asyncio.gather(
                self.client.request(f"/movie/{movie_id}", params={"append_to_response": "credits,keywords,recommendations"}),
            )
            data = results[0]
        except Exception as exc:
            print(f">>> [TMDB Graph] Fetching failed: {exc}", flush=True)
            raise

        nodes = []
        links = []
        center_id = f"m{movie_id}"

        # 中心节点
        center_title = data.get("title") or data.get("name") or "当前电影"
        nodes.append(GraphNode(id=center_id, label=center_title, type="movie", movie_id=movie_id))

        # 2. 提取分类 (Genres)
        genres = data.get("genres", [])
        for genre in genres[:3]:
            g_id = f"g{genre['id']}"
            if not any(n.id == g_id for n in nodes):
                nodes.append(GraphNode(id=g_id, label=genre["name"], type="genre"))
            links.append(GraphLink(source=center_id, target=g_id, relation="类型"))

        # 3. 提取导演和主演 (Credits)
        credits = data.get("credits", {})
        # 导演
        for crew in credits.get("crew", []):
            if crew.get("job") == "Director":
                p_id = f"p{crew['id']}"
                if not any(n.id == p_id for n in nodes):
                    nodes.append(GraphNode(id=p_id, label=crew["name"], type="person"))
                links.append(GraphLink(source=center_id, target=p_id, relation="导演"))
                break # 只取一个导演

        # 主演 (前 3)
        for cast in credits.get("cast", [])[:3]:
            p_id = f"p{cast['id']}"
            if not any(n.id == p_id for n in nodes):
                nodes.append(GraphNode(id=p_id, label=cast["name"], type="person"))
            links.append(GraphLink(source=center_id, target=p_id, relation="主演"))

        # 4. 提取关键词 (Keywords) - 前 3
        # 注意 TMDB 返回的 keywords 结构可能因端点不同而异，详情页 append 为 {"keywords": [...]}
        raw_keywords = data.get("keywords", {})
        keyword_list = []
        if isinstance(raw_keywords, dict):
            keyword_list = raw_keywords.get("keywords") or raw_keywords.get("results") or []
        elif isinstance(raw_keywords, list):
            keyword_list = raw_keywords

        for kw in keyword_list[:3]:
            if isinstance(kw, dict) and "id" in kw:
                k_id = f"k{kw['id']}"
                if not any(n.id == k_id for n in nodes):
                    nodes.append(GraphNode(id=k_id, label=kw.get("name") or "题材", type="keyword"))
                links.append(GraphLink(source=center_id, target=k_id, relation="题材"))

        # 5. 提取推荐电影 (Recommendations) - 前 4
        raw_recs = data.get("recommendations", {})
        rec_list = []
        if isinstance(raw_recs, dict):
            rec_list = raw_recs.get("results") or []
        elif isinstance(raw_recs, list):
            rec_list = raw_recs

        for rec in rec_list[:4]:
            if isinstance(rec, dict) and "id" in rec:
                r_id = f"m{rec['id']}"
                if not any(n.id == r_id for n in nodes):
                    nodes.append(GraphNode(id=r_id, label=rec.get("title") or rec.get("name") or "相似电影", type="movie", movie_id=rec["id"]))
                links.append(GraphLink(source=center_id, target=r_id, relation="推荐"))

        print(f">>> [TMDB Graph] Constructed graph with {len(nodes)} nodes and {len(links)} links", flush=True)
        return MovieGraphResponse(nodes=nodes, links=links)
