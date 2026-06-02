# services/tmdb/parser.py
#由于 TMDB 返回的原始数据字段（如 poster_path, vote_average）与我们本地系统定义的 Movie 模型不一致，
#我们需要一个独立的转换器，并且在这里处理复杂的相对路径拼接和演职人员提取。
#相当于一个数据模型转换器
from typing import Any, Dict, List
from models.schemas import Movie


class TMDBDataParser:
    """专门负责将 TMDB 原始 JSON 响应解析为本地的 Movie 模型"""

    def __init__(self, image_base_url: str) -> None:
        self.image_base = image_base_url
        # TMDB 官方分类映射 (用于将 genre_ids 转化为中文名称)
        self.genre_map = {
            28: "动作", 12: "冒险", 16: "动画", 35: "喜剧", 80: "犯罪", 99: "纪录", 18: "剧情",
            10751: "家庭", 14: "奇幻", 36: "历史", 27: "恐怖", 10402: "音乐", 9648: "悬疑",
            10749: "爱情", 878: "科幻", 10770: "电视电影", 53: "惊悚", 10752: "战争", 37: "西部"
        }

    def _build_url(self, path: str | None) -> str | None:
        """拼接完整的海报或背景图 URL，并封装为后端中转地址"""
        if not path:
            return None
        original_url = f"{self.image_base}{path}"
        # 自动包装为后端代理地址，解决模拟器访问不了 TMDB 的问题
        # 这里的 10.0.2.2 会由前端请求时自动识别或在 BaseUrl 中处理，
        # 但后端生成时最好返回相对路径，由前端拼接。
        # 为了简单起见，我们直接返回代理路径前缀
        return f"/api/proxy/image?url={original_url}"

    def _extract_year(self, release_date: str | None) -> int | None:
        """从 '2026-05-20' 格式中提取年份"""
        if not release_date:
            return None
        try:
            return int(release_date.split("-")[0])
        except (ValueError, IndexError):
            return None

    def _parse_credits(self, credits: Dict[str, Any]) -> tuple[List[str], List[str]]:
        """从追加的 credits 数据中分离导演与前 5 名核心演员"""
        directors = []
        cast = []
        if not credits:
            return directors, cast

        # 提取导演 (Crew 中 job 为 Director 的人)
        for crew_member in credits.get("crew", []):
            if crew_member.get("job") == "Director":
                name = crew_member.get("name")
                if name:
                    directors.append(name)

        # 提取前 5 位演员
        for actor in credits.get("cast", [])[:5]:
            name = actor.get("name")
            if name:
                cast.append(name)

        return directors, cast

    def json_to_movie(self, raw: Dict[str, Any]) -> Movie:
        """解析单部电影的核心方法"""
        # 如果外层有追加演职员，则能够提取
        credits = raw.get("credits", {})
        directors, cast = self._parse_credits(credits)

        # 解析电影类型（处理详情页的字典列表形式 或 列表页的 genre_ids）
        genres = []
        if "genres" in raw:
            genres = [g["name"] for g in raw["genres"] if "name" in g]
        elif "genre_ids" in raw:
            genres = [self.genre_map.get(gid, "其他") for gid in raw["genre_ids"]]

        return Movie(
            id=raw["id"],
            title=raw.get("title") or raw.get("name") or "未知电影",
            original_title=raw.get("original_title"),
            year=self._extract_year(raw.get("release_date")),
            genres=genres,
            rating=float(raw.get("vote_average", 0.0)),
            overview=raw.get("overview", ""),
            poster_url=self._build_url(raw.get("poster_path")),
            backdrop_url=self._build_url(raw.get("backdrop_path")),
            directors=directors,
            cast=cast
        )

    def json_to_movie_list(self, raw_list: List[Dict[str, Any]]) -> List[Movie]:
        """批量解析列表页数据"""
        movies = []
        for item in raw_list:
            try:
                movies.append(self.json_to_movie(item))
            except Exception:
                # 容错处理：如果列表中某部电影数据损坏，跳过它而不阻断整体
                continue
        return movies